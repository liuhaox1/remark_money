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
    notifyListeners();
  }

  Future<void> updateRecord(Record updated) async {
    final list = await _repository.update(updated);
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final list = await _repository.remove(id);
    _records
      ..clear()
      ..addAll(list);
    _rebuildBookCache();
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
    return _sumWhere(
      (record) =>
          record.isIncome &&
          record.bookId == bookId &&
          record.date.year == month.year &&
          record.date.month == month.month,
      (record) => record.incomeValue,
    );
  }

  double monthExpense(DateTime month, String bookId) {
    return _sumWhere(
      (record) =>
          record.isExpense &&
          record.bookId == bookId &&
          record.date.year == month.year &&
          record.date.month == month.month,
      (record) => record.expenseValue,
    );
  }

  double dayIncome(String bookId, DateTime day) {
    return _sumWhere(
      (record) =>
          record.bookId == bookId &&
          record.isIncome &&
          DateUtilsX.isSameDay(record.date, day),
      (record) => record.incomeValue,
    );
  }

  double dayExpense(String bookId, DateTime day) {
    return _sumWhere(
      (record) =>
          record.bookId == bookId &&
          record.isExpense &&
          DateUtilsX.isSameDay(record.date, day),
      (record) => record.expenseValue,
    );
  }

  double _sumWhere(bool Function(Record record) predicate,
      double Function(Record record) selector) {
    double total = 0;
    for (final record in _records) {
      if (predicate(record)) {
        total += selector(record);
      }
    }
    return total;
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
}
