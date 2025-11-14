import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../repository/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider();

  final BudgetRepository _repository = BudgetRepository();

  Budget _budget = Budget(total: 0, categoryBudgets: {});
  Budget get budget => _budget;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _budget = await _repository.loadBudget();
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateBudget({
    required double totalBudget,
    required Map<String, double> categoryBudgets,
  }) async {
    final next = _budget.copyWith(
      total: totalBudget,
      categoryBudgets: Map<String, double>.from(categoryBudgets),
    );
    await _repository.saveBudget(next);
    _budget = next;
    notifyListeners();
  }

  Future<void> setTotal(double value) async {
    final next = _budget.copyWith(total: value);
    await _repository.saveBudget(next);
    _budget = next;
    notifyListeners();
  }

  Future<void> setCategoryBudget(String key, double value) async {
    final updated = {..._budget.categoryBudgets, key: value};
    final next = _budget.copyWith(categoryBudgets: updated);
    await _repository.saveBudget(next);
    _budget = next;
    notifyListeners();
  }

  Future<void> deleteCategoryBudget(String key) async {
    final updated = {..._budget.categoryBudgets}..remove(key);
    final next = _budget.copyWith(categoryBudgets: updated);
    await _repository.saveBudget(next);
    _budget = next;
    notifyListeners();
  }
}
