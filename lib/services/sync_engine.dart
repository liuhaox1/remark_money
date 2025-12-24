import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/record_provider.dart';
import '../repository/repository_factory.dart';
import '../repository/record_repository_db.dart';
import 'account_delete_queue.dart';
import 'auth_service.dart';
import 'data_version_service.dart';
import 'sync_outbox_service.dart';
import 'sync_service.dart';
import 'sync_v2_conflict_store.dart';
import 'sync_v2_cursor_store.dart';
import 'sync_v2_pull_utils.dart';
import 'sync_v2_push_retry.dart';

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
    // 性能关键点：本地记账触发 outbox 变化时，先只 push（把本地变更上云）。
    // 立即 pull 会额外产生一轮 bill_change_log + bill_info 查询（服务端/客户端都浪费）。
    // 多设备变更的拉取由 app_start / app_resumed（以及未来可选的轮询/SSE）来覆盖。
    if (reason == 'local_outbox_changed') return;
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
      // 批处理性能关键：尽量把同一本账本的 outbox 聚合到一次 push
      final pending = await _outbox.loadPending(bookId, limit: 1000);
      if (pending.isEmpty) return;

      await _assignServerIdsForCreates(
        context,
        bookId,
        pending,
        reason: reason,
      );

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
    BuildContext context,
    String bookId,
    List<SyncOutboxItem> pending, {
    required String reason,
  }) async {
    final recordProvider = context.read<RecordProvider>();
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
    BuildContext context,
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
        final recordProvider = context.read<RecordProvider>();
        final accountProvider = context.read<AccountProvider>();
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

      // 用户在资产页修改账户后：优先上传，再用服务端回包回填 serverId/最新字段。
      if (reason == 'accounts_changed') {
        final deletedAccounts = await AccountDeleteQueue.instance.load();
        final localAccounts = accountProvider.accounts;
        if (localAccounts.isNotEmpty || deletedAccounts.isNotEmpty) {
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
          return;
        }

        // 本地账户为空时也不要回退到 download（同样会覆盖用户刚删除的结果）
        return;
      }

      final downloadResult = await _syncService.downloadAccounts();
      if (!downloadResult.success || downloadResult.accounts == null) return;

      final cloudAccounts = downloadResult.accounts!;
      await _outbox.runSuppressed(() async {
        await DataVersionService.runWithoutIncrement(() async {
          await accountProvider.replaceFromCloud(cloudAccounts, bookId: bookId);
        });
      });

      await _repairLegacyRecordAccountIds(context, bookId);
    } catch (e) {
      debugPrint('[SyncEngine] account sync failed: $e');
    }
  }

  Future<void> _repairLegacyRecordAccountIds(
    BuildContext context,
    String bookId,
  ) async {
    final accountProvider = context.read<AccountProvider>();
    final recordProvider = context.read<RecordProvider>();

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
