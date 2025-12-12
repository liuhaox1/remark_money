import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../models/account.dart';
import '../providers/record_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/account_provider.dart';
import '../services/sync_service.dart';
import '../services/data_version_service.dart';
import '../services/sync_version_cache_service.dart';
import '../utils/error_handler.dart';
import '../repository/repository_factory.dart';
import 'vip_purchase_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final SyncService _syncService = SyncService();
  final SyncVersionCacheService _versionCacheService = SyncVersionCacheService();
  bool _isSyncing = false;
  String _statusText = '准备同步';
  SyncRecord? _syncRecord;

  @override
  void initState() {
    super.initState();
    _loadStatus().then((_) {
      // 仅在用户进入同步页时做一次自动同步，避免后台轮询造成高频请求
      if (mounted &&
          _syncRecord != null &&
          _syncRecord!.lastSyncTime != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _performAutoSync();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final bookProvider = context.read<BookProvider>();
    final bookId = bookProvider.activeBookId;
    if (bookId.isEmpty) return;

    final result = await _syncService.queryStatus(bookId: bookId);
    if (result.success && mounted) {
      setState(() {
        _syncRecord = result.syncRecord;
      });
    } else if (!result.success && mounted) {
      // 检查是否是付费相关错误
      final error = result.error ?? '';
      if (_isPaymentRequiredError(error)) {
        _showVipPurchasePage();
      }
    }
  }

  /// 自动同步：根据同步记录自动判断首次/增量同步
  Future<void> _performAutoSync({bool isManual = false}) async {
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
        if (isManual && mounted) {
          ErrorHandler.showError(context, '请先选择账本');
        }
        return;
      }

      // 检查版本号：先尝试使用缓存的版本号，如果缓存不存在或过期，再请求服务器
      final localVersion = await DataVersionService.getVersion(bookId);
      int? serverVersion = _syncRecord?.dataVersion;
      
      // 如果_syncRecord中没有版本号，尝试从缓存获取
      if (serverVersion == null || serverVersion == 0) {
        serverVersion = await _versionCacheService.getCachedVersion(bookId);
      }
      
      // 如果缓存也没有，才请求服务器（但只在手动同步时请求，自动同步时跳过）
      if (serverVersion == null && isManual) {
        await _loadStatus();
        serverVersion = _syncRecord?.dataVersion ?? 0;
      } else {
        serverVersion ??= 0;
      }
      
      if (localVersion == serverVersion && _syncRecord != null && 
          _syncRecord!.lastSyncTime != null && 
          _syncRecord!.lastSyncTime!.isNotEmpty) {
        // 版本号相同，不需要同步
        if (isManual && mounted) {
          ErrorHandler.showSuccess(context, '数据已是最新版本');
        }
        return;
      }

      // 检查是否有同步记录（判断是否首次同步）
      final hasSyncRecord = _syncRecord != null && 
          _syncRecord!.lastSyncTime != null && 
          _syncRecord!.lastSyncTime!.isNotEmpty;

      if (!hasSyncRecord) {
        // 首次同步：检查本地是否有数据
        // 使用异步方法查询所有记录（包括数据库中的全部记录，不只是缓存）
        List<Record> localRecords;
        if (RepositoryFactory.isUsingDatabase) {
          final dbRepo = RepositoryFactory.createRecordRepository();
          localRecords = await dbRepo.loadRecords(bookId: bookId);
        } else {
          localRecords = recordProvider.records;
        }
        
        // 过滤掉转账记录（includeInStats == false 的记录不参与同步）
        localRecords = localRecords.where((r) => r.includeInStats).toList();
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

      // 同步预算数据
      await _syncBudget(bookId);

      // 同步账户数据
      await _syncAccounts(bookId);

      // 同步后更新本地版本号
      if (_syncRecord?.dataVersion != null) {
        await DataVersionService.syncVersion(bookId, _syncRecord!.dataVersion!);
      }

      await _loadStatus();
      if (mounted && isManual) {
        ErrorHandler.showSuccess(context, '同步完成');
      }
    } catch (e) {
      if (mounted && isManual) {
        // 检查是否是付费相关错误，如果是则显示VIP购买页面
        final errorMsg = e.toString();
        if (_isPaymentRequiredError(errorMsg)) {
          _showVipPurchasePage();
        } else {
          ErrorHandler.handleAsyncError(context, e);
        }
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

    // 过滤掉转账记录（includeInStats == false 的记录不参与同步）
    final filteredRecords = records.where((r) => r.includeInStats).toList();

    // 转换为Map格式
    final bills = filteredRecords.map((r) => _recordToMap(r)).toList();

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
        final error = result.error ?? '上传失败';
        if (_isPaymentRequiredError(error)) {
          if (mounted) {
            _showVipPurchasePage();
          }
          return;
        }
        throw Exception(error);
      }

      // 回填服务器ID
      if (result.bills != null && result.bills!.isNotEmpty) {
        await _applyServerIds(result.bills!);
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
        final error = result.error ?? '拉取失败';
        if (_isPaymentRequiredError(error)) {
          if (mounted) {
            _showVipPurchasePage();
          }
          return;
        }
        throw Exception(error);
      }

      final bills = result.bills ?? [];
      if (bills.isEmpty) break;

      if (!mounted) return;
      final accountProvider = context.read<AccountProvider>();
      // 转换为Record并保存到本地
      for (final billMap in bills) {
        try {
          await _applyCloudBill(
            billMap,
            recordProvider: recordProvider,
            accountProvider: accountProvider,
          );
        } catch (e) {
          // 忽略单个记录错误，继续处理
          if (kDebugMode) debugPrint('Failed to add record: $e');
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
        
        // 查询所有记录（不只是缓存），过滤掉转账记录
        List<Record> localRecords;
        if (RepositoryFactory.isUsingDatabase) {
          final dbRepo = RepositoryFactory.createRecordRepository();
          final allRecords = await dbRepo.loadRecords(bookId: bookId);
          localRecords = allRecords
              .where((r) => r.includeInStats && r.date.isAfter(lastSyncTime))
              .toList();
        } else {
          localRecords = recordProvider.records
              .where((r) => r.includeInStats && r.date.isAfter(lastSyncTime))
              .toList();
        }

        if (localRecords.isNotEmpty) {
          final bills = localRecords.map((r) => _recordToMap(r)).toList();
          final result = await _syncService.incrementalUpload(
            bookId: bookId,
            bills: bills,
          );

          if (!result.success) {
            final error = result.error ?? '增量上传失败';
            if (_isPaymentRequiredError(error)) {
              if (mounted) {
                _showVipPurchasePage();
              }
              return;
            }
            throw Exception(error);
          }

        // 回填服务器ID
        if (result.bills != null && result.bills!.isNotEmpty) {
          await _applyServerIds(result.bills!);
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
        lastSyncId: _syncRecord?.lastSyncId,
      );

      if (downloadResult.success) {
        final bills = downloadResult.bills ?? [];
        if (bills.isNotEmpty) {
          // 处理冲突
          for (final billMap in bills) {
            await _handleConflict(billMap);
          }
        }
      } else {
        final error = downloadResult.error ?? '增量拉取失败';
        if (_isPaymentRequiredError(error)) {
          if (mounted) {
            _showVipPurchasePage();
          }
          return;
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
      await _applyCloudBill(
        billMap,
        recordProvider: recordProvider,
        accountProvider: context.read(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Conflict handling error: $e');
    }
  }

  /// 显示超额警告
  void _showQuotaWarning(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('存储额度提醒', style: TextStyle(color: cs.onSurface)),
          content: Text(message, style: TextStyle(color: cs.onSurface)),
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
              child: Text('去升级', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  /// Record转Map
  Map<String, dynamic> _recordToMap(Record record) {
    return {
      'serverId': record.serverId, // 只传serverId，服务器不再需要billId
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
    // 服务器返回的id作为serverId，客户端生成临时id用于本地存储
    final serverId = map['id'] as int?;
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

  /// 回填服务器ID到本地记录
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

    final existing =
        await _findLocalByServerId(serverId, bookId: bookId, recordProvider: recordProvider);

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

  Future<void> _applyServerIds(List<Map<String, dynamic>> bills) async {
    if (!mounted) return;
    final recordProvider = context.read<RecordProvider>();
    for (final bill in bills) {
      final serverId = bill['id'] as int? ?? bill['serverId'] as int?;
      if (serverId != null) {
        // 通过serverId查找本地记录并更新
        final records = recordProvider.records;
        try {
          final localRecord = records.firstWhere((r) => r.serverId == serverId);
          if (localRecord.serverId != serverId) {
            await recordProvider.setServerId(localRecord.id, serverId);
          }
        } catch (e) {
          // 本地不存在该记录，跳过（可能是新下载的记录）
        }
      }
    }
  }

  String _generateTempId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
        (100000 + (DateTime.now().microsecond % 900000)).toString();
  }

  /// 同步预算数据
  Future<void> _syncBudget(String bookId) async {
    try {
      final budgetProvider = context.read<BudgetProvider>();
      final budgetEntry = budgetProvider.budgetForBook(bookId);
      
      // 上传预算数据
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
      
      if (uploadResult.success) {
        // 下载云端预算数据（如果有更新）
        final downloadResult = await _syncService.downloadBudget(bookId: bookId);
        if (downloadResult.success && downloadResult.budget != null) {
          // 更新本地预算数据
          final cloudBudget = downloadResult.budget!;
          await budgetProvider.updateBudgetForBook(
            bookId: bookId,
            totalBudget: (cloudBudget['total'] as num?)?.toDouble() ?? 0,
            categoryBudgets: Map<String, double>.from(
              (cloudBudget['categoryBudgets'] as Map?)?.cast<String, double>() ?? {},
            ),
            annualBudget: (cloudBudget['annualTotal'] as num?)?.toDouble() ?? 0,
            annualCategoryBudgets: Map<String, double>.from(
              (cloudBudget['annualCategoryBudgets'] as Map?)?.cast<String, double>() ?? {},
            ),
            periodStartDay: (cloudBudget['periodStartDay'] as int?) ?? 1,
          );
        }
      }
    } catch (e) {
      // 预算同步失败不影响账单同步
      debugPrint('Budget sync failed: $e');
    }
  }

  /// 同步账户数据
  Future<void> _syncAccounts(String bookId) async {
    try {
      final accountProvider = context.read<AccountProvider>();
      final accounts = accountProvider.accounts;
      
      // 上传账户数据（使用临时ID）
      final accountsData = accounts.map((a) => a.toMap()).toList();
      
      final uploadResult = await _syncService.uploadAccounts(
        accounts: accountsData,
      );
      
      if (uploadResult.success && uploadResult.accounts != null) {
        // 应用服务器返回的serverId到本地账户
        await _applyAccountServerIds(uploadResult.accounts!);
      }
      
      // 下载云端账户数据（如果有更新）
      final downloadResult = await _syncService.downloadAccounts();
      if (downloadResult.success && downloadResult.accounts != null && 
          downloadResult.accounts!.isNotEmpty) {
        // 更新本地账户数据（合并策略：云端优先）
        final cloudAccounts = downloadResult.accounts!;
        for (final accountMap in cloudAccounts) {
          try {
            // 服务器返回的id是serverId，需要转换为Account对象
            final serverId = accountMap['id'] as int?;
            if (serverId == null) continue;
            
            // 通过serverId查找本地账户
            final existingAccount = accounts.firstWhere(
              (a) => a.serverId == serverId,
              orElse: () => Account.fromMap(accountMap),
            );
            
            // 如果本地存在，更新serverId；否则创建新账户
            if (existingAccount.serverId == null) {
              // 更新本地账户的serverId
              final updatedAccount = existingAccount.copyWith(serverId: serverId);
              await accountProvider.updateAccount(updatedAccount, bookId: bookId);
            } else {
              // 检查是否需要更新（云端时间更新）
              final cloudUpdateTime = accountMap['updateTime'] != null
                  ? DateTime.tryParse(accountMap['updateTime'])
                  : null;
              if (cloudUpdateTime != null && 
                  (existingAccount.updatedAt == null || 
                   cloudUpdateTime.isAfter(existingAccount.updatedAt!))) {
                // 使用云端数据更新
                final account = Account.fromMap(accountMap);
                await accountProvider.updateAccount(account, bookId: bookId);
              }
            }
          } catch (e) {
            debugPrint('Failed to sync account: $e');
          }
        }
      }
    } catch (e) {
      // 账户同步失败不影响其他数据同步
      debugPrint('Account sync failed: $e');
    }
  }

  /// 应用服务器返回的serverId到本地账户
  Future<void> _applyAccountServerIds(List<Map<String, dynamic>> accounts) async {
    if (!mounted) return;
    final accountProvider = context.read<AccountProvider>();
    
    for (final accountMap in accounts) {
      final serverId = accountMap['id'] as int?;
      final tempId = accountMap['id'] as String?; // 客户端临时ID（首次上传时）
      
      if (serverId == null) continue;
      
      // 通过临时ID查找本地账户
      if (tempId != null) {
        final existingAccount = accountProvider.byId(tempId);
        if (existingAccount != null && existingAccount.serverId == null) {
          // 更新本地账户的serverId
          final updatedAccount = existingAccount.copyWith(serverId: serverId);
          await accountProvider.updateAccount(updatedAccount);
        }
      }
    }
  }

  /// 检查是否是付费相关错误
  bool _isPaymentRequiredError(String error) {
    return error.contains('无云端同步权限') ||
        error.contains('付费已过期') ||
        error.contains('数据量超限') ||
        error.contains('请升级套餐') ||
        error.contains('无权限') ||
        error.contains('需要付费');
  }

  /// 显示VIP购买页面
  void _showVipPurchasePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VipPurchasePage()),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  if (_syncRecord != null) ...[
                    Text('云端账单数：${_syncRecord!.cloudBillCount ?? 0}',
                        style: TextStyle(color: cs.onSurface)),
                    if (_syncRecord!.lastSyncTime != null)
                      Text('最后同步：${_syncRecord!.lastSyncTime}',
                          style: TextStyle(color: cs.onSurface)),
                    if (_syncRecord!.dataVersion != null)
                      Text('数据版本：${_syncRecord!.dataVersion}',
                          style: TextStyle(color: cs.onSurface)),
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
          // 手动同步按钮（只在首次且版本号不同时同步）
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : () => _performAutoSync(isManual: true),
            icon: const Icon(Icons.sync),
            label: const Text('手动同步'),
          ),
        ],
      ),
    );
  }
}
