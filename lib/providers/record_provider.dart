import 'dart:math';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../models/import_result.dart';
import '../repository/repository_factory.dart';
import '../utils/date_utils.dart';
import '../utils/validation_utils.dart';
import '../utils/error_handler.dart';
import 'account_provider.dart';

class RecordProvider extends ChangeNotifier {
  RecordProvider();

  // SharedPreferences 版本和数据库版本都实现了同样的方法签名，这里用 dynamic 接受
  final dynamic _repository = RepositoryFactory.createRecordRepository();
  final List<Record> _records = [];
  final Map<String, List<Record>> _recordsByBook = {};

  final Map<String, Map<int, Map<int, _MonthStats>>> _monthStatsCache = {};
  final Map<String, Map<DateTime, _DayStats>> _dayStatsCache = {};

  final Random _random = Random();

  List<Record> get records => List.unmodifiable(_records);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final list = await _repository.loadRecords();
      _records
        ..clear()
        ..addAll(list);
      _rebuildBookCache();
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.load', e, stackTrace);
      // 保持 _loaded = false，允许重试
      _loaded = false;
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

    if (accountId.isEmpty) {
      throw ArgumentError('账户不能为空');
    }

    try {
      final record = Record(
        id: _generateId(),
        amount: amount.abs(),
        remark: remark,
        date: date,
        categoryKey: categoryKey,
        bookId: bookId,
        accountId: accountId,
        direction: direction,
        includeInStats: includeInStats,
        pairId: pairId,
      );

      final list = await _repository.insert(record);
      _records
        ..clear()
        ..addAll(list);
      _rebuildBookCache();
      _clearCache();

      await _applyAccountDelta(accountProvider, record);

      notifyListeners();
      return record;
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.addRecord', e, stackTrace);
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
      final old = _records.firstWhere(
        (r) => r.id == updated.id,
        orElse: () => updated,
      );
      final list = await _repository.update(updated);
      _records
        ..clear()
        ..addAll(list);
      _rebuildBookCache();
      _clearCache();

      await _applyAccountDelta(accountProvider, old, reverse: true);
      await _applyAccountDelta(accountProvider, updated);

      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.updateRecord', e, stackTrace);
      rethrow;
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
      try {
        old = _records.firstWhere((r) => r.id == id);
      } catch (_) {
        old = null;
      }

      final list = await _repository.remove(id);
      _records
        ..clear()
        ..addAll(list);
      _rebuildBookCache();
      _clearCache();

      if (old != null) {
        await _applyAccountDelta(accountProvider, old, reverse: true);
      }

      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('RecordProvider.deleteRecord', e, stackTrace);
      rethrow;
    }
  }

  List<Record> recordsForBook(String bookId) {
    return List<Record>.from(
      (_recordsByBook[bookId] ?? const []).where((r) => r.includeInStats),
    );
  }

  List<Record> recordsForDay(String bookId, DateTime day) {
    return recordsForBook(bookId)
        .where((r) => DateUtilsX.isSameDay(r.date, day))
        .toList();
  }

  List<Record> recordsForMonth(String bookId, int year, int month) {
    return recordsForBook(bookId)
        .where((r) => r.date.year == year && r.date.month == month)
        .toList();
  }

  List<Record> recordsForPeriod(
    String bookId, {
    required DateTime start,
    required DateTime end,
  }) {
    return recordsForBook(bookId).where((r) {
      return !r.date.isBefore(start) && !r.date.isAfter(end);
    }).toList();
  }

  double periodExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) {
    double expense = 0;
    for (final record in recordsForPeriod(bookId, start: start, end: end)) {
      if (record.isIncome || !record.includeInStats) continue;
      expense += record.expenseValue;
    }
    return expense;
  }

  Map<String, double> periodCategoryExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) {
    final result = <String, double>{};
    for (final record in recordsForPeriod(bookId, start: start, end: end)) {
      if (record.isIncome || !record.includeInStats) continue;
      result[record.categoryKey] =
          (result[record.categoryKey] ?? 0) + record.expenseValue;
    }
    return result;
  }

  double monthIncome(DateTime month, String bookId) {
    final stats = _getMonthStats(month, bookId);
    return stats.income;
  }

  double monthExpense(DateTime month, String bookId) {
    final stats = _getMonthStats(month, bookId);
    return stats.expense;
  }

  double dayIncome(String bookId, DateTime day) {
    final stats = _getDayStats(bookId, day);
    return stats.income;
  }

  double dayExpense(String bookId, DateTime day) {
    final stats = _getDayStats(bookId, day);
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
      final existingIds = _records.map((r) => r.id).toSet();
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

          // Ensure id uniqueness.
          if (existingIds.contains(record.id)) {
            record = record.copyWith(id: _generateId());
          }

          newRecords.add(record);
        } catch (e) {
          ErrorHandler.logError('RecordProvider.importRecords (single record)', e);
          failure += 1;
        }
      }

      if (newRecords.isNotEmpty) {
        _records.addAll(newRecords);
        _records.sort((a, b) => b.date.compareTo(a.date));
        
        // 使用 saveRecords 保存所有记录（兼容 SharedPreferences 和 Database）
        try {
          // 尝试调用 saveRecords（两种 Repository 都有这个方法）
          await (_repository as dynamic).saveRecords(_records);
        } catch (e) {
          // 如果失败，使用批量插入（仅 Database 版本）
          if (_repository.toString().contains('RecordRepositoryDb')) {
            await (_repository as dynamic).batchInsert(newRecords);
            // 重新加载所有记录
            final list = await _repository.loadRecords();
            _records
              ..clear()
              ..addAll(list);
          } else {
            rethrow;
          }
        }
        
        _rebuildBookCache();
        _clearCache();
        notifyListeners();
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

  Future<Record> transfer({
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
      final pairId = _generateId();
      final now = date ?? DateTime.now();
      final baseRemark = remark ?? '';
      final mainRemark = baseRemark.isEmpty ? '转账' : baseRemark;

      await addRecord(
        amount: amount,
        remark: mainRemark,
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
        remark: mainRemark,
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

      return _records.firstWhere((r) => r.pairId == pairId);
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

  _MonthStats _getMonthStats(DateTime month, String bookId) {
    if (_monthStatsCache.containsKey(bookId)) {
      final yearMap = _monthStatsCache[bookId]!;
      if (yearMap.containsKey(month.year)) {
        final monthMap = yearMap[month.year]!;
        if (monthMap.containsKey(month.month)) {
          return monthMap[month.month]!;
        }
      }
    }

    double income = 0;
    double expense = 0;

    for (final record in _records) {
      if (record.bookId == bookId &&
          record.date.year == month.year &&
          record.date.month == month.month) {
        if (!record.includeInStats) continue;
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }

    final stats = _MonthStats(income: income, expense: expense);

    final yearMap = _monthStatsCache.putIfAbsent(bookId, () => {});
    final monthMap = yearMap.putIfAbsent(month.year, () => {});
    monthMap[month.month] = stats;

    return stats;
  }

  _DayStats _getDayStats(String bookId, DateTime day) {
    if (_dayStatsCache.containsKey(bookId)) {
      final dayMap = _dayStatsCache[bookId]!;
      if (dayMap.containsKey(day)) {
        return dayMap[day]!;
      }
    }

    double income = 0;
    double expense = 0;

    for (final record in _records) {
      if (record.bookId == bookId && DateUtilsX.isSameDay(record.date, day)) {
        if (!record.includeInStats) continue;
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }

    final stats = _DayStats(income: income, expense: expense);

    final dayMap = _dayStatsCache.putIfAbsent(bookId, () => {});
    dayMap[day] = stats;

    return stats;
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomBits = _random.nextInt(1 << 31);
    return '${timestamp.toRadixString(16)}-${randomBits.toRadixString(16)}';
  }

  void _rebuildBookCache() {
    _recordsByBook.clear();
    for (final record in _records) {
      final list = _recordsByBook.putIfAbsent(record.bookId, () => []);
      list.add(record);
    }
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
    await accountProvider.adjustBalance(record.accountId, delta);
  }

}

class _MonthStats {
  final double income;
  final double expense;

  const _MonthStats({required this.income, required this.expense});
}

class _DayStats {
  final double income;
  final double expense;

  const _DayStats({required this.income, required this.expense});
}
