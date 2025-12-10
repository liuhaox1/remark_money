import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../providers/book_provider.dart';
import '../services/sync_service.dart';
import '../utils/error_handler.dart';
import 'dart:convert';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  String _statusText = '准备同步';
  SyncRecord? _syncRecord;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadStatus().then((_) {
      // 加载状态后，如果已登录且有同步记录，自动触发同步
      if (mounted && _syncRecord != null && _syncRecord!.lastSyncTime != null) {
        // 延迟一下，让用户看到状态
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _performAutoSync();
          }
        });
      }
    });
  }

  Future<void> _loadStatus() async {
    final bookProvider = context.read<BookProvider>();
    final bookId = bookProvider.activeBookId;
    if (bookId.isEmpty) return;

    final result = await _syncService.queryStatus(bookId: bookId);
    if (result.success && mounted) {
      setState(() {
        _syncRecord = result.syncRecord;
        _userInfo = result.userInfo;
      });
    }
  }

  /// 自动同步：根据同步记录自动判断首次/增量同步
  Future<void> _performAutoSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _statusText = '正在检测同步状态...';
    });

    try {
      final recordProvider = context.read<RecordProvider>();
      final bookProvider = context.read<BookProvider>();
      final bookId = bookProvider.activeBookId;

      if (bookId.isEmpty) {
        ErrorHandler.showError(context, '请先选择账本');
        return;
      }

      // 检查是否有同步记录（判断是否首次同步）
      final hasSyncRecord = _syncRecord != null && 
          _syncRecord!.lastSyncTime != null && 
          _syncRecord!.lastSyncTime!.isNotEmpty;

      if (!hasSyncRecord) {
        // 首次同步：检查本地是否有数据
        final localRecords = recordProvider.records;
        final hasLocalData = localRecords.isNotEmpty;

        if (hasLocalData) {
          // 全量上传
          setState(() => _statusText = '首次同步：上传本地数据...');
          await _fullUpload(bookId, localRecords);
        } else {
          // 全量拉取
          setState(() => _statusText = '首次同步：下载云端数据...');
          await _fullDownload(bookId);
        }
      } else {
        // 增量同步
        setState(() => _statusText = '增量同步中...');
        await _performIncrementalSync();
      }

      await _loadStatus();
      if (mounted) {
        ErrorHandler.showSuccess(context, '同步完成');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusText = '同步完成';
        });
      }
    }
  }

  /// 全量上传
  Future<void> _fullUpload(String bookId, List<Record> records) async {
    setState(() {
      _statusText = '正在上传数据...';
    });

    // 转换为Map格式
    final bills = records.map((r) => _recordToMap(r)).toList();

    // 分批上传（每批500条）
    const batchSize = 500;
    final totalBatches = (bills.length / batchSize).ceil();

    for (int i = 0; i < totalBatches; i++) {
      final start = i * batchSize;
      final end = (start + batchSize < bills.length) ? start + batchSize : bills.length;
      final batch = bills.sublist(start, end);

      setState(() {
        _statusText = '上传中 ${i + 1}/$totalBatches...';
      });

      final result = await _syncService.fullUpload(
        bookId: bookId,
        bills: batch,
        batchNum: i + 1,
        totalBatches: totalBatches,
      );

      if (!result.success) {
        throw Exception(result.error ?? '上传失败');
      }

      // 检查超额警告
      if (result.quotaWarning != null && mounted) {
        _showQuotaWarning(result.quotaWarning!);
      }
    }

    if (mounted) {
      ErrorHandler.showSuccess(context, '全量上传成功');
    }
  }

  /// 全量拉取
  Future<void> _fullDownload(String bookId) async {
    setState(() {
      _statusText = '正在下载数据...';
    });

    final recordProvider = context.read<RecordProvider>();
    int offset = 0;
    const limit = 100;
    int totalDownloaded = 0;

    while (true) {
      final result = await _syncService.fullDownload(
        bookId: bookId,
        offset: offset,
        limit: limit,
      );

      if (!result.success) {
        throw Exception(result.error ?? '拉取失败');
      }

      final bills = result.bills ?? [];
      if (bills.isEmpty) break;

      // 转换为Record并保存到本地
      for (final billMap in bills) {
        try {
          final record = _mapToRecord(billMap);
          await recordProvider.addRecord(
            amount: record.amount,
            remark: record.remark,
            date: record.date,
            categoryKey: record.categoryKey,
            bookId: record.bookId,
            accountId: record.accountId,
            direction: record.direction,
            includeInStats: record.includeInStats,
            accountProvider: context.read(),
          );
        } catch (e) {
          // 忽略单个记录错误，继续处理
          print('Failed to add record: $e');
        }
      }

      totalDownloaded += bills.length;
      setState(() {
        _statusText = '已下载 $totalDownloaded 条...';
      });

      if (!(result.hasMore ?? false)) break;
      offset += limit;
    }

    if (mounted) {
      ErrorHandler.showSuccess(context, '全量拉取成功，共 $totalDownloaded 条');
    }
  }

  /// 增量同步
  Future<void> _performIncrementalSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _statusText = '正在增量同步...';
    });

    try {
      final recordProvider = context.read<RecordProvider>();
      final bookProvider = context.read<BookProvider>();
      final bookId = bookProvider.activeBookId;

      if (bookId.isEmpty) {
        ErrorHandler.showError(context, '请先选择账本');
        return;
      }

      // 1. 上传增量（本地修改的）
      if (_syncRecord?.lastSyncTime != null) {
        final lastSyncTime = DateTime.parse(_syncRecord!.lastSyncTime!);
        final localRecords = recordProvider.records
            .where((r) => r.date.isAfter(lastSyncTime))
            .toList();

        if (localRecords.isNotEmpty) {
          final bills = localRecords.map((r) => _recordToMap(r)).toList();
          final result = await _syncService.incrementalUpload(
            bookId: bookId,
            bills: bills,
          );

          if (!result.success) {
            throw Exception(result.error ?? '增量上传失败');
          }

          if (result.quotaWarning != null && mounted) {
            _showQuotaWarning(result.quotaWarning!);
          }
        }
      }

      // 2. 拉取增量（云端修改的）
      final downloadResult = await _syncService.incrementalDownload(
        bookId: bookId,
        lastSyncTime: _syncRecord?.lastSyncTime,
        lastSyncBillId: _syncRecord?.lastSyncBillId,
      );

      if (downloadResult.success) {
        final bills = downloadResult.bills ?? [];
        if (bills.isNotEmpty) {
          // 处理冲突
          for (final billMap in bills) {
            await _handleConflict(billMap);
          }
        }
      }

      await _loadStatus();
      if (mounted) {
        ErrorHandler.showSuccess(context, '增量同步完成');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusText = '同步完成';
        });
      }
    }
  }

  /// 处理冲突
  Future<void> _handleConflict(Map<String, dynamic> billMap) async {
    // TODO: 实现冲突处理UI（显示差异，让用户选择）
    // 暂时直接使用云端数据
    final recordProvider = context.read<RecordProvider>();
    try {
      final record = _mapToRecord(billMap);
      // 检查本地是否存在
      final existing = recordProvider.records.firstWhere(
        (r) => r.id == record.id,
        orElse: () => record,
      );

      if (existing.id != record.id || existing.date != record.date) {
        // 有冲突，显示差异提示
        if (mounted) {
          _showConflictDialog(billMap, existing);
        }
      } else {
        // 无冲突，直接更新
        // TODO: 更新本地记录
      }
    } catch (e) {
      print('Conflict handling error: $e');
    }
  }

  /// 显示冲突对话框
  void _showConflictDialog(Map<String, dynamic> cloudBill, Record localRecord) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('发现云端更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('同一账单在其他设备更新过，已用云端版本覆盖本地。'),
              const SizedBox(height: 16),
              const Text('差异对比：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('金额：本地 ${localRecord.amount} → 云端 ${cloudBill['amount']}'),
              Text('备注：本地 ${localRecord.remark} → 云端 ${cloudBill['remark'] ?? ''}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('接受云端版本', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // TODO: 以本地为准并重试上传
              },
              child: Text('以本地为准', style: TextStyle(color: cs.onSurface)),
            ),
          ],
        );
      },
    );
  }

  /// 显示超额警告
  void _showQuotaWarning(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('存储额度提醒'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('暂不处理', style: TextStyle(color: cs.onSurface)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // TODO: 跳转到升级页面
              },
              child: const Text('去升级'),
            ),
          ],
        );
      },
    );
  }

  /// Record转Map
  Map<String, dynamic> _recordToMap(Record record) {
    return {
      'billId': record.id,
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
      'updateTime': record.date.toIso8601String(),
    };
  }

  /// Map转Record
  Record _mapToRecord(Map<String, dynamic> map) {
    return Record(
      id: map['billId'] as String,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookProvider = context.watch<BookProvider>();
    final bookName = bookProvider.activeBook?.name ?? '默认账本';

    return Scaffold(
      appBar: AppBar(
        title: const Text('云端同步'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 状态卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前账本：$bookName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_syncRecord != null) ...[
                    Text('云端账单数：${_syncRecord!.cloudBillCount ?? 0}'),
                    if (_syncRecord!.lastSyncTime != null)
                      Text('最后同步：${_syncRecord!.lastSyncTime}'),
                    if (_syncRecord!.dataVersion != null)
                      Text('数据版本：${_syncRecord!.dataVersion}'),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    style: TextStyle(color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 自动同步按钮（系统自动判断首次/增量）
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _performAutoSync,
            icon: const Icon(Icons.sync),
            label: const Text('开始同步'),
          ),
        ],
      ),
    );
  }
}

