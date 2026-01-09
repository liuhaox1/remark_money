import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../models/savings_plan.dart';
import '../models/tag.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../repository/repository_factory.dart';
import '../repository/record_repository_db.dart';
import '../repository/savings_plan_repository.dart';
import 'account_delete_queue.dart';
import 'auth_service.dart';
import 'budget_conflict_backup_store.dart';
import 'budget_sync_state_store.dart';
import 'category_delete_queue.dart';
import 'data_version_service.dart';
import 'savings_plan_conflict_backup_store.dart';
import 'savings_plan_delete_queue.dart';
import 'sync_outbox_service.dart';
import 'sync_service.dart';
import 'sync_v2_conflict_store.dart';
import 'sync_v2_cursor_store.dart';
import 'sync_v2_pull_utils.dart';
import 'sync_v2_push_retry.dart';
import 'sync_v2_summary_store.dart';
import 'tag_delete_queue.dart';

class SyncEngine {
  SyncEngine({
    SyncService? syncService,
    AuthService? authService,
    SyncOutboxService? outbox,
  })  : _syncService = syncService ?? SyncService(),
        _authService = authService ?? const AuthService(),
        _outbox = outbox ?? SyncOutboxService.instance;

  final SyncService _syncService;
  final AuthService _authService;
  final SyncOutboxService _outbox;

  static const String _prefsGuestUploadPolicyKey = 'guest_upload_policy';

  Future<int> getGuestUploadPolicy() async => _loadGuestUploadPolicyRaw();

  Future<void> setGuestUploadPolicy(int value) async {
    if (value != 0 && value != 1 && value != 2) return;
    await _saveGuestUploadPolicyRaw(value);
  }

  Future<int> countGuestCreateOpsForCurrentBooks(BuildContext context) async {
    final bookProvider = context.read<BookProvider>();
    final bookIds = <String>{};
    final active = bookProvider.activeBookId;
    if (active.isNotEmpty) bookIds.add(active);
    for (final b in bookProvider.books) {
      if (b.id.isNotEmpty) bookIds.add(b.id);
    }
    return _outbox.countGuestCreateOps(bookIds: bookIds);
  }

  Future<int> _loadGuestUploadPolicyRaw() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsGuestUploadPolicyKey) ?? 0; // 0=ask,1=always,2=never
  }

  Future<void> _saveGuestUploadPolicyRaw(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsGuestUploadPolicyKey, value);
  }

  Future<({bool proceed, bool remember})> _promptGuestUpload(
    BuildContext context, {
    required int count,
  }) async {
    if (!context.mounted) return (proceed: false, remember: false);

    bool remember = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('同步本地数据到云端？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '检测到本地有 $count 条未同步记录。\n同步后可跨设备查看，并在卸载/换机时避免丢失。',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: remember,
                onChanged: (v) => setState(() => remember = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('记住我的选择'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('暂不同步'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('同步'),
            ),
          ],
        ),
      ),
    );
    return (proceed: result == true, remember: remember);
  }

  /// Do NOT force uploading guest-created records after login.
  /// If there are guest-created records (owner=0), prompt the user (unless a remembered policy exists).
  Future<void> maybeUploadGuestOutboxAfterLogin(
    BuildContext context, {
    String reason = 'login',
  }) async {
    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;

    final policy = await _loadGuestUploadPolicyRaw();

    if (!context.mounted) return;
    final bookProvider = context.read<BookProvider>();
    final bookIds = <String>{};
    final active = bookProvider.activeBookId;
    if (active.isNotEmpty) bookIds.add(active);
    for (final b in bookProvider.books) {
      if (b.id.isNotEmpty) bookIds.add(b.id);
    }

    final guestCount = await _outbox.countGuestCreateOps(
      bookIds: bookIds.toList(growable: false),
    );
    if (guestCount <= 0) return;

    if (policy == 2) {
      // never
      return;
    }
    if (policy == 1) {
      // always
      await pushAllOutboxAfterLogin(context, reason: reason);
      return;
    }

    final decision = await _promptGuestUpload(context, count: guestCount);
    if (!context.mounted) return;

    if (decision.remember) {
      await _saveGuestUploadPolicyRaw(decision.proceed ? 1 : 2);
    }
    if (!decision.proceed) return;

    await pushAllOutboxAfterLogin(context, reason: reason);
  }

  // Coalesce/throttle meta sync (categories/tags) to avoid duplicate queries within a short window.
  // Only throttle after a successful run so transient failures won't block retries.
  static const int _metaThrottleWindowMs = 15 * 1000;
  static final Map<String, int> _metaLastOkMs = <String, int>{};
  static final Map<String, Future<bool>> _metaInFlight = <String, Future<bool>>{};

  Future<int> _authUserIdOrZero() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auth_user_id') ?? 0;
  }

  Future<void> _runMetaThrottled(
    String key,
    Future<bool> Function() action, {
    bool bypassWindow = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastOk = _metaLastOkMs[key] ?? 0;
    if (!bypassWindow && now - lastOk < _metaThrottleWindowMs) return;

    final inFlight = _metaInFlight[key];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = () async {
      final ok = await action();
      if (ok) {
        _metaLastOkMs[key] = DateTime.now().millisecondsSinceEpoch;
      }
      return ok;
    }();
    _metaInFlight[key] = future;
    try {
      await future;
    } finally {
      _metaInFlight.remove(key);
    }
  }

  Future<void> syncActiveBook(BuildContext context) async {
    final bookId = context.read<BookProvider>().activeBookId;
    if (bookId.isEmpty) return;
    await syncBookV2(context, bookId);
  }

  /// After a user logs in, retry pushing any locally queued outbox operations that were created
  /// while unauthenticated. This fixes the case where an outbox sync was attempted earlier
  /// (token invalid) and no new outbox events are emitted after login.
  Future<void> pushAllOutboxAfterLogin(
    BuildContext context, {
    String reason = 'login',
  }) async {
    final bookProvider = context.read<BookProvider>();
    final recordProvider = context.read<RecordProvider>();

    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;

    // Migrate guest-created ops (owner=0) to the current user so records created before register/login
    // can be uploaded, while keeping stale ops from other accounts isolated.
    await _outbox.adoptGuestOutboxToCurrentUser();

    final bookIds = <String>{};
    final active = bookProvider.activeBookId;
    if (active.isNotEmpty) bookIds.add(active);
    for (final b in bookProvider.books) {
      if (b.id.isNotEmpty) bookIds.add(b.id);
    }

    for (final bid in bookIds) {
      await _uploadOutboxV2(recordProvider, bid, reason: reason);
    }
  }

  Future<void> syncBook(BuildContext context, String bookId) async {
    await syncBookV2(context, bookId);
  }

  Future<void> syncBookV2(
    BuildContext context,
    String bookId, {
    String reason = 'unknown',
  }) async {
    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();

    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;
    await _uploadOutboxV2(recordProvider, bookId, reason: reason);
    // 性能关键点：本地记账触发 outbox 变化时，先只 push（把本地变更上云）。
    // 立即 pull 会额外产生一轮 bill_change_log + bill_info 查询（服务端/客户端都浪费）。
    // 多设备变更的拉取由 app_start / app_resumed（以及未来可选的轮询/SSE）来覆盖。
    if (reason == 'local_outbox_changed') return;

    // Keep sync transparent but light-weight:
    // - Pull on app_start / app_resumed / periodic timers.
    // - Meta (categories/tags/budget/accounts/...) is scheduled separately by BackgroundSyncManager,
    //   to avoid duplicate requests/SQL during login/app_start flows.

    await _pullV2(
      recordProvider,
      accountProvider,
      bookId,
      reason: reason,
    );

    final shouldSummaryCheck = reason == 'app_start' || reason == 'app_resumed';
    if (shouldSummaryCheck) {
      await _maybeBootstrapFromSummary(
        recordProvider,
        accountProvider,
        bookId,
        reason: reason,
      );
    }
  }

  Future<void> forceBootstrapV2(
    BuildContext context,
    String bookId, {
    bool pushBeforePull = true,
  }) async {
    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final tagProvider = context.read<TagProvider>();
    final budgetProvider = context.read<BudgetProvider>();

    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;

    await SyncV2CursorStore.setLastChangeId(bookId, 0);
    await SyncV2ConflictStore.clear(bookId);
    await SyncV2SummaryStore.clear(bookId);

    if (pushBeforePull) {
      await _uploadOutboxV2(recordProvider, bookId, reason: 'force_bootstrap');
    }
    await _syncCategories(categoryProvider, bookId, reason: 'force_bootstrap');
    await _syncTags(tagProvider, bookId, reason: 'force_bootstrap');
    await _syncBudget(budgetProvider, bookId, reason: 'force_bootstrap');
    await _syncAccounts(accountProvider, recordProvider, bookId, reason: 'force_bootstrap');
    await _syncSavingsPlans(bookId, reason: 'force_bootstrap');
    await _pullV2(recordProvider, accountProvider, bookId, reason: 'force_bootstrap');
  }

  /// 同步“元数据”（预算/账户等低频数据）。
  /// 设计为低频触发：登录后、前台唤醒、进入资产页等场景。
  Future<bool> syncMeta(
    BuildContext context,
    String bookId, {
    String reason = 'unknown',
  }) async {
    final categoryProvider = context.read<CategoryProvider>();
    final tagProvider = context.read<TagProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final accountProvider = context.read<AccountProvider>();
    final recordProvider = context.read<RecordProvider>();

    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return false;
    // Avoid syncing unrelated meta on user-triggered changes to reduce backend load.
    // Full meta refresh still happens on app_start/app_resumed/meta_periodic/force_bootstrap.
    if (reason == 'categories_changed') {
      await _syncCategories(categoryProvider, bookId, reason: reason);
      return true;
    }
    if (reason == 'tags_changed') {
      await _syncTags(tagProvider, bookId, reason: reason);
      return true;
    }
    if (reason == 'budget_changed') {
      await _syncBudget(budgetProvider, bookId, reason: reason);
      return true;
    }
    if (reason == 'accounts_changed') {
      await _syncAccounts(accountProvider, recordProvider, bookId, reason: reason);
      return true;
    }
    if (reason == 'savings_plans_changed') {
      await _syncSavingsPlans(bookId, reason: reason);
      return true;
    }

    await _syncCategories(categoryProvider, bookId, reason: reason);
    await _syncTags(tagProvider, bookId, reason: reason);
    await _syncBudget(budgetProvider, bookId, reason: reason);
    await _syncAccounts(accountProvider, recordProvider, bookId, reason: reason);
    await _syncSavingsPlans(bookId, reason: reason);
    return true;
  }

  Future<void> _syncCategories(
    CategoryProvider? categoryProvider,
    String bookId, {
    required String reason,
  }) async {
    final uid = await _authUserIdOrZero();
    final bypassWindow =
        reason == 'categories_changed' || reason == 'force_bootstrap';
    await _runMetaThrottled(
      'meta_categories_u${uid}_b$bookId',
      () async {
      try {
        final repo = RepositoryFactory.createCategoryRepository();
        final rawCategories = await repo.loadCategories();
        final List<Category> categories = rawCategories is List<Category>
            ? rawCategories
            : (rawCategories as List).cast<Category>();
        final deletedKeys = await CategoryDeleteQueue.instance.load();

        // Download first to obtain server syncVersion baselines, without overwriting local edits.
        final download = await _syncService.downloadCategories(bookId: bookId);
        if (!download.success) {
          debugPrint('[SyncEngine] categories download failed: ${download.error}');
          return false;
        }
        final remote = (download.categories ?? const [])
            .map((m) => (m as Map).cast<String, dynamic>())
            .toList(growable: false);
        final remoteCats = remote.map(Category.fromMap).toList(growable: false);
        final remoteByKey = <String, Category>{};
        for (final c in remoteCats) {
          remoteByKey[c.key] = c;
        }

        bool needsUpload = deletedKeys.isNotEmpty;
        if (!needsUpload) {
          for (final c in categories) {
            final r = remoteByKey[c.key];
            if (r == null) {
              needsUpload = true;
              break;
            }
            final unchanged =
                r.name == c.name &&
                r.isExpense == c.isExpense &&
                r.parentKey == c.parentKey &&
                r.icon.codePoint == c.icon.codePoint &&
                r.icon.fontFamily == c.icon.fontFamily &&
                r.icon.fontPackage == c.icon.fontPackage;
            if (!unchanged) {
              needsUpload = true;
              break;
            }
          }
        }
        final List<Category> merged = categories
            .map((c) => c.copyWith(syncVersion: c.syncVersion ?? remoteByKey[c.key]?.syncVersion))
            .toList(growable: false);

        if (!needsUpload) {
          // No local edits/deletes: apply server view and skip upload to reduce SQL.
          await repo.saveCategories(remoteCats);
          if (categoryProvider != null) {
            try {
              categoryProvider.replaceFromCloud(remoteCats);
            } catch (_) {}
          }
          return true;
        }

        final payload = merged.map((c) => c.toMap()).toList(growable: false);
        final upload = await _syncService.uploadCategories(
          bookId: bookId,
          categories: payload,
          deletedKeys: deletedKeys,
        );
        if (!upload.success) {
          debugPrint('[SyncEngine] categories upload failed: ${upload.error}');
        }
        if (upload.success) {
          await CategoryDeleteQueue.instance.clear();
        }

        // Apply server authoritative view.
        // uploadCategories already returns categories; prefer it to avoid an extra download.
        final authoritative = upload.success && upload.categories != null
            ? upload.categories!
            : (download.categories ?? const []);
        final remote2 = (authoritative)
            .map((m) => (m as Map).cast<String, dynamic>())
            .toList(growable: false);
        final remoteCats2 = remote2.map(Category.fromMap).toList(growable: false);
        await repo.saveCategories(remoteCats2);
        if (categoryProvider != null) {
          try {
            categoryProvider.replaceFromCloud(remoteCats2);
          } catch (_) {}
        }
        return true;
      } catch (e) {
        debugPrint('[SyncEngine] categories sync failed: $e');
        return false;
      }
    },
      bypassWindow: bypassWindow,
    );
  }

  Future<void> _syncTags(
    TagProvider? tagProvider,
    String bookId, {
    required String reason,
  }) async {
    final uid = await _authUserIdOrZero();
    final bypassWindow = reason == 'tags_changed' || reason == 'force_bootstrap';
    await _runMetaThrottled(
      'meta_tags_u${uid}_b$bookId',
      () async {
      try {
        final repo = RepositoryFactory.createTagRepository();
        final rawTags = await repo.loadTags(bookId: bookId);
        final List<Tag> tags =
            rawTags is List<Tag> ? rawTags : (rawTags as List).cast<Tag>();
        final deletedByBook = await TagDeleteQueue.instance.load();
        final deleted = deletedByBook[bookId] ?? const <String>[];

        // Download first to obtain server syncVersion baselines, without overwriting local edits.
        final download = await _syncService.downloadTags(bookId: bookId);
        if (!download.success) {
          debugPrint('[SyncEngine] tags download failed: ${download.error}');
          return false;
        }
        final remote = (download.tags ?? const [])
            .map((m) => (m as Map).cast<String, dynamic>())
            .toList(growable: false);
        final remoteTags = remote.map(Tag.fromMap).toList(growable: false);
        final remoteById = <String, Tag>{};
        for (final t in remoteTags) {
          remoteById[t.id] = t;
        }

        bool needsUpload = deleted.isNotEmpty;
        if (!needsUpload) {
          for (final t in tags) {
            final r = remoteById[t.id];
            if (r == null) {
              needsUpload = true;
              break;
            }
            final unchanged = r.bookId == t.bookId &&
                r.name == t.name &&
                r.colorValue == t.colorValue &&
                r.sortOrder == t.sortOrder;
            if (!unchanged) {
              needsUpload = true;
              break;
            }
          }
        }
        final List<Tag> merged = tags
            .map((t) => t.copyWith(syncVersion: t.syncVersion ?? remoteById[t.id]?.syncVersion))
            .toList(growable: false);

        if (!needsUpload) {
          // No local edits/deletes: apply server view and skip upload to reduce SQL.
          await repo.saveTagsForBook(bookId, remoteTags);
          if (tagProvider != null) {
            try {
              tagProvider.replaceFromCloud(bookId, remoteTags);
            } catch (_) {}
          }
          return true;
        }

        final payload = merged
            .map(
              (t) => <String, dynamic>{
                'id': t.id,
                'bookId': bookId,
                'name': t.name,
                'syncVersion': t.syncVersion,
                'colorValue': t.colorValue,
                'sortOrder': t.sortOrder,
                'createdAt': t.createdAt?.toIso8601String(),
                'updatedAt': t.updatedAt?.toIso8601String(),
              },
            )
            .toList(growable: false);

        final upload = await _syncService.uploadTags(
          bookId: bookId,
          tags: payload,
          deletedTagIds: deleted,
        );
        if (!upload.success) {
          debugPrint('[SyncEngine] tags upload failed: ${upload.error}');
        }
        if (upload.success) {
          await TagDeleteQueue.instance.clearBook(bookId);
        }

        // Apply server authoritative view.
        // uploadTags already returns tags; prefer it to avoid an extra download.
        final authoritative = upload.success && upload.tags != null
            ? upload.tags!
            : (download.tags ?? const []);
        final remote2 = (authoritative)
            .map((m) => (m as Map).cast<String, dynamic>())
            .toList(growable: false);
        final remoteTags2 = remote2.map(Tag.fromMap).toList(growable: false);
        await repo.saveTagsForBook(bookId, remoteTags2);
        if (tagProvider != null) {
          try {
            tagProvider.replaceFromCloud(bookId, remoteTags2);
          } catch (_) {}
        }
        return true;
      } catch (e) {
        debugPrint('[SyncEngine] tags sync failed: $e');
        return false;
      }
    },
      bypassWindow: bypassWindow,
    );
  }

  Future<void> _uploadOutboxV2(
    RecordProvider recordProvider,
    String bookId, {
    required String reason,
  }) async {
    while (true) {
      // 批处理性能关键：尽量把同一本账本的 outbox 聚合到一次 push
      final pending = await _outbox.loadPending(bookId, limit: 1000);
      if (pending.isEmpty) return;

      await _assignServerIdsForCreates(recordProvider, bookId, pending, reason: reason);

      final ops = pending.map((e) => e.payload).toList(growable: false);
      final resp = await _syncService.v2Push(
        bookId: bookId,
        ops: ops,
        reason: reason,
      );
      if (resp['success'] != true) {
        debugPrint('[SyncEngine] v2Push failed: ${resp['error']}');
        return;
      }

      final results = (resp['results'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final resultByOpId = <String, Map<String, dynamic>>{};
      for (final r in results) {
        final opId = r['opId'] as String?;
        if (opId != null) resultByOpId[opId] = r;
      }

      final toDelete = <SyncOutboxItem>[];
      final toUpdate = <SyncOutboxItem>[];
      final syncStateUpdates =
          <({String billId, int? serverId, int? serverVersion})>[];
      for (final item in pending) {
        final opId = item.payload['opId'] as String?;
        if (opId == null) {
          final syntheticOpId = 'missing-opid-${DateTime.now().microsecondsSinceEpoch}';
          await SyncV2ConflictStore.addConflict(bookId, {
            'opId': syntheticOpId,
            'localOp': item.payload,
            'error': 'missing opId in outbox payload',
          });
          toDelete.add(item);
          continue;
        }
        final r = resultByOpId[opId];
        if (r == null) {
          // Server response missing this opId: keep it for retry with a capped attempt counter.
          debugPrint('[SyncEngine] v2Push missing result for opId=$opId');
          final bumped = SyncV2PushRetry.bumpAttempt(
            item.payload,
            error: 'missing server result',
          );
          if (SyncV2PushRetry.shouldQuarantine(bumped)) {
            await SyncV2ConflictStore.addConflict(bookId, {
              'opId': opId,
              'localOp': item.payload,
              'error': 'missing server result (exceeded retry)',
            });
            toDelete.add(item);
          } else {
            toUpdate.add(
              SyncOutboxItem(
                id: item.id,
                bookId: item.bookId,
                op: item.op,
                payload: bumped,
                createdAtMs: item.createdAtMs,
              ),
            );
          }
          continue;
        }

        final status = r['status'] as String?;
        if (status == 'applied') {
          // 如果之前同一个 opId 曾被记录为冲突/错误，成功后自动移除，避免残留提示。
          await SyncV2ConflictStore.remove(bookId, opId: opId);
          final type = item.payload['type'] as String?;
          if (type == 'upsert') {
            final bill = (item.payload['bill'] as Map?)?.cast<String, dynamic>();
            final localId = bill?['localId'] as String?;
            final serverId = r['serverId'] as int?;
            final version = r['version'] as int?;
            if (localId != null && serverId != null) {
              syncStateUpdates.add(
                (billId: localId, serverId: serverId, serverVersion: version),
              );
            } else {
              // Unexpected: server says applied but missing critical fields; keep for retry.
              final bumped = SyncV2PushRetry.bumpAttempt(
                item.payload,
                error: 'applied but missing serverId/localId',
              );
              if (SyncV2PushRetry.shouldQuarantine(bumped)) {
                await SyncV2ConflictStore.addConflict(bookId, {
                  'opId': opId,
                  'localOp': item.payload,
                  'serverId': r['serverId'],
                  'serverVersion': r['version'],
                  'error': 'applied but missing serverId/localId (exceeded retry)',
                  'serverBill': r['serverBill'],
                });
                toDelete.add(item);
              } else {
                toUpdate.add(
                  SyncOutboxItem(
                    id: item.id,
                    bookId: item.bookId,
                    op: item.op,
                    payload: bumped,
                    createdAtMs: item.createdAtMs,
                  ),
                );
              }
              continue;
            }
          }
          toDelete.add(item);
        } else if (status == 'conflict') {
          final type = item.payload['type'] as String?;
          final serverBill = (r['serverBill'] as Map?)?.cast<String, dynamic>();
          if (type == 'upsert' && serverBill != null) {
            final bill = (item.payload['bill'] as Map?)?.cast<String, dynamic>();
            final localId = bill?['localId'] as String?;

            bool numEq(dynamic a, dynamic b) {
              if (a == null && b == null) return true;
              if (a is num && b is num) return (a - b).abs() < 0.0001;
              return a?.toString() == b?.toString();
            }

            bool listEq(dynamic a, dynamic b) {
              List<String> norm(dynamic v) {
                if (v is List) {
                  return v.map((e) => e.toString()).toList()..sort();
                }
                if (v == null) return const <String>[];
                return <String>[v.toString()]..sort();
              }

              final la = norm(a);
              final lb = norm(b);
              if (la.length != lb.length) return false;
              for (var i = 0; i < la.length; i++) {
                if (la[i] != lb[i]) return false;
              }
              return true;
            }

            final same = bill != null &&
                (bill['bookId']?.toString() == serverBill['bookId']?.toString()) &&
                (bill['accountId']?.toString() == serverBill['accountId']?.toString()) &&
                (bill['categoryKey']?.toString() ==
                    serverBill['categoryKey']?.toString()) &&
                numEq(bill['amount'], serverBill['amount']) &&
                (bill['direction']?.toString() == serverBill['direction']?.toString()) &&
                (bill['remark']?.toString() == serverBill['remark']?.toString()) &&
                (bill['billDate']?.toString() == serverBill['billDate']?.toString()) &&
                (bill['includeInStats']?.toString() ==
                    serverBill['includeInStats']?.toString()) &&
                (bill['pairId']?.toString() == serverBill['pairId']?.toString()) &&
                listEq(bill['tagIds'], serverBill['tagIds']) &&
                (bill['isDelete']?.toString() == serverBill['isDelete']?.toString());

            if (same && localId != null) {
              final serverId =
                  (r['serverId'] as int?) ?? (serverBill['serverId'] as int?);
              final version = r['version'] as int?;
              if (serverId != null) {
                syncStateUpdates.add(
                  (billId: localId, serverId: serverId, serverVersion: version),
                );
                await SyncV2ConflictStore.remove(bookId, opId: opId);
                toDelete.add(item);
                continue;
              }
            }
          }

          await SyncV2ConflictStore.addConflict(bookId, {
            'opId': opId,
            'localOp': item.payload,
            'serverId': r['serverId'],
            'serverVersion': r['version'],
            'serverBill': r['serverBill'],
          });
          toDelete.add(item);
        } else {
          // error/unknown: retry a few times (transient failures), then quarantine to conflict store.
          final retryable = r['retryable'] as bool?;
          final err = (r['error'] as String?) ?? 'status=$status';
          if (retryable == false) {
            await SyncV2ConflictStore.addConflict(bookId, {
              'opId': opId,
              'localOp': item.payload,
              'serverId': r['serverId'],
              'serverVersion': r['version'],
              'error': err,
              'serverBill': r['serverBill'],
            });
            toDelete.add(item);
          } else {
            final bumped = SyncV2PushRetry.bumpAttempt(item.payload, error: err);
            if (SyncV2PushRetry.shouldQuarantine(bumped)) {
              await SyncV2ConflictStore.addConflict(bookId, {
                'opId': opId,
                'localOp': item.payload,
                'serverId': r['serverId'],
                'serverVersion': r['version'],
                'error': err,
                'serverBill': r['serverBill'],
              });
              toDelete.add(item);
            } else {
              toUpdate.add(
                SyncOutboxItem(
                  id: item.id,
                  bookId: item.bookId,
                  op: item.op,
                  payload: bumped,
                  createdAtMs: item.createdAtMs,
                ),
              );
            }
          }
        }
      }

      // 无进展保护：避免 while(true) 无限循环
      if (toDelete.isEmpty && toUpdate.isEmpty) {
        debugPrint('[SyncEngine] v2Push made no progress; stop this cycle');
        return;
      }

      if (syncStateUpdates.isNotEmpty) {
        await recordProvider.setServerSyncStatesBulk(syncStateUpdates);
      }
      if (toUpdate.isNotEmpty) {
        await _outbox.updateItems(bookId, toUpdate);
      }
      if (toDelete.isNotEmpty) {
        await _outbox.deleteItems(bookId, toDelete);
      }

      // 如果还有未处理项（缺结果等），留待下一次触发，避免本次循环内反复重试
      if (toDelete.length < pending.length) return;
      if (toUpdate.isNotEmpty) return;
    }
  }

  Future<void> _assignServerIdsForCreates(
    RecordProvider recordProvider,
    String bookId,
    List<SyncOutboxItem> pending, {
    required String reason,
  }) async {
    final creates = <SyncOutboxItem>[];
    for (final it in pending) {
      final type = it.payload['type'] as String?;
      if (type != 'upsert') continue;
      final bill = (it.payload['bill'] as Map?)?.cast<String, dynamic>();
      if (bill == null) continue;
      final serverId = bill['serverId'] as int? ?? bill['id'] as int?;
      if (serverId != null) continue;
      creates.add(it);
    }
    if (creates.isEmpty) return;

    final alloc = await _syncService.v2AllocateBillIds(
      count: creates.length,
      reason: reason,
    );
    if (alloc['success'] != true) {
      debugPrint(
          '[SyncEngine] v2AllocateBillIds failed: ${alloc['error']} (creates=${creates.length})');
      return;
    }
    final startId = alloc['startId'] as int?;
    if (startId == null) return;
    debugPrint(
        '[SyncEngine] allocated bill ids start=$startId count=${creates.length} reason=$reason');

    final updated = <SyncOutboxItem>[];
    var next = startId;
    for (final it in creates) {
      final bill = (it.payload['bill'] as Map).cast<String, dynamic>();
      final localId = bill['localId'] as String?;
      final assigned = next++;

      bill['serverId'] = assigned;
      bill['id'] = assigned;
      it.payload['expectedVersion'] = 0;
      it.payload['bill'] = bill;

      updated.add(
        SyncOutboxItem(
          id: it.id,
          bookId: it.bookId,
          op: it.op,
          payload: it.payload,
          createdAtMs: it.createdAtMs,
        ),
      );

      if (localId != null) {
        await recordProvider.setServerSyncState(localId, serverId: assigned);
      }
    }

    await _outbox.updateItems(bookId, updated);
  }

  Future<void> _pullV2(
    RecordProvider recordProvider,
    AccountProvider accountProvider,
    String bookId, {
    required String reason,
  }) async {
    var cursor = await SyncV2CursorStore.getLastChangeId(bookId);
    const pageSize = 200;
    const maxPagesPerSync = 50;
    var pages = 0;

    while (true) {
      pages++;
      if (pages > maxPagesPerSync) {
        debugPrint('[SyncEngine] v2Pull reached max pages; stop (book=$bookId)');
        return;
      }

      final prevCursor = cursor;
      final resp = await _syncService.v2Pull(
        bookId: bookId,
        afterChangeId: cursor == 0 ? null : cursor,
        limit: pageSize,
        reason: reason,
      );
      if (resp['success'] != true) {
        debugPrint('[SyncEngine] v2Pull failed: ${resp['error']}');
        return;
      }

      if (resp['cursorExpired'] == true) {
        debugPrint(
          '[SyncEngine] v2Pull cursorExpired book=$bookId prevCursor=$prevCursor minKept=${resp['minKeptChangeId']}',
        );
        cursor = 0;
        pages = 0;
        await SyncV2CursorStore.setLastChangeId(bookId, 0);
        continue;
      }

      final changes = (resp['changes'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      final next = changes.isEmpty
          ? prevCursor
          : SyncV2PullUtils.computeNextCursor(
              previousCursor: prevCursor,
              nextChangeIdFromServer: resp['nextChangeId'],
              changes: changes,
            );

      if (changes.isNotEmpty) {
        await _outbox.runSuppressed(() async {
          await DataVersionService.runWithoutIncrement(() async {
            // 性能关键：DB 模式下批量应用变更，避免逐条 add/update/delete 触发大量 notify/落库。
            if (RepositoryFactory.isUsingDatabase) {
              final repo = RepositoryFactory.createRecordRepository();
              if (repo is RecordRepositoryDb) {
                final bills = <Map<String, dynamic>>[];
                for (final c in changes) {
                  final bill = (c['bill'] as Map?)?.cast<String, dynamic>();
                  if (bill != null) bills.add(bill);
                }
                if (bills.isNotEmpty) {
                  await repo.applyCloudBillsV2(bookId: bookId, bills: bills);
                  // 同步后：刷新最近记录缓存 + 统一重算余额（一次落库/一次 notify）
                  await recordProvider.refreshRecentCache(bookId: bookId);
                  await accountProvider.refreshBalancesFromRecords();
                }
              } else {
                for (final c in changes) {
                  final bill = (c['bill'] as Map?)?.cast<String, dynamic>();
                  if (bill == null) continue;
                  await _applyCloudBill(
                    bill,
                    recordProvider: recordProvider,
                    accountProvider: accountProvider,
                  );
                }
              }
            } else {
              for (final c in changes) {
                final bill = (c['bill'] as Map?)?.cast<String, dynamic>();
                if (bill == null) continue;
                await _applyCloudBill(
                  bill,
                  recordProvider: recordProvider,
                  accountProvider: accountProvider,
                );
              }
            }
          });
        });
      }

      final hasMore = resp['hasMore'] as bool? ?? false;
      if (hasMore && next <= prevCursor) {
        debugPrint('[SyncEngine] v2Pull hasMore but cursor not advanced; stop to avoid loop');
        return;
      }

      if (next > prevCursor) {
        cursor = next;
        await SyncV2CursorStore.setLastChangeId(bookId, cursor);
      }
      if (!hasMore) break;
    }
  }

  Future<void> _maybeBootstrapFromSummary(
    RecordProvider recordProvider,
    AccountProvider accountProvider,
    String bookId, {
    required String reason,
  }) async {
    try {
      if (!await SyncV2SummaryStore.shouldCheck(bookId)) return;

      final pending = await _outbox.loadPending(bookId, limit: 1);
      if (pending.isNotEmpty) return;

      final resp = await _syncService.v2Summary(
        bookId: bookId,
        reason: reason.isNotEmpty ? '$reason:summary_check' : 'summary_check',
      );
      if (resp['success'] != true) return;
      await SyncV2SummaryStore.markChecked(bookId);

      final summary = (resp['summary'] as Map?)?.cast<String, dynamic>();
      if (summary == null) return;

      final serverMaxChangeId = (summary['maxChangeId'] as num?)?.toInt() ?? 0;
      final serverBillCount = (summary['billCount'] as num?)?.toInt() ?? 0;
      final serverSumIds = (summary['sumIds'] as num?)?.toInt() ?? 0;
      final serverSumVersions = (summary['sumVersions'] as num?)?.toInt() ?? 0;
      if (serverBillCount <= 0 || serverMaxChangeId <= 0) return;

      final localCursor = await SyncV2CursorStore.getLastChangeId(bookId);
      if (localCursor != serverMaxChangeId) return;

      final localSyncedCount = await _countLocalSyncedRecords(recordProvider, bookId);
      final localAgg = await _localSyncedAgg(recordProvider, bookId);
      final bool ok =
          localSyncedCount == serverBillCount &&
          localAgg.sumIds == serverSumIds &&
          localAgg.sumVersions == serverSumVersions;
      if (ok) return;

      // Likely local data loss / reset with a stale cursor. Bootstrap by resetting cursor.
      debugPrint(
          '[SyncEngine] v2 summary mismatch; bootstrap pull book=$bookId localSynced=$localSyncedCount serverBillCount=$serverBillCount cursor=$localCursor');
      await SyncV2CursorStore.setLastChangeId(bookId, 0);
      await _pullV2(
        recordProvider,
        accountProvider,
        bookId,
        reason: 'bootstrap_summary_mismatch',
      );
    } catch (e) {
      debugPrint('[SyncEngine] v2 summary check failed: $e');
    }
  }

  Future<({int sumIds, int sumVersions})> _localSyncedAgg(
    RecordProvider recordProvider,
    String bookId,
  ) async {
    int sumIds = 0;
    int sumVersions = 0;
    if (RepositoryFactory.isUsingDatabase) {
      try {
        final repo = RepositoryFactory.createRecordRepository();
        if (repo is RecordRepositoryDb) {
          return await repo.sumSyncedAgg(bookId: bookId);
        }
      } catch (_) {
        // Fall back to in-memory calculation.
      }
    }
    for (final r in recordProvider.recordsForBook(bookId)) {
      final sid = r.serverId;
      if (sid == null) continue;
      sumIds += sid;
      sumVersions += r.serverVersion ?? 0;
    }
    return (sumIds: sumIds, sumVersions: sumVersions);
  }

  Future<int> _countLocalSyncedRecords(RecordProvider recordProvider, String bookId) async {
    if (RepositoryFactory.isUsingDatabase) {
      try {
        final repo = RepositoryFactory.createRecordRepository();
        if (repo is RecordRepositoryDb) {
          return await repo.countSyncedRecords(bookId: bookId);
        }
      } catch (_) {}
    }
    return recordProvider
        .recordsForBook(bookId)
        .where((r) => r.serverId != null)
        .length;
  }

  Record _mapToRecord(Map<String, dynamic> map) {
    final serverId = map['id'] as int? ?? map['serverId'] as int?;
    final serverVersion = map['version'] as int? ?? map['serverVersion'] as int?;
    final createdByUserId = (() {
      final raw = map['userId'] ?? map['createdByUserId'];
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    })();

    double parseAmount(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    return Record(
      id: serverId != null ? 'server_$serverId' : _generateTempId(),
      serverId: serverId,
      serverVersion: serverVersion,
      createdByUserId: createdByUserId,
      amount: parseAmount(map['amount']),
      remark: map['remark'] as String? ?? '',
      date: DateTime.parse(map['billDate'] as String),
      categoryKey: map['categoryKey'] as String,
      bookId: map['bookId'] as String,
      accountId: map['accountId'] as String,
      direction: (map['direction'] as int) == 1
          ? TransactionDirection.income
          : TransactionDirection.out,
      includeInStats: (map['includeInStats'] as int? ?? 1) == 1,
      pairId: map['pairId'] as String?,
    );
  }

  String _generateTempId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (100000 + (DateTime.now().microsecond % 900000)).toString();
  }

  Future<Record?> _findLocalByServerId(
    int serverId, {
    required String bookId,
    required RecordProvider recordProvider,
  }) async {
    if (RepositoryFactory.isUsingDatabase) {
      final repo = RepositoryFactory.createRecordRepository() as dynamic;
      try {
        final Record? found =
            await repo.loadRecordByServerId(serverId, bookId: bookId);
        if (found != null) return found;
      } catch (_) {}
    }
    try {
      return recordProvider.records.firstWhere(
        (r) => r.serverId == serverId && r.bookId == bookId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyCloudBill(
    Map<String, dynamic> billMap, {
    required RecordProvider recordProvider,
    required AccountProvider accountProvider,
  }) async {
    final serverId = billMap['id'] as int? ?? billMap['serverId'] as int?;
    if (serverId == null) return;
    final isDelete = (billMap['isDelete'] as int? ?? 0) == 1;
    final serverVersion =
        billMap['version'] as int? ?? billMap['serverVersion'] as int?;
    final bookId = billMap['bookId'] as String? ?? '';

    final existing = await _findLocalByServerId(
      serverId,
      bookId: bookId,
      recordProvider: recordProvider,
    );

    if (existing != null &&
        serverVersion != null &&
        existing.serverVersion != null &&
        serverVersion <= existing.serverVersion!) {
      return;
    }

    if (isDelete) {
      if (existing != null) {
        await recordProvider.deleteRecord(existing.id, accountProvider: accountProvider);
        try {
          final tagRepo = RepositoryFactory.createTagRepository();
          await tagRepo.deleteLinksForRecord(existing.id);
        } catch (_) {}
      }
      return;
    }

    final cloudRecord = _mapToRecord(billMap);
    final rawTagIds = billMap['tagIds'];
    final tagIds = rawTagIds is List
        ? rawTagIds.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    if (existing != null) {
      final updated = existing.copyWith(
        serverId: serverId,
        serverVersion: serverVersion,
        createdByUserId: cloudRecord.createdByUserId ?? existing.createdByUserId,
        amount: cloudRecord.amount,
        remark: cloudRecord.remark,
        date: cloudRecord.date,
        categoryKey: cloudRecord.categoryKey,
        bookId: cloudRecord.bookId,
        accountId: cloudRecord.accountId,
        direction: cloudRecord.direction,
        includeInStats: cloudRecord.includeInStats,
        pairId: cloudRecord.pairId,
      );
      await recordProvider.updateRecord(updated, accountProvider: accountProvider);
      if (tagIds.isNotEmpty) {
        try {
          final tagRepo = RepositoryFactory.createTagRepository();
          await tagRepo.setTagsForRecord(existing.id, tagIds);
        } catch (_) {}
      }
      return;
    }

    final created = await recordProvider.addRecord(
      amount: cloudRecord.amount,
      remark: cloudRecord.remark,
      date: cloudRecord.date,
      categoryKey: cloudRecord.categoryKey,
      bookId: cloudRecord.bookId,
      accountId: cloudRecord.accountId,
      direction: cloudRecord.direction,
      includeInStats: cloudRecord.includeInStats,
      pairId: cloudRecord.pairId,
      createdByUserId: cloudRecord.createdByUserId ?? 0,
      accountProvider: accountProvider,
    );
    await recordProvider.setServerSyncState(
      created.id,
      serverId: serverId,
      serverVersion: serverVersion,
    );
    if (tagIds.isNotEmpty) {
      try {
        final tagRepo = RepositoryFactory.createTagRepository();
        await tagRepo.setTagsForRecord(created.id, tagIds);
      } catch (_) {}
    }
  }

  Future<void> _syncSavingsPlans(
    String bookId, {
    required String reason,
  }) async {
    final uid = await _authUserIdOrZero();
    final bypassWindow =
        reason == 'savings_plans_changed' || reason == 'force_bootstrap';
    await _runMetaThrottled(
      'meta_savings_plans_u${uid}_b$bookId',
      () async {
        try {
          debugPrint('[SyncEngine] savings plans sync book=$bookId reason=$reason');
          final repo = SavingsPlanRepository();
          final localPlans = await repo.loadPlans(bookId: bookId);
          final deletedIds =
              await SavingsPlanDeleteQueue.instance.loadForBook(bookId);

          final download =
              await _syncService.downloadSavingsPlans(bookId: bookId);
          if (!download.success) {
            debugPrint(
              '[SyncEngine] savings plans download failed: ${download.error}',
            );
            return false;
          }
          final remoteRaw = download.savingsPlans ?? const <Map<String, dynamic>>[];
          final remotePlans = <SavingsPlan>[];
          final remoteDeleted = <String>{};
          for (final m in remoteRaw) {
            final isDelete = (m['isDelete'] == true) ||
                (m['isDelete'] is num && (m['isDelete'] as num).toInt() == 1);
            final pid = (m['id'] ?? '').toString();
            if (pid.isEmpty) continue;
            if (isDelete) {
              remoteDeleted.add(pid);
            } else {
              try {
                remotePlans.add(SavingsPlan.fromMap(m));
              } catch (_) {}
            }
          }

          final remoteById = <String, SavingsPlan>{};
          for (final p in remotePlans) {
            remoteById[p.id] = p;
          }

          final mergedLocal = localPlans
              .map(
                (p) => p.syncVersion != null
                    ? p
                    : p.copyWith(syncVersion: remoteById[p.id]?.syncVersion),
              )
              .toList(growable: false);

          bool needsUpload = deletedIds.isNotEmpty;
          if (!needsUpload) {
            for (final p in mergedLocal) {
              final r = remoteById[p.id];
              if (r == null) {
                needsUpload = true;
                break;
              }
              // Compare business fields only (syncVersion is only for concurrency).
              final unchanged =
                  p.bookId == r.bookId &&
                  p.accountId == r.accountId &&
                  p.name == r.name &&
                  p.type == r.type &&
                  p.targetAmount == r.targetAmount &&
                  p.includeInStats == r.includeInStats &&
                  p.savedAmount == r.savedAmount &&
                  p.archived == r.archived &&
                  p.startDate == r.startDate &&
                  p.endDate == r.endDate &&
                  p.monthlyDay == r.monthlyDay &&
                  p.monthlyAmount == r.monthlyAmount &&
                  p.weeklyWeekday == r.weeklyWeekday &&
                  p.weeklyAmount == r.weeklyAmount &&
                  p.executedCount == r.executedCount &&
                  p.lastExecutedAt == r.lastExecutedAt &&
                  p.defaultFromAccountId == r.defaultFromAccountId;
              if (!unchanged) {
                needsUpload = true;
                break;
              }
            }
          }

          if (!needsUpload) {
            // No local edits/deletes: apply server view and skip upload to reduce SQL.
            final filtered = remotePlans
                .where((p) => !remoteDeleted.contains(p.id))
                .toList(growable: false);
            await repo.replacePlansForBook(bookId, filtered);
            return true;
          }

          final payload = mergedLocal.map((p) => p.toMap()).toList(growable: false);
          final upload = await _syncService.uploadSavingsPlans(
            bookId: bookId,
            plans: payload,
            deletedIds: deletedIds,
          );
          if (!upload.success) {
            debugPrint('[SyncEngine] savings plans upload failed: ${upload.error}');
            final err = (upload.error ?? '').toLowerCase();
            final isConflict = err.contains('conflict') || err.contains('syncversion');
            if (isConflict) {
              await SavingsPlanConflictBackupStore.save(
                bookId,
                mergedLocal.map((p) => p.toMap()).toList(growable: false),
              );
            }
            return false;
          }

          final serverRaw = upload.savingsPlans ?? const <Map<String, dynamic>>[];
          final nextPlans = <SavingsPlan>[];
          final serverDeleted = <String>{};
          for (final m in serverRaw) {
            final isDelete = (m['isDelete'] == true) ||
                (m['isDelete'] is num && (m['isDelete'] as num).toInt() == 1);
            final pid = (m['id'] ?? '').toString();
            if (pid.isEmpty) continue;
            if (isDelete) {
              serverDeleted.add(pid);
              continue;
            }
            try {
              nextPlans.add(SavingsPlan.fromMap(m));
            } catch (_) {}
          }

          final filtered = nextPlans
              .where((p) => !serverDeleted.contains(p.id))
              .where((p) => !remoteDeleted.contains(p.id))
              .toList(growable: false);
          await repo.replacePlansForBook(bookId, filtered);
          await SavingsPlanDeleteQueue.instance.clearBook(bookId);
          return true;
        } catch (e) {
          debugPrint('[SyncEngine] savings plans sync failed: $e');
          return false;
        }
      },
      bypassWindow: bypassWindow,
    );
  }

  Future<void> _syncBudget(
    BudgetProvider budgetProvider,
    String bookId, {
    required String reason,
  }) async {
    final uid = await _authUserIdOrZero();
    await _runMetaThrottled(
      'meta_budget_u${uid}_b$bookId',
      () async {
        await _syncBudgetRaw(budgetProvider, bookId, reason: reason);
        return true;
      },
      // Budget sync should not run concurrently (duplicate SQL) but should still be allowed
      // whenever requested; bypass the time window and only coalesce in-flight requests.
      bypassWindow: true,
    );
  }

  Future<void> _syncBudgetRaw(
    BudgetProvider budgetProvider,
    String bookId, {
    required String reason,
  }) async {
    try {
      debugPrint('[SyncEngine] budget sync book=$bookId reason=$reason');
      final budgetEntry = budgetProvider.budgetForBook(bookId);
      final localEditMs = await BudgetSyncStateStore.getLocalEditMs(bookId);
      final localBaseSyncVersion =
          await BudgetSyncStateStore.getLocalBaseSyncVersion(bookId);

      final downloadResult = await _syncService.downloadBudget(bookId: bookId);
      if (!downloadResult.success) {
        debugPrint('[SyncEngine] budget download failed: ${downloadResult.error}');
        return;
      }

      final cloudBudget = Map<String, dynamic>.from(
        downloadResult.budget ?? const <String, dynamic>{},
      );
      final cloudSyncVersion = (() {
        final raw = cloudBudget['syncVersion'];
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw.trim()) ?? 0;
        return 0;
      })();
      final cloudHasBaseline =
          cloudBudget.containsKey('syncVersion') && cloudSyncVersion > 0;
      final cloudUpdateTimeRaw = cloudBudget['updateTime'] as String?;
      final cloudMs = (() {
        if (cloudUpdateTimeRaw == null || cloudUpdateTimeRaw.isEmpty) return 0;
        final dt = DateTime.tryParse(cloudUpdateTimeRaw);
        return dt?.millisecondsSinceEpoch ?? 0;
      })();
      if (cloudMs > 0) {
        await BudgetSyncStateStore.setServerUpdateMs(bookId, cloudMs);
      }
      if (cloudSyncVersion > 0) {
        await BudgetSyncStateStore.setServerSyncVersion(bookId, cloudSyncVersion);
      }

      // If local has unsynced edits, try uploading using syncVersion (optimistic concurrency).
      var keepLocalDueToUploadFailure = false;
      if (localEditMs > 0) {
        final localBudgetData = <String, dynamic>{
          'total': budgetEntry.total,
          'categoryBudgets': budgetEntry.categoryBudgets,
          'periodStartDay': budgetEntry.periodStartDay,
          'annualTotal': budgetEntry.annualTotal,
          'annualCategoryBudgets': budgetEntry.annualCategoryBudgets,
          'updateTime':
              DateTime.fromMillisecondsSinceEpoch(localEditMs).toIso8601String(),
          if (cloudHasBaseline) 'syncVersion': localBaseSyncVersion,
        };

        if (!cloudHasBaseline) {
          // First-time budget: server has no row yet -> upload without syncVersion to create.
          final uploadResult = await _syncService.uploadBudget(
            bookId: bookId,
            budgetData: localBudgetData,
          );
          if (!uploadResult.success) {
            debugPrint(
              '[SyncEngine] budget initial upload failed: ${uploadResult.error}',
            );
            keepLocalDueToUploadFailure = true;
          } else {
            final refreshed = await _syncService.downloadBudget(bookId: bookId);
            if (!refreshed.success) {
              debugPrint(
                '[SyncEngine] budget refresh download failed: ${refreshed.error}',
              );
              keepLocalDueToUploadFailure = true;
            } else {
              cloudBudget
                ..clear()
                ..addAll(refreshed.budget ?? const <String, dynamic>{});
              final refreshedSyncVersion = (() {
                final raw = cloudBudget['syncVersion'];
                if (raw is num) return raw.toInt();
                if (raw is String) return int.tryParse(raw.trim()) ?? 0;
                return 0;
              })();
              if (refreshedSyncVersion > 0) {
                await BudgetSyncStateStore.setServerSyncVersion(
                  bookId,
                  refreshedSyncVersion,
                );
                await BudgetSyncStateStore.setLocalBaseSyncVersion(
                  bookId,
                  refreshedSyncVersion,
                );
              }
            }
          }
        } else {
          final localBaseUnknown = localBaseSyncVersion <= 0;
          final versionMismatch = localBaseSyncVersion != cloudSyncVersion;
          if (localBaseUnknown || versionMismatch) {
            await BudgetConflictBackupStore.save(bookId, localBudgetData);
            await BudgetSyncStateStore.setLocalEditMs(bookId, 0);
            await BudgetSyncStateStore.setLocalBaseSyncVersion(
              bookId,
              cloudSyncVersion,
            );
          } else {
            final uploadResult = await _syncService.uploadBudget(
              bookId: bookId,
              budgetData: localBudgetData,
            );
            if (!uploadResult.success) {
              final err = (uploadResult.error ?? '').toLowerCase();
              final isConflict = err.contains('conflict') ||
                  err.contains('syncversion') ||
                  err.contains('version');
              debugPrint('[SyncEngine] budget upload failed: ${uploadResult.error}');
              if (isConflict) {
                await BudgetConflictBackupStore.save(bookId, localBudgetData);
                await BudgetSyncStateStore.setLocalEditMs(bookId, 0);
                await BudgetSyncStateStore.setLocalBaseSyncVersion(
                  bookId,
                  cloudSyncVersion,
                );
              } else {
                keepLocalDueToUploadFailure = true;
              }
            } else {
              final refreshed = await _syncService.downloadBudget(bookId: bookId);
              if (refreshed.success) {
                cloudBudget
                  ..clear()
                  ..addAll(refreshed.budget ?? const <String, dynamic>{});
                final refreshedSyncVersion = (() {
                  final raw = cloudBudget['syncVersion'];
                  if (raw is num) return raw.toInt();
                  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
                  return 0;
                })();
                if (refreshedSyncVersion > 0) {
                  await BudgetSyncStateStore.setServerSyncVersion(
                    bookId,
                    refreshedSyncVersion,
                  );
                  await BudgetSyncStateStore.setLocalBaseSyncVersion(
                    bookId,
                    refreshedSyncVersion,
                  );
                }
              }
            }
          }
        }
      }

      if (keepLocalDueToUploadFailure) {
        // Keep local state; retry on next meta sync.
        return;
      }

      Map<String, double> parseBudgetMap(dynamic raw) {
        if (raw == null) return const <String, double>{};
        if (raw is Map) {
          final result = <String, double>{};
          raw.forEach((k, v) {
            if (k == null) return;
            final key = k.toString();
            if (v is num) {
              result[key] = v.toDouble();
              return;
            }
            if (v is String) {
              result[key] = double.tryParse(v.trim()) ?? 0;
              return;
            }
          });
          return result;
        }
        if (raw is String) {
          final s = raw.trim();
          if (s.isEmpty) return const <String, double>{};
          try {
            final decoded = jsonDecode(s);
            if (decoded is Map) return parseBudgetMap(decoded);
          } catch (_) {}
        }
        return const <String, double>{};
      }

      await _outbox.runSuppressed(() async {
        await DataVersionService.runWithoutIncrement(() async {
          await budgetProvider.updateBudgetForBook(
            bookId: bookId,
            totalBudget: (cloudBudget['total'] as num?)?.toDouble() ?? 0,
            categoryBudgets: parseBudgetMap(cloudBudget['categoryBudgets']),
            annualBudget: (cloudBudget['annualTotal'] as num?)?.toDouble() ?? 0,
            annualCategoryBudgets:
                parseBudgetMap(cloudBudget['annualCategoryBudgets']),
            periodStartDay: (cloudBudget['periodStartDay'] as int?) ?? 1,
            markUserEdited: false,
          );
        });
      });

      // After applying server budget, clear local dirty flag.
      await BudgetSyncStateStore.setLocalEditMs(bookId, 0);
      final appliedSyncVersion = (() {
        final raw = cloudBudget['syncVersion'];
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw.trim()) ?? 0;
        return 0;
      })();
      await BudgetSyncStateStore.setLocalBaseSyncVersion(
        bookId,
        appliedSyncVersion,
      );
    } catch (e) {
      debugPrint('[SyncEngine] budget sync failed: $e');
    }
  }

  Future<void> _syncAccounts(
    AccountProvider accountProvider,
    RecordProvider recordProvider,
    String bookId, {
    required String reason,
  }) async {
    final uid = await _authUserIdOrZero();
    await _runMetaThrottled(
      'meta_accounts_u${uid}_b$bookId',
      () async {
        await _syncAccountsRaw(
          accountProvider,
          recordProvider,
          bookId,
          reason: reason,
        );
        return true;
      },
      // Accounts sync should not run concurrently (duplicate SQL) but should still be allowed
      // whenever requested; bypass the time window and only coalesce in-flight requests.
      bypassWindow: true,
    );
  }

  Future<void> _syncAccountsRaw(
    AccountProvider accountProvider,
    RecordProvider recordProvider,
    String bookId, {
    required String reason,
  }) async {
    try {
      debugPrint('[SyncEngine] account sync book=$bookId reason=$reason');
      // 元数据以服务器为准：不在后台做全量上传，避免频繁SQL与覆盖风险
      // 账户的新增/修改应走专用服务接口（成功后再刷新）。

      // 用户在资产页修改账户后：优先上传，再用服务端回包回填 serverId/最新字段。
      if (reason == 'accounts_changed') {
        final deletedAccounts = await AccountDeleteQueue.instance.load();
        final localAccounts = accountProvider.accounts;
        if (localAccounts.isNotEmpty || deletedAccounts.isNotEmpty) {
          // Download first to obtain serverId/syncVersion baselines to satisfy optimistic concurrency.
          try {
            final down = await _syncService.downloadAccounts(bookId: bookId);
            if (down.success && down.accounts != null) {
              await _outbox.runSuppressed(() async {
                await DataVersionService.runWithoutIncrement(() async {
                  await accountProvider.mergeSyncStateFromCloud(down.accounts!);
                });
              });
            }
          } catch (_) {}

          final payload = localAccounts
              .map(
                (a) => {
                  ...a.toMap(),
                  'updateTime':
                      (a.updatedAt ?? DateTime.now()).toIso8601String(),
                },
              )
              .toList(growable: false);

          final uploadResult = await _syncService.uploadAccounts(
            bookId: bookId,
            accounts: payload,
            deletedAccounts: deletedAccounts,
          );
          if (uploadResult.success && uploadResult.accounts != null) {
            final cloudAccounts = uploadResult.accounts!;
            await _outbox.runSuppressed(() async {
              await DataVersionService.runWithoutIncrement(() async {
                await accountProvider.replaceFromCloud(
                  cloudAccounts,
                  bookId: bookId,
                );
              });
            });
            if (deletedAccounts.isNotEmpty) {
              await AccountDeleteQueue.instance.clear();
            }
            return;
          }

          // accounts_changed 是“用户刚做了操作”的场景：上传失败时不要回退到 download 覆盖本地，
          // 否则会出现“刚删除又回来”的体验。后续由下一次 sync 自动重试即可。
          debugPrint('[SyncEngine] account upload failed, skip download to avoid overwrite');
          if (!uploadResult.success) {
            debugPrint('[SyncEngine] account upload error: ${uploadResult.error}');
          }

          // Self-heal: download latest serverId/syncVersion and merge into local state without overwriting edits.
          // This helps recover quickly from optimistic-concurrency errors (e.g. missing/stale syncVersion).
          try {
            final down = await _syncService.downloadAccounts(bookId: bookId);
            if (down.success && down.accounts != null) {
              await _outbox.runSuppressed(() async {
                await DataVersionService.runWithoutIncrement(() async {
                  await accountProvider.mergeSyncStateFromCloud(down.accounts!);
                });
              });
            }
          } catch (_) {}
          return;
        }

        // 本地账户为空时也不要回退到 download（同样会覆盖用户刚删除的结果）
        return;
      }

      final downloadResult = await _syncService.downloadAccounts(bookId: bookId);
      if (!downloadResult.success || downloadResult.accounts == null) return;

      final cloudAccounts = downloadResult.accounts!;
      await _outbox.runSuppressed(() async {
        await DataVersionService.runWithoutIncrement(() async {
          await accountProvider.replaceFromCloud(cloudAccounts, bookId: bookId);
        });
      });

      await _repairLegacyRecordAccountIds(accountProvider, recordProvider, bookId);
    } catch (e) {
      debugPrint('[SyncEngine] account sync failed: $e');
    }
  }

  Future<void> _repairLegacyRecordAccountIds(
    AccountProvider accountProvider,
    RecordProvider recordProvider,
    String bookId,
  ) async {
    final byLegacy = <String, String>{};
    for (final a in accountProvider.accounts) {
      final sid = a.serverId;
      if (sid == null) continue;
      byLegacy['server_$sid'] = a.id;
      byLegacy['$sid'] = a.id;
    }
    if (byLegacy.isEmpty) return;

    final records = recordProvider.recordsForBook(bookId);
    if (records.isEmpty) return;

    var changed = 0;
    await DataVersionService.runWithoutIncrement(() async {
      for (final r in records) {
        final mapped = byLegacy[r.accountId];
        if (mapped == null || mapped == r.accountId) continue;
        await recordProvider.updateRecord(
          r.copyWith(accountId: mapped),
          accountProvider: accountProvider,
        );
        changed++;
      }
    });

    if (changed > 0) {
      debugPrint(
          '[SyncEngine] migrated $changed legacy record accountIds for book=$bookId');
    }
  }
}
