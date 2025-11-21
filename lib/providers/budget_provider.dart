import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../repository/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider();

  final BudgetRepository _repository = BudgetRepository();

  Budget _budgetStore = Budget.empty();
  Budget get store => _budgetStore;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _budgetStore = await _repository.loadBudget();
    _loaded = true;
    notifyListeners();
  }

  BudgetEntry budgetForBook(String bookId) {
    return _budgetStore.entryFor(bookId);
  }

  Future<void> updateBudgetForBook({
    required String bookId,
    required double totalBudget,
    required Map<String, double> categoryBudgets,
    double? annualBudget,
    int? periodStartDay,
  }) async {
    final current = _budgetStore.entries[bookId];
    final entry = BudgetEntry(
      total: totalBudget,
      categoryBudgets: Map<String, double>.from(categoryBudgets),
      periodStartDay: periodStartDay ?? current?.periodStartDay ?? 1,
      annualTotal: annualBudget ?? current?.annualTotal ?? 0,
    );
    _budgetStore = _budgetStore.replaceEntry(bookId, entry);
    await _repository.saveBudget(_budgetStore);
    notifyListeners();
  }

  Future<void> setTotal(String bookId, double value) async {
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: value,
      categoryBudgets: current.categoryBudgets,
      annualBudget: current.annualTotal,
    );
  }

  Future<void> setAnnualTotal(String bookId, double value) async {
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      annualBudget: value,
    );
  }

  Future<void> setCategoryBudget(
    String bookId,
    String key,
    double value,
  ) async {
    final current = budgetForBook(bookId);
    final updated = {...current.categoryBudgets, key: value};
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: updated,
    );
  }

  Future<void> deleteCategoryBudget(String bookId, String key) async {
    final current = budgetForBook(bookId);
    final updated = {...current.categoryBudgets}..remove(key);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: updated,
    );
  }

  Future<void> setPeriodStartDay(String bookId, int day) async {
    final safeDay = day.clamp(1, 28);
    final current = budgetForBook(bookId);
    await updateBudgetForBook(
      bookId: bookId,
      totalBudget: current.total,
      categoryBudgets: current.categoryBudgets,
      periodStartDay: safeDay,
    );
  }

  Future<void> resetBudgetForBook(String bookId) async {
    final current = budgetForBook(bookId);
    final entry = BudgetEntry(
      total: 0,
      categoryBudgets: const {},
      periodStartDay: current.periodStartDay,
    );
    _budgetStore = _budgetStore.replaceEntry(bookId, entry);
    await _repository.saveBudget(_budgetStore);
    notifyListeners();
  }

  /// 当前账本在指定日期下的预算周期（起止日）
  DateTimeRange currentPeriodRange(String bookId, DateTime anchor) {
    final entry = budgetForBook(bookId);
    final startDay = entry.periodStartDay.clamp(1, 28);
    final today = DateTime(anchor.year, anchor.month, anchor.day);

    late DateTime start;
    late DateTime end;

    if (today.day >= startDay) {
      start = DateTime(today.year, today.month, startDay);
      end = DateTime(today.year, today.month + 1, startDay)
          .subtract(const Duration(days: 1));
    } else {
      start = DateTime(today.year, today.month - 1, startDay);
      end = DateTime(today.year, today.month, startDay)
          .subtract(const Duration(days: 1));
    }

    return DateTimeRange(start: start, end: end);
  }
}
