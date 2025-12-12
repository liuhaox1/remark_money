import 'dart:math' as math;

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
    await syncBook(context, bookId);
  }

  Future<void> syncBook(BuildContext context, String bookId) async {
    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;

    // 取一次状态；后续根据返回的 syncRecord 游标做增量
    final status = await _syncService.queryStatus(bookId: bookId);
    if (!status.success) return;

    final localVersion = await DataVersionService.getVersion(bookId);
    final syncRecord = status.syncRecord;
    final serverVersion = syncRecord?.dataVersion ?? 0;
    final hasEverSynced = syncRecord?.lastSyncTime != null &&
        (syncRecord!.lastSyncTime?.isNotEmpty ?? false);

    // 无本地变更且服务器版本不变：直接跳过（不上传/不下载）
    final pending = await _outbox.loadPending(bookId, limit: 1);
    if (pending.isEmpty && hasEverSynced && localVersion == serverVersion) {
      return;
    }

    // 首次：尽量减少重复/冲突。云端有数据时先拉取，再上传本地修改队列。
    if (!hasEverSynced) {
      final cloudCount = syncRecord?.cloudBillCount ?? 0;
      final localCount = await _estimateLocalCount(bookId);

      if (cloudCount > 0) {
        await _fullDownload(context, bookId);
      } else if (localCount > 0) {
        await _fullUpload(context, bookId);
      } else {
        // 两边都空：不做事
      }
    }

    SyncRecord? latest = syncRecord;

    // 1) 先上传本地 outbox（包含历史修改/删除）
    latest = await _uploadOutbox(context, bookId) ?? latest;

    // 2) 再拉取云端增量（解决多设备）
    latest = await _downloadIncremental(
          context,
          bookId,
          lastSyncTime: latest?.lastSyncTime,
          lastSyncId: latest?.lastSyncId,
        ) ??
        latest;

    // 3) 用服务器版本统一本地版本，避免重复触发
    if (latest?.dataVersion != null) {
      await DataVersionService.syncVersion(bookId, latest!.dataVersion!);
    }
  }

  /// 同步“元数据”（预算/账户等低频数据）。
  /// 设计为低频触发：登录后、前台唤醒、进入资产页等场景。
  Future<void> syncMeta(BuildContext context, String bookId) async {
    final tokenValid = await _authService.isTokenValid();
    if (!tokenValid) return;
    await _syncBudget(context, bookId);
    await _syncAccounts(context, bookId);
  }

  Future<int> _estimateLocalCount(String bookId) async {
    try {
      if (RepositoryFactory.isUsingDatabase) {
        final repo = RepositoryFactory.createRecordRepository() as dynamic;
        final list = await repo.loadRecords(bookId: bookId);
        return (list as List<Record>).where((r) => r.includeInStats).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _fullUpload(BuildContext context, String bookId) async {
    try {
      List<Record> localRecords;
      if (RepositoryFactory.isUsingDatabase) {
        final repo = RepositoryFactory.createRecordRepository() as dynamic;
        localRecords = (await repo.loadRecords(bookId: bookId)) as List<Record>;
      } else {
        localRecords = context.read<RecordProvider>().recordsForBook(bookId);
      }
      localRecords = localRecords.where((r) => r.includeInStats).toList();
      if (localRecords.isEmpty) return;

      final bills = localRecords.map(_recordToMap).toList();

      const batchSize = 300;
      final totalBatches = (bills.length / batchSize).ceil();

      for (int i = 0; i < totalBatches; i++) {
        final start = i * batchSize;
        final end = math.min(start + batchSize, bills.length);
        final batch = bills.sublist(start, end);
        final result = await _syncService.fullUpload(
          bookId: bookId,
          bills: batch,
          batchNum: i + 1,
          totalBatches: totalBatches,
        );
        if (!result.success) {
          debugPrint('[SyncEngine] fullUpload failed: ${result.error}');
          return;
        }

        // 尝试用“字段匹配”回填 serverId（批次内匹配，避免全表扫描）
        if (result.bills != null && result.bills!.isNotEmpty) {
          await _applyServerIdsFromUploadedBatch(
            context,
            localRecords: localRecords,
            uploadedBatch: batch,
            returnedBills: result.bills!,
          );
        }
      }

      // 全量上传后，outbox 里的 upsert 很可能已包含相同数据；此处不强制清空，后续增量会幂等更新
    } catch (e) {
      debugPrint('[SyncEngine] fullUpload exception: $e');
    }
  }

  Future<void> _fullDownload(BuildContext context, String bookId) async {
    try {
      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();

      int offset = 0;
      const limit = 200;
      while (true) {
        final result = await _syncService.fullDownload(
          bookId: bookId,
          offset: offset,
          limit: limit,
        );
        if (!result.success) {
          debugPrint('[SyncEngine] fullDownload failed: ${result.error}');
          return;
        }
        final bills = result.bills ?? [];
        if (bills.isEmpty) break;

        await _outbox.runSuppressed(() async {
          await DataVersionService.runWithoutIncrement(() async {
            for (final billMap in bills) {
              await _applyCloudBill(
                billMap,
                recordProvider: recordProvider,
                accountProvider: accountProvider,
              );
            }
          });
        });

        if (!(result.hasMore ?? false)) break;
        offset += limit;
      }
    } catch (e) {
      debugPrint('[SyncEngine] fullDownload exception: $e');
    }
  }

  Future<SyncRecord?> _uploadOutbox(BuildContext context, String bookId) async {
    SyncRecord? latest;
    while (true) {
      final pending = await _outbox.loadPending(bookId, limit: 200);
      if (pending.isEmpty) return latest;

      final bills = pending.map((e) => e.payload).toList();
      final result = await _syncService.incrementalUpload(bookId: bookId, bills: bills);
      if (!result.success) {
        debugPrint('[SyncEngine] incrementalUpload failed: ${result.error}');
        return latest;
      }
      latest = result.syncRecord ?? latest;

      // 回填 serverId：优先用 serverId 精确匹配，否则在本批 outbox 的 localId 上匹配
      if (result.bills != null && result.bills!.isNotEmpty) {
        await _applyServerIdsFromOutboxBatch(
          context,
          outboxItems: pending,
          returnedBills: result.bills!,
        );
      }

      await _outbox.deleteItems(bookId, pending);
    }
  }

  Future<SyncRecord?> _downloadIncremental(
    BuildContext context,
    String bookId, {
    String? lastSyncTime,
    int? lastSyncId,
  }) async {
    final downloadResult = await _syncService.incrementalDownload(
      bookId: bookId,
      lastSyncTime: lastSyncTime,
      lastSyncId: lastSyncId,
    );
    if (!downloadResult.success) return null;

    final bills = downloadResult.bills ?? [];
    if (bills.isEmpty) return downloadResult.syncRecord;

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();

    await _outbox.runSuppressed(() async {
      await DataVersionService.runWithoutIncrement(() async {
        for (final billMap in bills) {
          await _applyCloudBill(
            billMap,
            recordProvider: recordProvider,
            accountProvider: accountProvider,
          );
        }
      });
    });

    return downloadResult.syncRecord;
  }

  Map<String, dynamic> _recordToMap(Record record) {
    final now = DateTime.now();
    return {
      'localId': record.id,
      'serverId': record.serverId,
      'bookId': record.bookId,
      'accountId': record.accountId,
      'categoryKey': record.categoryKey,
      'amount': record.amount,
      'direction': record.direction == TransactionDirection.income ? 1 : 0,
      'remark': record.remark,
      'billDate': record.date.toIso8601String(),
      'includeInStats': record.includeInStats ? 1 : 0,
      'pairId': record.pairId,
      'isDelete': 0,
      // 这里是“同步写入时间”，用于服务器冲突处理；不使用账单日期
      'updateTime': now.toIso8601String(),
    };
  }

  Record _mapToRecord(Map<String, dynamic> map) {
    final serverId = map['id'] as int? ?? map['serverId'] as int?;
    return Record(
      id: serverId != null ? 'server_$serverId' : _generateTempId(),
      serverId: serverId,
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
    final bookId = billMap['bookId'] as String? ?? '';

    final existing = await _findLocalByServerId(
      serverId,
      bookId: bookId,
      recordProvider: recordProvider,
    );

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
    await recordProvider.setServerId(created.id, serverId);
  }

  bool _matchPayloadToRecord(Map<String, dynamic> payload, Record record) {
    return (payload['bookId'] as String?) == record.bookId &&
        (payload['accountId'] as String?) == record.accountId &&
        (payload['categoryKey'] as String?) == record.categoryKey &&
        ((payload['amount'] as num?)?.toDouble() ?? -1) == record.amount &&
        ((payload['direction'] as int?) ?? -1) ==
            (record.direction == TransactionDirection.income ? 1 : 0) &&
        (payload['remark'] as String? ?? '') == record.remark &&
        (payload['pairId'] as String?) == record.pairId &&
        DateTime.tryParse(payload['billDate'] as String? ?? '')
                ?.isAtSameMomentAs(record.date) ==
            true;
  }

  bool _matchReturnedBillToPayload(
    Map<String, dynamic> bill,
    Map<String, dynamic> payload,
  ) {
    final billDate = DateTime.tryParse(bill['billDate'] as String? ?? '');
    final payloadDate = DateTime.tryParse(payload['billDate'] as String? ?? '');
    return (bill['bookId'] as String?) == (payload['bookId'] as String?) &&
        (bill['accountId'] as String?) == (payload['accountId'] as String?) &&
        (bill['categoryKey'] as String?) == (payload['categoryKey'] as String?) &&
        ((bill['amount'] as num?)?.toDouble() ?? -1) ==
            ((payload['amount'] as num?)?.toDouble() ?? -2) &&
        (bill['direction'] as int?) == (payload['direction'] as int?) &&
        (bill['remark'] as String? ?? '') == (payload['remark'] as String? ?? '') &&
        (bill['pairId'] as String?) == (payload['pairId'] as String?) &&
        (billDate != null &&
            payloadDate != null &&
            billDate.isAtSameMomentAs(payloadDate));
  }

  Future<void> _applyServerIdsFromOutboxBatch(
    BuildContext context, {
    required List<SyncOutboxItem> outboxItems,
    required List<Map<String, dynamic>> returnedBills,
  }) async {
    final recordProvider = context.read<RecordProvider>();

    final candidates = <SyncOutboxItem>[
      for (final item in outboxItems)
        if (item.op == SyncOutboxOp.upsert &&
            (item.payload['serverId'] as int?) == null)
          item
    ];

    for (final bill in returnedBills) {
      final serverId = bill['id'] as int? ?? bill['serverId'] as int?;
      if (serverId == null) continue;

      // 用 outbox payload 做字段匹配回填
      SyncOutboxItem? matched;
      for (final c in candidates) {
        if (_matchReturnedBillToPayload(bill, c.payload)) {
          matched = c;
          break;
        }
      }
      if (matched != null) {
        final localRecordId = matched.payload['localId'] as String?;
        if (localRecordId != null) {
          await recordProvider.setServerId(localRecordId, serverId);
        }
        candidates.remove(matched);
      }
    }
  }

  Future<void> _applyServerIdsFromUploadedBatch(
    BuildContext context, {
    required List<Record> localRecords,
    required List<Map<String, dynamic>> uploadedBatch,
    required List<Map<String, dynamic>> returnedBills,
  }) async {
    final recordProvider = context.read<RecordProvider>();

    // 用本批上传的 payload 作为候选，匹配回填
    final candidates = <Map<String, dynamic>>[
      for (final p in uploadedBatch)
        if ((p['serverId'] as int?) == null) p,
    ];
    final recordById = {for (final r in localRecords) r.id: r};

    for (final bill in returnedBills) {
      final serverId = bill['id'] as int? ?? bill['serverId'] as int?;
      if (serverId == null) continue;

      final localId = bill['localId'] as String?;
      if (localId != null && localId.isNotEmpty) {
        await recordProvider.setServerId(localId, serverId);
        continue;
      }

      Map<String, dynamic>? matched;
      for (final c in candidates) {
        final lid = c['localId'] as String?;
        if (lid == null) continue;
        final record = recordById[lid];
        if (record == null) continue;
        if (_matchPayloadToRecord(c, record)) {
          matched = c;
          break;
        }
      }
      if (matched != null) {
        final lid = matched['localId'] as String?;
        if (lid != null) {
          await recordProvider.setServerId(lid, serverId);
        }
        candidates.remove(matched);
      }
    }
  }

  Future<void> _syncBudget(BuildContext context, String bookId) async {
    try {
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

  Future<void> _syncAccounts(BuildContext context, String bookId) async {
    try {
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
