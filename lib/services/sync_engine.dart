import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/record_provider.dart';
import '../repository/repository_factory.dart';
import 'auth_service.dart';
import 'data_version_service.dart';
import 'sync_outbox_service.dart';
import 'sync_service.dart';
import 'sync_v2_conflict_store.dart';
import 'sync_v2_cursor_store.dart';

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

  Future<void> syncActiveBook(BuildContext context) async {
    final bookId = context.read<BookProvider>().activeBookId;
    if (bookId.isEmpty) return;
    await syncBookV2(context, bookId);
  }

  Future<void> syncBook(BuildContext context, String bookId) async {
    await syncBookV2(context, bookId);
  }

  Future<void> syncBookV2(
    BuildContext context,
    String bookId, {
    String reason = 'unknown',
  }) async {
    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;
    await _uploadOutboxV2(context, bookId, reason: reason);
    await _pullV2(context, bookId, reason: reason);
  }

  /// 同步“元数据”（预算/账户等低频数据）。
  /// 设计为低频触发：登录后、前台唤醒、进入资产页等场景。
  Future<void> syncMeta(
    BuildContext context,
    String bookId, {
    String reason = 'unknown',
  }) async {
    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;
    await _syncBudget(context, bookId, reason: reason);
    await _syncAccounts(context, bookId, reason: reason);
  }

  Future<void> _uploadOutboxV2(
    BuildContext context,
    String bookId, {
    required String reason,
  }) async {
    final recordProvider = context.read<RecordProvider>();

    while (true) {
      final pending = await _outbox.loadPending(bookId, limit: 200);
      if (pending.isEmpty) return;

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
          // 服务端未返回该 opId 的结果：避免本次 sync 内死循环重试
          debugPrint('[SyncEngine] v2Push missing result for opId=$opId');
          continue;
        }

        final status = r['status'] as String?;
        if (status == 'applied') {
          final type = item.payload['type'] as String?;
          if (type == 'upsert') {
            final bill = (item.payload['bill'] as Map?)?.cast<String, dynamic>();
            final localId = bill?['localId'] as String?;
            final serverId = r['serverId'] as int?;
            final version = r['version'] as int?;
            if (localId != null && serverId != null) {
              await recordProvider.setServerSyncState(
                localId,
                serverId: serverId,
                serverVersion: version,
              );
            }
          }
          toDelete.add(item);
        } else if (status == 'conflict') {
          await SyncV2ConflictStore.addConflict(bookId, {
            'opId': opId,
            'localOp': item.payload,
            'serverId': r['serverId'],
            'serverVersion': r['version'],
            'serverBill': r['serverBill'],
          });
          toDelete.add(item);
        } else {
          // error/unknown：落盘并删除，避免无限重试压服务端
          await SyncV2ConflictStore.addConflict(bookId, {
            'opId': opId,
            'localOp': item.payload,
            'serverId': r['serverId'],
            'serverVersion': r['version'],
            'error': r['error'] ?? 'status=$status',
          });
          toDelete.add(item);
        }
      }

      // 无进展保护：避免 while(true) 无限循环
      if (toDelete.isEmpty) {
        debugPrint('[SyncEngine] v2Push made no progress; stop this cycle');
        return;
      }

      await _outbox.deleteItems(bookId, toDelete);

      // 如果还有未处理项（缺结果等），留待下一次触发，避免本次循环内反复重试
      if (toDelete.length < pending.length) return;
    }
  }

  Future<void> _pullV2(
    BuildContext context,
    String bookId, {
    required String reason,
  }) async {
    var cursor = await SyncV2CursorStore.getLastChangeId(bookId);

    while (true) {
      final prevCursor = cursor;
      final resp = await _syncService.v2Pull(
        bookId: bookId,
        afterChangeId: cursor == 0 ? null : cursor,
        limit: 200,
        reason: reason,
      );
      if (resp['success'] != true) {
        debugPrint('[SyncEngine] v2Pull failed: ${resp['error']}');
        return;
      }

      final next = resp['nextChangeId'] as int? ?? cursor;
      final changes = (resp['changes'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);

      if (changes.isNotEmpty) {
        final recordProvider = context.read<RecordProvider>();
        final accountProvider = context.read<AccountProvider>();
        await _outbox.runSuppressed(() async {
          await DataVersionService.runWithoutIncrement(() async {
            for (final c in changes) {
              final bill = (c['bill'] as Map?)?.cast<String, dynamic>();
              if (bill == null) continue;
              await _applyCloudBill(
                bill,
                recordProvider: recordProvider,
                accountProvider: accountProvider,
              );
            }
          });
        });
      }

      cursor = next;
      await SyncV2CursorStore.setLastChangeId(bookId, cursor);

      final hasMore = resp['hasMore'] as bool? ?? false;
      if (hasMore && next == prevCursor && changes.isEmpty) {
        debugPrint('[SyncEngine] v2Pull hasMore but cursor not advanced; stop to avoid loop');
        return;
      }
      if (!hasMore) break;
    }
  }

  Record _mapToRecord(Map<String, dynamic> map) {
    final serverId = map['id'] as int? ?? map['serverId'] as int?;
    final serverVersion = map['version'] as int? ?? map['serverVersion'] as int?;
    return Record(
      id: serverId != null ? 'server_$serverId' : _generateTempId(),
      serverId: serverId,
      serverVersion: serverVersion,
      amount: (map['amount'] as num).toDouble(),
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
      }
      return;
    }

    final cloudRecord = _mapToRecord(billMap);
    if (existing != null) {
      final updated = existing.copyWith(
        serverId: serverId,
        serverVersion: serverVersion,
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
      accountProvider: accountProvider,
    );
    await recordProvider.setServerSyncState(
      created.id,
      serverId: serverId,
      serverVersion: serverVersion,
    );
  }

  Future<void> _syncBudget(
    BuildContext context,
    String bookId, {
    required String reason,
  }) async {
    try {
      debugPrint('[SyncEngine] budget sync book=$bookId reason=$reason');
      final budgetProvider = context.read<BudgetProvider>();
      final budgetEntry = budgetProvider.budgetForBook(bookId);
      final budgetData = {
        'total': budgetEntry.total,
        'categoryBudgets': budgetEntry.categoryBudgets,
        'periodStartDay': budgetEntry.periodStartDay,
        'annualTotal': budgetEntry.annualTotal,
        'annualCategoryBudgets': budgetEntry.annualCategoryBudgets,
      };

      final uploadResult = await _syncService.uploadBudget(
        bookId: bookId,
        budgetData: budgetData,
      );
      if (!uploadResult.success) return;

      final downloadResult = await _syncService.downloadBudget(bookId: bookId);
      if (!downloadResult.success || downloadResult.budget == null) return;

      final cloudBudget = downloadResult.budget!;
      await _outbox.runSuppressed(() async {
        await DataVersionService.runWithoutIncrement(() async {
          await budgetProvider.updateBudgetForBook(
            bookId: bookId,
            totalBudget: (cloudBudget['total'] as num?)?.toDouble() ?? 0,
            categoryBudgets: Map<String, double>.from(
              (cloudBudget['categoryBudgets'] as Map?)?.cast<String, double>() ??
                  {},
            ),
            annualBudget: (cloudBudget['annualTotal'] as num?)?.toDouble() ?? 0,
            annualCategoryBudgets: Map<String, double>.from(
              (cloudBudget['annualCategoryBudgets'] as Map?)
                      ?.cast<String, double>() ??
                  {},
            ),
            periodStartDay: (cloudBudget['periodStartDay'] as int?) ?? 1,
          );
        });
      });
    } catch (e) {
      debugPrint('[SyncEngine] budget sync failed: $e');
    }
  }

  Future<void> _syncAccounts(
    BuildContext context,
    String bookId, {
    required String reason,
  }) async {
    try {
      debugPrint('[SyncEngine] account sync book=$bookId reason=$reason');
      final accountProvider = context.read<AccountProvider>();
      // 元数据以服务器为准：不在后台做全量上传，避免频繁SQL与覆盖风险
      // 账户的新增/修改应走专用服务接口（成功后再刷新）。

      final downloadResult = await _syncService.downloadAccounts();
      if (!downloadResult.success || downloadResult.accounts == null) return;

      final cloudAccounts = downloadResult.accounts!;
      await _outbox.runSuppressed(() async {
        await DataVersionService.runWithoutIncrement(() async {
          await accountProvider.replaceFromCloud(cloudAccounts);
        });
      });
    } catch (e) {
      debugPrint('[SyncEngine] account sync failed: $e');
    }
  }
}
