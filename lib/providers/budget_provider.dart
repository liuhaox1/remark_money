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
  }) async {
    final entry = BudgetEntry(
      total: totalBudget,
      categoryBudgets: Map<String, double>.from(categoryBudgets),
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
}
