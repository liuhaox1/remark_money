import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record.dart';
import '../providers/record_provider.dart';
import '../repository/repository_factory.dart';
import '../services/data_version_service.dart';
import '../services/sync_outbox_service.dart';
import '../services/sync_v2_conflict_store.dart';

class SyncConflictsPage extends StatefulWidget {
  const SyncConflictsPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<SyncConflictsPage> createState() => _SyncConflictsPageState();
}

class _SyncConflictsPageState extends State<SyncConflictsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  final SyncOutboxService _outbox = SyncOutboxService.instance;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await SyncV2ConflictStore.list(widget.bookId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  String _fmtMs(int? ms) {
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$mi';
  }

  double _amountFromBill(Map<String, dynamic>? bill) {
    final v = bill?['amount'];
    if (v is num) return v.toDouble();
    return 0;
  }

  Future<Record?> _findLocalByServerId(int serverId) async {
    final provider = context.read<RecordProvider>();
    if (RepositoryFactory.isUsingDatabase) {
      final repo = RepositoryFactory.createRecordRepository() as dynamic;
      try {
        final Record? found =
            await repo.loadRecordByServerId(serverId, bookId: widget.bookId);
        if (found != null) return found;
      } catch (_) {}
    }
    try {
      return provider.records.firstWhere(
        (r) => r.serverId == serverId && r.bookId == widget.bookId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _acceptServer(Map<String, dynamic> item) async {
    final serverBill = (item['serverBill'] as Map?)?.cast<String, dynamic>();
    final serverId = item['serverId'] as int?;
    if (serverBill == null || serverId == null) return;

    final recordProvider = context.read<RecordProvider>();
    final local = await _findLocalByServerId(serverId);

    final direction = (serverBill['direction'] as int? ?? 0) == 1
        ? TransactionDirection.income
        : TransactionDirection.out;
    final includeInStats = (serverBill['includeInStats'] as int? ?? 1) == 1;

    final next = Record(
      id: local?.id ?? 'server_$serverId',
      serverId: serverId,
      serverVersion: serverBill['version'] as int? ?? item['serverVersion'] as int?,
      amount: _amountFromBill(serverBill).abs(),
      remark: serverBill['remark'] as String? ?? '',
      date: DateTime.tryParse(serverBill['billDate'] as String? ?? '') ??
          DateTime.now(),
      categoryKey: serverBill['categoryKey'] as String? ?? '',
      bookId: widget.bookId,
      accountId: serverBill['accountId'] as String? ?? '',
      direction: direction,
      includeInStats: includeInStats,
      pairId: serverBill['pairId'] as String?,
    );

    await _outbox.runSuppressed(() async {
      await DataVersionService.runWithoutIncrement(() async {
        if (local != null) {
          await recordProvider.updateRecord(next);
          await recordProvider.setServerSyncState(
            local.id,
            serverId: serverId,
            serverVersion: next.serverVersion,
          );
        } else {
          final created = await recordProvider.addRecord(
            amount: next.amount,
            remark: next.remark,
            date: next.date,
            categoryKey: next.categoryKey,
            bookId: widget.bookId,
            accountId: next.accountId,
            direction: next.direction,
            includeInStats: next.includeInStats,
            pairId: next.pairId,
          );
          await recordProvider.setServerSyncState(
            created.id,
            serverId: serverId,
            serverVersion: next.serverVersion,
          );
        }
      });
    });

    await SyncV2ConflictStore.remove(widget.bookId, opId: item['opId'] as String);
    await _reload();
  }

  Future<void> _retryLocal(Map<String, dynamic> item) async {
    final localOp = (item['localOp'] as Map?)?.cast<String, dynamic>();
    if (localOp == null) return;

    final type = localOp['type'] as String?;
    if (type == 'upsert') {
      final bill = (localOp['bill'] as Map?)?.cast<String, dynamic>();
      final localId = bill?['localId'] as String?;
      if (localId == null) return;
      final local = await _loadLocalById(localId);
      if (local == null) return;
      await SyncOutboxService.instance.enqueueUpsert(
        local.copyWith(serverVersion: item['serverVersion'] as int?),
      );
    } else if (type == 'delete') {
      final serverId = item['serverId'] as int?;
      if (serverId == null) return;
      final local = await _findLocalByServerId(serverId);
      if (local == null) return;
      await SyncOutboxService.instance.enqueueDelete(
        local.copyWith(serverVersion: item['serverVersion'] as int?),
      );
    }

    await SyncV2ConflictStore.remove(widget.bookId, opId: item['opId'] as String);
    await _reload();
  }

  Future<Record?> _loadLocalById(String id) async {
    final recordProvider = context.read<RecordProvider>();
    if (RepositoryFactory.isUsingDatabase) {
      final repo = RepositoryFactory.createRecordRepository() as dynamic;
      try {
        final Record? found = await repo.loadRecordById(id);
        if (found != null) return found;
      } catch (_) {}
    }
    try {
      return recordProvider.records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _dismiss(Map<String, dynamic> item) async {
    await SyncV2ConflictStore.remove(widget.bookId, opId: item['opId'] as String);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步冲突'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await SyncV2ConflictStore.clear(widget.bookId);
                await _reload();
              },
              child: const Text('清空'),
            ),
        ],
      ),
      backgroundColor: cs.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    '暂无冲突',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final opId = item['opId'] as String? ?? '';
                    final localOp =
                        (item['localOp'] as Map?)?.cast<String, dynamic>();
                    final type = localOp?['type'] as String? ?? '';
                    final serverBill =
                        (item['serverBill'] as Map?)?.cast<String, dynamic>();
                    final serverId = item['serverId'];
                    final serverVersion = item['serverVersion'];
                    final timeMs = item['timeMs'] as int?;
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sync_problem_outlined,
                                    color: cs.tertiary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    type.isEmpty ? '冲突' : '冲突：$type',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: cs.onSurface),
                                  ),
                                ),
                                Text(
                                  _fmtMs(timeMs),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              cs.onSurface.withOpacity(0.6)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'opId: $opId',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'serverId: $serverId  version: $serverVersion',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                            ),
                            if (serverBill != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                '云端：${serverBill['categoryKey'] ?? ''}  ¥${_amountFromBill(serverBill).toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                serverBill['remark'] as String? ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: cs.onSurface.withOpacity(0.7)),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _dismiss(item),
                                    child: const Text('忽略'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: serverBill == null
                                        ? null
                                        : () => _acceptServer(item),
                                    child: const Text('采用云端'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _retryLocal(item),
                                    child: const Text('保留本地'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _items.length,
                ),
    );
  }
}
