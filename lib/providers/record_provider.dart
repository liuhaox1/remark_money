import 'dart:math';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../models/account.dart';
import '../models/import_result.dart';
import '../repository/repository_factory.dart';
import '../repository/record_repository_db.dart';
import '../utils/date_utils.dart';
import '../utils/validation_utils.dart';
import '../utils/error_handler.dart';
import '../services/data_version_service.dart';
import '../services/user_stats_service.dart';
import '../services/sync_outbox_service.dart';
import 'account_provider.dart';

class RecordProvider extends ChangeNotifier {
  RecordProvider();

  // SharedPreferences 版本和数据库版本都实现了同样的方法签名，这里用 dynamic 接受
  final dynamic _repository = RepositoryFactory.createRecordRepository();
  
  // 不再全量加载，只保留最近使用的记录缓存（用于快速访问）
  final List<Record> _recentRecordsCache = [];
  static const int _maxCacheSize = 1000; // 最多缓存1000条最近记录

  // 统计缓存（使用数据库聚合查询的结果）
  final Map<String, Map<int, Map<int, MonthStats>>> _monthStatsCache = {};
  final Map<String, Map<DateTime, DayStats>> _dayStatsCache = {};

  final Random _random = Random();

  // 兼容性：返回空列表，实际查询应该使用按需查询方法
  List<Record> get records => List.unmodifiable(_recentRecordsCache);

  bool _loaded = false;
  bool get loaded => _loaded;

  int _changeCounter = 0;
  int get changeCounter => _changeCounter;

  void _notifyChanged() {
    _changeCounter++;
    notifyListeners();
  }

  // 检查是否使用数据库
  bool get _isUsingDatabase => RepositoryFactory.isUsingDatabase;

  /// 初始化（不再全量加载）
  Future<void> load() async {
    if (_loaded) return;
    try {
      // 如果是数据库版本，只加载最近的记录用于缓存
      if (_isUsingDatabase) {
        final dbRepo = _repository as dynamic;
        // 使用反射检查是否有 loadRecordsPaginated 方法
        if (dbRepo.toString().contains('RecordRepositoryDb') || 
            (dbRepo.runtimeType.toString().contains('RecordRepositoryDb'))) {
          // 加载最近1000条记录作为缓存
          _recentRecordsCache.clear();
          final recent = await dbRepo.loadRecordsPaginated(limit: _maxCacheSize);
          _recentRecordsCache.addAll(recent);
        } else {
          // SharedPreferences 版本：仍然全量加载（兼容性）
          final list = await _repository.loadRecords();
          _recentRecordsCache
            ..clear()
            ..addAll(list);
        }
      } else {
        // SharedPreferences 版本：仍然全量加载（兼容性）
        final list = await _repository.loadRecords();
        _recentRecordsCache
          ..clear()
          ..addAll(list);
      }
      
      _loaded = true;
      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  /// 刷新最近记录缓存（用于同步后 UI 立即更新，避免逐条 notify/落库带来的卡顿）
  Future<void> refreshRecentCache({String? bookId}) async {
    if (!_loaded) {
      await load();
      return;
    }
    if (!_isUsingDatabase) {
      _notifyChanged();
      return;
    }

    try {
      final dbRepo = _repository as dynamic;
      if (!(dbRepo.runtimeType.toString().contains('RecordRepositoryDb'))) {
        _notifyChanged();
        return;
      }
      final recent = await dbRepo.loadRecordsPaginated(
        bookId: bookId,
        limit: _maxCacheSize,
      );
      _recentRecordsCache
        ..clear()
        ..addAll(recent);
      _clearCache();
      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.refreshRecentCache', e, stackTrace);
      rethrow;
    }
  }

  Future<Record> addRecord({
    required double amount,
    required String remark,
    required DateTime date,
    required String categoryKey,
    required String bookId,
    required String accountId,
    TransactionDirection direction = TransactionDirection.out,
    bool includeInStats = true,
    String? pairId,
    AccountProvider? accountProvider,
  }) async {
    // 数据验证
    final amountError = ValidationUtils.validateAmount(amount);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    final remarkError = ValidationUtils.validateRemark(remark);
    if (remarkError != null) {
      throw ArgumentError(remarkError);
    }

    final dateError = ValidationUtils.validateDate(date);
    if (dateError != null) {
      throw ArgumentError(dateError);
    }

    if (categoryKey.isEmpty) {
      throw ArgumentError('分类不能为空');
    }

    try {
      var resolvedAccountId = accountId;
      // 记一笔不强制用户手动选账户：为空/未知时自动兜底到默认钱包
      if (resolvedAccountId.isEmpty && accountProvider != null) {
        final fallback =
            await accountProvider.ensureDefaultWallet(bookId: bookId);
        resolvedAccountId = fallback.id;
      } else if (resolvedAccountId.isNotEmpty &&
          accountProvider != null &&
          accountProvider.byId(resolvedAccountId) == null) {
        final fallback =
            await accountProvider.ensureDefaultWallet(bookId: bookId);
        resolvedAccountId = fallback.id;
      }

      final record = Record(
        id: _generateId(),
        amount: amount.abs(),
        remark: remark,
        date: date,
        categoryKey: categoryKey,
        bookId: bookId,
        accountId: resolvedAccountId,
        direction: direction,
        includeInStats: includeInStats,
        pairId: pairId,
      );

      if (_isUsingDatabase) {
        // 数据库版本：直接插入，不清空缓存
        final dbRepo = _repository as dynamic;
        await dbRepo.saveRecord(record);
        
        // 如果是最近的记录，添加到缓存前面
        if (_recentRecordsCache.length < _maxCacheSize) {
          _recentRecordsCache.insert(0, record);
        } else {
          // 如果缓存已满，移除最后一条，添加新记录到前面
          _recentRecordsCache.removeLast();
          _recentRecordsCache.insert(0, record);
        }
      } else {
        // SharedPreferences 版本：兼容旧逻辑
        final list = await _repository.insert(record);
        _recentRecordsCache
          ..clear()
          ..addAll(list);
      }
      
      _clearCache();

      await _applyAccountDelta(accountProvider, record);

      // 数据修改时版本号+1
      await DataVersionService.incrementVersion(bookId);

      // 记录到同步发件箱（透明后台同步）
      await SyncOutboxService.instance.enqueueUpsert(record);

      // 更新用户统计
      await UserStatsService.updateRecordStats(date);

      _notifyChanged();
      return record;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.addRecord', e, stackTrace);
      rethrow;
    }
  }

  Future<int> countRecordsForAccount(String bookId, Account account) async {
    try {
      if (_isUsingDatabase &&
          _repository.runtimeType.toString().contains('RecordRepositoryDb')) {
        final dbRepo = _repository as dynamic;
        final ids = <String>[account.id];
        final sid = account.serverId;
        if (sid != null) {
          ids.add('server_$sid');
          ids.add('$sid');
        }
        return await dbRepo.countRecordsByAccountIds(
          bookId: bookId,
          accountIds: ids,
        ) as int;
      }

      final list = await _repository.loadRecords(bookId: bookId) as List<Record>;
      return list.where((r) => r.accountId == account.id).length;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.countRecordsForAccount', e, stackTrace);
      rethrow;
    }
  }

  Future<int> deleteRecordsForAccount(String bookId, Account account) async {
    try {
      final ids = <String>[account.id];
      final sid = account.serverId;
      if (sid != null) {
        ids.add('server_$sid');
        ids.add('$sid');
      }

      if (_isUsingDatabase &&
          _repository.runtimeType.toString().contains('RecordRepositoryDb')) {
        final dbRepo = _repository as dynamic;
        final deleted = await dbRepo.deleteRecordsByAccountIds(
          bookId: bookId,
          accountIds: ids,
        ) as int;

        if (deleted > 0) {
          _recentRecordsCache.removeWhere(
            (r) => r.bookId == bookId && ids.contains(r.accountId),
          );
          _clearCache();
          _notifyChanged();
        }
        return deleted;
      }

      // SharedPreferences 版本：加载并过滤后保存
      final list = await _repository.loadRecords() as List<Record>;
      final filtered = list.where((r) => !(r.bookId == bookId && ids.contains(r.accountId))).toList();
      await _repository.saveRecords(filtered);
      _recentRecordsCache
        ..clear()
        ..addAll(filtered.take(_maxCacheSize));
      _clearCache();
      _notifyChanged();
      return list.length - filtered.length;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.deleteRecordsForAccount', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateRecord(
    Record updated, {
    AccountProvider? accountProvider,
  }) async {
    // 数据验证
    final amountError = ValidationUtils.validateAmount(updated.amount);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    final remarkError = ValidationUtils.validateRemark(updated.remark);
    if (remarkError != null) {
      throw ArgumentError(remarkError);
    }

    final dateError = ValidationUtils.validateDate(updated.date);
    if (dateError != null) {
      throw ArgumentError(dateError);
    }

    try {
      Record? old;
      if (_isUsingDatabase) {
        // 数据库版本：从数据库查询旧记录
        final dbRepo = _repository as dynamic;
        old = await dbRepo.loadRecordById(updated.id);
        await dbRepo.saveRecord(updated);
        
        // 更新缓存中的记录
        final index = _recentRecordsCache.indexWhere((r) => r.id == updated.id);
        if (index != -1) {
          _recentRecordsCache[index] = updated;
        }
      } else {
        // SharedPreferences 版本：兼容旧逻辑
        old = _recentRecordsCache.firstWhere(
          (r) => r.id == updated.id,
          orElse: () => updated,
        );
        final list = await _repository.update(updated);
        _recentRecordsCache
          ..clear()
          ..addAll(list);
      }
      
      _clearCache();

      if (old != null) {
        await _applyAccountDelta(accountProvider, old, reverse: true);
        await _applyAccountDelta(accountProvider, updated);
      }

      // 数据修改时版本号+1
      await DataVersionService.incrementVersion(updated.bookId);

      // 记录到同步发件箱（透明后台同步）
      await SyncOutboxService.instance.enqueueUpsert(updated);

      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.updateRecord', e, stackTrace);
      rethrow;
    }
  }

  /// 回填服务器ID（serverId），用于同步后写回本地
  Future<void> setServerId(String billId, int serverId) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      await dbRepo.updateServerId(billId, serverId);
      // 更新缓存中的记录
      final index = _recentRecordsCache.indexWhere((r) => r.id == billId);
      if (index != -1) {
        _recentRecordsCache[index] = _recentRecordsCache[index].copyWith(serverId: serverId);
      }
      _clearCache();
    } else {
      // SharedPreferences 版本：更新内存缓存并持久化
      final index = _recentRecordsCache.indexWhere((r) => r.id == billId);
      if (index != -1) {
        _recentRecordsCache[index] = _recentRecordsCache[index].copyWith(serverId: serverId);
        final list = await _repository.update(_recentRecordsCache[index]);
        _recentRecordsCache
          ..clear()
          ..addAll(list);
      }
    }
  }

  Future<void> setServerSyncState(
    String billId, {
    int? serverId,
    int? serverVersion,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      try {
        await dbRepo.updateServerSyncState(
          billId,
          serverId: serverId,
          serverVersion: serverVersion,
        );
      } catch (_) {
        if (serverId != null) {
          await dbRepo.updateServerId(billId, serverId);
        }
      }

      final index = _recentRecordsCache.indexWhere((r) => r.id == billId);
      if (index != -1) {
        _recentRecordsCache[index] = _recentRecordsCache[index].copyWith(
          serverId: serverId ?? _recentRecordsCache[index].serverId,
          serverVersion: serverVersion ?? _recentRecordsCache[index].serverVersion,
        );
      }
      _clearCache();
      return;
    }

    final index = _recentRecordsCache.indexWhere((r) => r.id == billId);
    if (index != -1) {
      _recentRecordsCache[index] = _recentRecordsCache[index].copyWith(
        serverId: serverId ?? _recentRecordsCache[index].serverId,
        serverVersion: serverVersion ?? _recentRecordsCache[index].serverVersion,
      );
      final list = await _repository.update(_recentRecordsCache[index]);
      _recentRecordsCache
        ..clear()
        ..addAll(list);
    }
  }

  Future<void> setServerSyncStatesBulk(
    List<({String billId, int? serverId, int? serverVersion})> updates,
  ) async {
    if (updates.isEmpty) return;

    if (_isUsingDatabase && _repository is RecordRepositoryDb) {
      await (_repository as RecordRepositoryDb).updateServerSyncStatesBulk(updates);

      for (final u in updates) {
        final index = _recentRecordsCache.indexWhere((r) => r.id == u.billId);
        if (index == -1) continue;
        _recentRecordsCache[index] = _recentRecordsCache[index].copyWith(
          serverId: u.serverId ?? _recentRecordsCache[index].serverId,
          serverVersion: u.serverVersion ?? _recentRecordsCache[index].serverVersion,
        );
      }
      _clearCache();
      return;
    }

    for (final u in updates) {
      await setServerSyncState(
        u.billId,
        serverId: u.serverId,
        serverVersion: u.serverVersion,
      );
    }
  }

  Future<void> deleteRecord(
    String id, {
    AccountProvider? accountProvider,
  }) async {
    if (id.isEmpty) {
      throw ArgumentError('记录ID不能为空');
    }

    try {
      Record? old;
      if (_isUsingDatabase) {
        // 数据库版本：从数据库查询旧记录
        final dbRepo = _repository as dynamic;
        old = await dbRepo.loadRecordById(id);
        await dbRepo.remove(id);
        
        // 从缓存中移除
        _recentRecordsCache.removeWhere((r) => r.id == id);
      } else {
        // SharedPreferences 版本：兼容旧逻辑
        try {
          old = _recentRecordsCache.firstWhere((r) => r.id == id);
        } catch (_) {
          old = null;
        }
        final list = await _repository.remove(id);
        _recentRecordsCache
          ..clear()
          ..addAll(list);
      }
      
      _clearCache();

      if (old != null) {
        // 清理标签关联（不影响主流程）
        try {
          final tagRepo = RepositoryFactory.createTagRepository();
          await tagRepo.deleteLinksForRecord(id);
        } catch (_) {}

        await _applyAccountDelta(accountProvider, old, reverse: true);
        // 数据修改时版本号+1
        await DataVersionService.incrementVersion(old.bookId);

        // 记录到同步发件箱（透明后台同步）
        await SyncOutboxService.instance.enqueueDelete(old);
      }

      _notifyChanged();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.deleteRecord', e, stackTrace);
      rethrow;
    }
  }

  /// 同步方法：获取指定账本的记录（从缓存，兼容旧代码）
  List<Record> recordsForBook(String bookId) {
    return List<Record>.from(
      _recentRecordsCache.where((r) => r.bookId == bookId && r.includeInStats),
    );
  }

  /// 获取指定账本的全部记录（包含不计入统计的转账/存款等）
  List<Record> recordsForBookAll(String bookId) {
    return List<Record>.from(_recentRecordsCache.where((r) => r.bookId == bookId));
  }

  /// 异步方法：获取指定账本的记录（使用数据库查询）
  Future<List<Record>> recordsForBookAsync(String bookId) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForPeriod(
        bookId: bookId,
        start: DateTime(1970, 1, 1),
        end: DateTime.now().add(const Duration(days: 365)),
      );
    } else {
      return recordsForBook(bookId);
    }
  }

  /// 异步方法：获取指定账本的全部记录（包含不计入统计的转账/存款等）
  Future<List<Record>> recordsForBookAllAsync(String bookId) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForPeriod(
        bookId: bookId,
        start: DateTime(1970, 1, 1),
        end: DateTime.now().add(const Duration(days: 365)),
      );
    } else {
      return recordsForBookAll(bookId);
    }
  }

  /// 同步方法：获取指定日期的记录（从缓存，兼容旧代码）
  List<Record> recordsForDay(String bookId, DateTime day) {
    return _recentRecordsCache
        .where((r) => r.bookId == bookId && 
                     DateUtilsX.isSameDay(r.date, day) && 
                     r.includeInStats)
        .toList();
  }

  /// 异步方法：获取指定日期的记录（使用数据库查询）
  Future<List<Record>> recordsForDayAsync(String bookId, DateTime day) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForDay(bookId: bookId, day: day);
    } else {
      return recordsForDay(bookId, day);
    }
  }

  /// 同步方法：获取指定月份的记录（从缓存，兼容旧代码）
  List<Record> recordsForMonth(String bookId, int year, int month) {
    return _recentRecordsCache
        .where((r) => r.bookId == bookId && 
                     r.date.year == year && 
                     r.date.month == month && 
                     r.includeInStats)
        .toList();
  }

  /// 异步方法：获取指定月份的记录（使用数据库查询）
  Future<List<Record>> recordsForMonthAsync(String bookId, int year, int month) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForMonth(
        bookId: bookId,
        year: year,
        month: month,
      );
    } else {
      return recordsForMonth(bookId, year, month);
    }
  }

  /// 同步方法：获取指定时间段的记录（从缓存，兼容旧代码）
  List<Record> recordsForPeriod(
    String bookId, {
    required DateTime start,
    required DateTime end,
  }) {
    return _recentRecordsCache
        .where((r) => r.bookId == bookId && 
                     !r.date.isBefore(start) && 
                     !r.date.isAfter(end) && 
                     r.includeInStats)
        .toList();
  }

  /// 同步方法：获取指定时间段的全部记录（包含不计入统计的转账/存款等）
  List<Record> recordsForPeriodAll(
    String bookId, {
    required DateTime start,
    required DateTime end,
  }) {
    return _recentRecordsCache
        .where((r) =>
            r.bookId == bookId &&
            !r.date.isBefore(start) &&
            !r.date.isAfter(end))
        .toList();
  }

  /// 异步方法：获取指定时间段的记录（使用数据库查询）
  Future<List<Record>> recordsForPeriodAsync(
    String bookId, {
    required DateTime start,
    required DateTime end,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForPeriod(
        bookId: bookId,
        start: start,
        end: end,
      );
    } else {
      return recordsForPeriod(bookId, start: start, end: end);
    }
  }

  /// 异步方法：获取指定时间段的全部记录（包含不计入统计的转账/存款等）
  Future<List<Record>> recordsForPeriodAllAsync(
    String bookId, {
    required DateTime start,
    required DateTime end,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForPeriod(
        bookId: bookId,
        start: start,
        end: end,
      );
    } else {
      return recordsForPeriodAll(bookId, start: start, end: end);
    }
  }

  /// 分页查询：获取指定时间段的记录（带分页）
  Future<List<Record>> recordsForPeriodPaginated(
    String bookId, {
    required DateTime start,
    required DateTime end,
    int limit = 50,
    int offset = 0,
    String? categoryKey,
    String? accountId,
    bool? isExpense,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.queryRecordsForPeriod(
        bookId: bookId,
        start: start,
        end: end,
        categoryKey: categoryKey,
        accountId: accountId,
        isExpense: isExpense,
        limit: limit,
        offset: offset,
      );
    } else {
      // SharedPreferences 版本：从缓存查询并手动分页
      var filtered = _recentRecordsCache
          .where((r) => r.bookId == bookId && 
                       !r.date.isBefore(start) && 
                       !r.date.isAfter(end) && 
                       r.includeInStats);
      
      if (categoryKey != null) {
        filtered = filtered.where((r) => r.categoryKey == categoryKey);
      }
      if (accountId != null) {
        filtered = filtered.where((r) => r.accountId == accountId);
      }
      if (isExpense != null) {
        filtered = filtered.where((r) => r.isExpense == isExpense);
      }
       
      final list = filtered.toList()
        ..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          final byServerId =
              (b.serverId ?? -1).compareTo(a.serverId ?? -1);
          if (byServerId != 0) return byServerId;
          return b.id.compareTo(a.id);
        });
      final endIndex = (offset + limit).clamp(0, list.length);
      return list.sublist(offset.clamp(0, list.length), endIndex);
    }
  }

  /// 使用数据库聚合查询获取时间段支出
  Future<double> periodExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.getPeriodExpense(bookId: bookId, start: start, end: end);
    } else {
      // SharedPreferences 版本：从缓存计算
      double expense = 0;
      for (final record in _recentRecordsCache) {
        if (record.bookId == bookId &&
            !record.date.isBefore(start) &&
            !record.date.isAfter(end) &&
            record.isExpense &&
            record.includeInStats &&
            !record.categoryKey.startsWith('transfer')) {
          expense += record.expenseValue;
        }
      }
      return expense;
    }
  }

  /// 使用数据库聚合查询获取时间段分类支出
  Future<Map<String, double>> periodCategoryExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      return await dbRepo.getPeriodCategoryExpense(bookId: bookId, start: start, end: end);
    } else {
      // SharedPreferences 版本：从缓存计算
      final result = <String, double>{};
      for (final record in _recentRecordsCache) {
        if (record.bookId == bookId &&
            !record.date.isBefore(start) &&
            !record.date.isAfter(end) &&
            record.isExpense &&
            record.includeInStats &&
            !record.categoryKey.startsWith('transfer')) {
          result[record.categoryKey] =
              (result[record.categoryKey] ?? 0) + record.expenseValue;
        }
      }
      return result;
    }
  }

  /// 同步方法：获取月份收入（从缓存，兼容旧代码）
  double monthIncome(DateTime month, String bookId) {
    final stats = _getMonthStats(month, bookId);
    return stats.income;
  }

  /// 异步方法：获取月份收入（使用数据库聚合查询）
  Future<double> monthIncomeAsync(DateTime month, String bookId) async {
    final stats = await getMonthStatsAsync(month, bookId);
    return stats.income;
  }

  /// 同步方法：获取月份支出（从缓存，兼容旧代码）
  double monthExpense(DateTime month, String bookId) {
    final stats = _getMonthStats(month, bookId);
    return stats.expense;
  }

  /// 异步方法：获取月份支出（使用数据库聚合查询）
  Future<double> monthExpenseAsync(DateTime month, String bookId) async {
    final stats = await getMonthStatsAsync(month, bookId);
    return stats.expense;
  }

  /// 同步方法：获取日期收入（从缓存，兼容旧代码）
  double dayIncome(String bookId, DateTime day) {
    final stats = _getDayStats(bookId, day);
    return stats.income;
  }

  /// 异步方法：获取日期收入（使用数据库聚合查询）
  Future<double> dayIncomeAsync(String bookId, DateTime day) async {
    final stats = await getDayStatsAsync(bookId, day);
    return stats.income;
  }

  /// 同步方法：获取日期支出（从缓存，兼容旧代码）
  double dayExpense(String bookId, DateTime day) {
    final stats = _getDayStats(bookId, day);
    return stats.expense;
  }

  /// 异步方法：获取日期支出（使用数据库聚合查询）
  Future<double> dayExpenseAsync(String bookId, DateTime day) async {
    final stats = await getDayStatsAsync(bookId, day);
    return stats.expense;
  }

  /// Import a batch of records from backup.
  ///
  /// - Skips empty input
  /// - Ensures record ids are unique in current storage
  /// - Keeps records ordered by date descending
  Future<ImportResult> importRecords(
    List<Record> imported, {
    required String activeBookId,
    required AccountProvider accountProvider,
  }) async {
    if (imported.isEmpty) {
      return const ImportResult(successCount: 0, failureCount: 0);
    }

    try {
      final accounts = accountProvider.accounts;
      
      if (accounts.isEmpty) {
        throw StateError('没有可用账户，请先添加账户');
      }

      final defaultAccount =
          accounts.firstWhere((a) => a.name == '现金', orElse: () => accounts.first);

      final newRecords = <Record>[];
      var failure = 0;

      for (final r in imported) {
        try {
          var record = r;
          
          // 数据验证
          final amountError = ValidationUtils.validateAmount(record.amount);
          if (amountError != null) {
            failure += 1;
            continue;
          }

          final dateError = ValidationUtils.validateDate(record.date);
          if (dateError != null) {
            failure += 1;
            continue;
          }

          // Map to current active book.
          record = record.copyWith(bookId: activeBookId);

          // Fix missing / unknown account.
          final hasAccount =
              accounts.any((a) => a.id == record.accountId);
          if (!hasAccount) {
            record = record.copyWith(accountId: defaultAccount.id);
          }

          // Ensure id uniqueness (检查数据库或缓存)
          if (_isUsingDatabase) {
            final dbRepo = _repository as dynamic;
            final existing = await dbRepo.loadRecordById(record.id);
            if (existing != null) {
              record = record.copyWith(id: _generateId());
            }
          } else {
            if (_recentRecordsCache.any((r) => r.id == record.id)) {
              record = record.copyWith(id: _generateId());
            }
          }

          newRecords.add(record);
        } catch (e) {
          ErrorHandler.logError('RecordProvider.importRecords (single record)', e);
          failure += 1;
        }
      }

      if (newRecords.isNotEmpty) {
        if (_isUsingDatabase) {
          // 数据库版本：批量插入
          final dbRepo = _repository as dynamic;
          await dbRepo.batchInsert(newRecords);
          
          // 更新缓存：添加新记录到前面
          for (final record in newRecords.reversed) {
            if (_recentRecordsCache.length < _maxCacheSize) {
              _recentRecordsCache.insert(0, record);
            } else {
              _recentRecordsCache.removeLast();
              _recentRecordsCache.insert(0, record);
            }
          }
        } else {
          // SharedPreferences 版本：兼容旧逻辑
          _recentRecordsCache.addAll(newRecords);
          _recentRecordsCache.sort((a, b) => b.date.compareTo(a.date));
          
          await (_repository as dynamic).saveRecords(_recentRecordsCache);
        }
        
        _clearCache();
        _notifyChanged();
      }

      return ImportResult(
        successCount: newRecords.length,
        failureCount: failure,
      );
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.importRecords', e, stackTrace);
      rethrow;
    }
  }

  /// 账户间转账：写入双方流水，但不计入统计（首页/账单不展示）
  Future<void> transfer({
    required AccountProvider accountProvider,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    double fee = 0,
    String bookId = 'default-book',
    DateTime? date,
    String? remark,
  }) async {
    // 数据验证
    final amountError = ValidationUtils.validateAmount(amount);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    if (fee < 0) {
      throw ArgumentError('手续费不能为负数');
    }

    if (fee > 0) {
      final feeError = ValidationUtils.validateAmount(fee);
      if (feeError != null) {
        throw ArgumentError('手续费：$feeError');
      }
    }

    if (fromAccountId.isEmpty || toAccountId.isEmpty) {
      throw ArgumentError('转出账户和转入账户不能为空');
    }

    if (fromAccountId == toAccountId) {
      throw ArgumentError('转出账户和转入账户不能相同');
    }

    try {
      // 需要在“资产-流水”中可追溯转账与存款，但不计入首页/账单统计：
      // - 转出账户：transfer-out（out）
      // - 转入账户：transfer-in（income）
      // - 手续费：transfer-fee（out，可选）
      final now = date ?? DateTime.now();
      final text = (remark == null || remark.trim().isEmpty) ? '转账' : remark.trim();
      final pairId = _generateId();

      await addRecord(
        amount: amount,
        remark: text,
        date: now,
        categoryKey: 'transfer-out',
        bookId: bookId,
        accountId: fromAccountId,
        direction: TransactionDirection.out,
        includeInStats: false,
        pairId: pairId,
        accountProvider: accountProvider,
      );

      await addRecord(
        amount: amount,
        remark: text,
        date: now,
        categoryKey: 'transfer-in',
        bookId: bookId,
        accountId: toAccountId,
        direction: TransactionDirection.income,
        includeInStats: false,
        pairId: pairId,
        accountProvider: accountProvider,
      );

      if (fee > 0) {
        await addRecord(
          amount: fee,
          remark: '手续费',
          date: now,
          categoryKey: 'transfer-fee',
          bookId: bookId,
          accountId: fromAccountId,
          direction: TransactionDirection.out,
          includeInStats: false,
          pairId: pairId,
          accountProvider: accountProvider,
        );
      }

      return;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.transfer', e, stackTrace);
      rethrow;
    }
  }

  Future<void> borrow({
    required AccountProvider accountProvider,
    required String debtAccountId,
    required String assetAccountId,
    required double amount,
    String bookId = 'default-book',
    DateTime? date,
    String? remark,
  }) async {
    final pairId = _generateId();
    final now = date ?? DateTime.now();
    final text = remark ?? '借入';
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'borrow-in',
      bookId: bookId,
      accountId: assetAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'borrow-liability',
      bookId: bookId,
      accountId: debtAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
  }

  Future<void> repay({
    required AccountProvider accountProvider,
    required String debtAccountId,
    required String assetAccountId,
    required double principal,
    double interest = 0,
    String bookId = 'default-book',
    DateTime? date,
    String? remark,
  }) async {
    final pairId = _generateId();
    final now = date ?? DateTime.now();
    final text = remark ?? '还款';
    if (principal > 0) {
      await addRecord(
        amount: principal,
        remark: text,
        date: now,
        categoryKey: 'repay-principal',
        bookId: bookId,
        accountId: assetAccountId,
        direction: TransactionDirection.out,
        includeInStats: false,
        pairId: pairId,
        accountProvider: accountProvider,
      );
      await addRecord(
        amount: principal,
        remark: text,
        date: now,
        categoryKey: 'repay-liability',
        bookId: bookId,
        accountId: debtAccountId,
        direction: TransactionDirection.out,
        includeInStats: false,
        pairId: pairId,
        accountProvider: accountProvider,
      );
    }
    if (interest > 0) {
      await addRecord(
        amount: interest,
        remark: '利息',
        date: now,
        categoryKey: 'interest',
        bookId: bookId,
        accountId: assetAccountId,
        direction: TransactionDirection.out,
        includeInStats: true,
        pairId: pairId,
        accountProvider: accountProvider,
      );
    }
  }

  Future<void> lendOut({
    required AccountProvider accountProvider,
    required String lendAccountId,
    required String assetAccountId,
    required double amount,
    String bookId = 'default-book',
    DateTime? date,
    String? remark,
  }) async {
    final pairId = _generateId();
    final now = date ?? DateTime.now();
    final text = remark ?? '借出';
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'lend-out',
      bookId: bookId,
      accountId: assetAccountId,
      direction: TransactionDirection.out,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'lend-receivable',
      bookId: bookId,
      accountId: lendAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
  }

  Future<void> receiveLend({
    required AccountProvider accountProvider,
    required String lendAccountId,
    required String assetAccountId,
    required double amount,
    String bookId = 'default-book',
    DateTime? date,
    String? remark,
  }) async {
    final pairId = _generateId();
    final now = date ?? DateTime.now();
    final text = remark ?? '收回借款';
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'lend-repay',
      bookId: bookId,
      accountId: assetAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
    await addRecord(
      amount: amount,
      remark: text,
      date: now,
      categoryKey: 'lend-receivable-down',
      bookId: bookId,
      accountId: lendAccountId,
      direction: TransactionDirection.out,
      includeInStats: false,
      pairId: pairId,
      accountProvider: accountProvider,
    );
  }

  /// 获取月份统计（使用数据库聚合查询或缓存）
  MonthStats _getMonthStats(DateTime month, String bookId) {
    // 检查缓存
    if (_monthStatsCache.containsKey(bookId)) {
      final yearMap = _monthStatsCache[bookId]!;
      if (yearMap.containsKey(month.year)) {
        final monthMap = yearMap[month.year]!;
        if (monthMap.containsKey(month.month)) {
          return monthMap[month.month]!;
        }
      }
    }

    // 如果使用数据库，使用聚合查询
    if (_isUsingDatabase) {
      // 异步查询，但这里需要同步返回，所以先返回0，然后异步更新缓存
      // 实际使用中应该使用 Future 版本
      return const MonthStats(income: 0, expense: 0);
    }

    // SharedPreferences 版本：从缓存计算
    double income = 0;
    double expense = 0;

    for (final record in _recentRecordsCache) {
      if (record.bookId == bookId &&
          record.date.year == month.year &&
          record.date.month == month.month) {
        if (!record.includeInStats) continue;
        // Keep behavior consistent with DB aggregates: transfer records are not part of income/expense stats.
        if (record.categoryKey.startsWith('transfer')) continue;
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }

    final stats = MonthStats(income: income, expense: expense);

    final yearMap = _monthStatsCache.putIfAbsent(bookId, () => {});
    final monthMap = yearMap.putIfAbsent(month.year, () => {});
    monthMap[month.month] = stats;

    return stats;
  }

  /// 异步获取月份统计（使用数据库聚合查询）
  Future<MonthStats> getMonthStatsAsync(DateTime month, String bookId) async {
    // 检查缓存
    if (_monthStatsCache.containsKey(bookId)) {
      final yearMap = _monthStatsCache[bookId]!;
      if (yearMap.containsKey(month.year)) {
        final monthMap = yearMap[month.year]!;
        if (monthMap.containsKey(month.month)) {
          return monthMap[month.month]!;
        }
      }
    }

    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      final stats = await dbRepo.getMonthStats(
        bookId: bookId,
        year: month.year,
        month: month.month,
      );
      
      final result = MonthStats(
        income: stats['income'] ?? 0.0,
        expense: stats['expense'] ?? 0.0,
      );
      
      // 更新缓存
      final yearMap = _monthStatsCache.putIfAbsent(bookId, () => {});
      final monthMap = yearMap.putIfAbsent(month.year, () => {});
      monthMap[month.month] = result;
      
      return result;
    } else {
      // SharedPreferences 版本：同步计算
      return _getMonthStats(month, bookId);
    }
  }

  /// 获取日期统计（使用数据库聚合查询或缓存）
  DayStats _getDayStats(String bookId, DateTime day) {
    // 检查缓存
    if (_dayStatsCache.containsKey(bookId)) {
      final dayMap = _dayStatsCache[bookId]!;
      final dayKey = DateTime(day.year, day.month, day.day);
      if (dayMap.containsKey(dayKey)) {
        return dayMap[dayKey]!;
      }
    }

    // 如果使用数据库，使用聚合查询
    if (_isUsingDatabase) {
      // 异步查询，但这里需要同步返回，所以先返回0
      return const DayStats(income: 0, expense: 0);
    }

    // SharedPreferences 版本：从缓存计算
    double income = 0;
    double expense = 0;

    for (final record in _recentRecordsCache) {
      if (record.bookId == bookId && DateUtilsX.isSameDay(record.date, day)) {
        if (!record.includeInStats) continue;
        if (record.categoryKey.startsWith('transfer')) continue;
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }

    final stats = DayStats(income: income, expense: expense);
    final dayKey = DateTime(day.year, day.month, day.day);

    final dayMap = _dayStatsCache.putIfAbsent(bookId, () => {});
    dayMap[dayKey] = stats;

    return stats;
  }

  /// 异步获取日期统计（使用数据库聚合查询）
  Future<DayStats> getDayStatsAsync(String bookId, DateTime day) async {
    // 检查缓存
    if (_dayStatsCache.containsKey(bookId)) {
      final dayMap = _dayStatsCache[bookId]!;
      final dayKey = DateTime(day.year, day.month, day.day);
      if (dayMap.containsKey(dayKey)) {
        return dayMap[dayKey]!;
      }
    }

    if (_isUsingDatabase) {
      final dbRepo = _repository as dynamic;
      final stats = await dbRepo.getDayStats(bookId: bookId, day: day);
      
      final result = DayStats(
        income: stats['income'] ?? 0.0,
        expense: stats['expense'] ?? 0.0,
      );
      
      // 更新缓存
      final dayKey = DateTime(day.year, day.month, day.day);
      final dayMap = _dayStatsCache.putIfAbsent(bookId, () => {});
      dayMap[dayKey] = result;
      
      return result;
    } else {
      // SharedPreferences 版本：同步计算
      return _getDayStats(bookId, day);
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomBits = _random.nextInt(1 << 31);
    return '${timestamp.toRadixString(16)}-${randomBits.toRadixString(16)}';
  }

  void _clearCache() {
    _monthStatsCache.clear();
    _dayStatsCache.clear();
  }

  Future<void> _applyAccountDelta(
    AccountProvider? accountProvider,
    Record record, {
    bool reverse = false,
  }) async {
    if (accountProvider == null || record.accountId.isEmpty) return;
    final target = accountProvider.byId(record.accountId);
    if (target == null) return;
    final baseDelta = record.isIncome ? record.amount : -record.amount;
    final delta = reverse ? -baseDelta : baseDelta;
    // 余额变化来自流水，不应触发“账户元数据同步”（否则每记一笔都会触发 accounts_changed -> 大量SQL/轮询）。
    await accountProvider.adjustBalance(
      record.accountId,
      delta,
      triggerSync: false,
    );
  }
}

class MonthStats {
  final double income;
  final double expense;

  const MonthStats({required this.income, required this.expense});
}

class DayStats {
  final double income;
  final double expense;

  const DayStats({required this.income, required this.expense});
}
