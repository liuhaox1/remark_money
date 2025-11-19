import 'dart:math';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../repository/record_repository.dart';
import '../utils/date_utils.dart';

class RecordProvider extends ChangeNotifier {
  RecordProvider();

  final RecordRepository _repository = RecordRepository();
  final List<Record> _records = [];
  final Map<String, List<Record>> _recordsByBook = {};
  
  // 添加缓存来存储每月统计数据
  final Map<String, Map<int, Map<int, _MonthStats>>> _monthStatsCache = {};
  
  // 添加缓存来存储每日统计数据
  final Map<String, Map<DateTime, _DayStats>> _dayStatsCache = {};

  final Random _random = Random();

  List<Record> get records => List.unmodifiable(_records);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final list = await _repository.loadRecords();
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addRecord({
    required double amount,
    required String remark,
    required DateTime date,
    required String categoryKey,
    required String bookId,
  }) async {
    final record = Record(
      id: _generateId(),
      amount: amount,
      remark: remark,
      date: date,
      categoryKey: categoryKey,
      bookId: bookId,
    );

    final list = await _repository.insert(record);
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
    _clearCache(); // 清除缓存
    notifyListeners();
  }

  Future<void> updateRecord(Record updated) async {
    final list = await _repository.update(updated);
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
    _clearCache(); // 清除缓存
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final list = await _repository.remove(id);
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
    _clearCache(); // 清除缓存
    notifyListeners();
  }

  List<Record> recordsForBook(String bookId) {
    return List<Record>.from(_recordsByBook[bookId] ?? const []);
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

  double monthIncome(DateTime month, String bookId) {
    // 检查缓存
    final stats = _getMonthStats(month, bookId);
    return stats.income;
  }

  double monthExpense(DateTime month, String bookId) {
    // 检查缓存
    final stats = _getMonthStats(month, bookId);
    return stats.expense;
  }

  double dayIncome(String bookId, DateTime day) {
    // 检查缓存
    final stats = _getDayStats(bookId, day);
    return stats.income;
  }

  double dayExpense(String bookId, DateTime day) {
    // 检查缓存
    final stats = _getDayStats(bookId, day);
    return stats.expense;
  }

  // 获取月份统计数据
  _MonthStats _getMonthStats(DateTime month, String bookId) {
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
    
    // 计算统计数据
    double income = 0;
    double expense = 0;
    
    for (final record in _records) {
      if (record.bookId == bookId && 
          record.date.year == month.year && 
          record.date.month == month.month) {
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }
    
    final stats = _MonthStats(income: income, expense: expense);
    
    // 缓存结果
    final yearMap = _monthStatsCache.putIfAbsent(bookId, () => {});
    final monthMap = yearMap.putIfAbsent(month.year, () => {});
    monthMap[month.month] = stats;
    
    return stats;
  }
  
  // 获取每日统计数据
  _DayStats _getDayStats(String bookId, DateTime day) {
    // 检查缓存
    if (_dayStatsCache.containsKey(bookId)) {
      final dayMap = _dayStatsCache[bookId]!;
      if (dayMap.containsKey(day)) {
        return dayMap[day]!;
      }
    }
    
    // 计算统计数据
    double income = 0;
    double expense = 0;
    
    for (final record in _records) {
      if (record.bookId == bookId && DateUtilsX.isSameDay(record.date, day)) {
        if (record.isIncome) {
          income += record.incomeValue;
        } else {
          expense += record.expenseValue;
        }
      }
    }
    
    final stats = _DayStats(income: income, expense: expense);
    
    // 缓存结果
    final dayMap = _dayStatsCache.putIfAbsent(bookId, () => {});
    dayMap[day] = stats;
    
    return stats;
  }

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    // dart2js/js ints are 32-bit,避免位移溢出导致 max=0 的异常
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
  
  // 清除所有缓存
  void _clearCache() {
    _monthStatsCache.clear();
    _dayStatsCache.clear();
  }
}

// 添加用于缓存统计信息的类
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
