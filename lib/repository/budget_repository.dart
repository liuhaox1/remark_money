import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';

class BudgetRepository {
  static const _key = 'budget_v1';

  Future<Budget> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) {
      return Budget(total: 0, categoryBudgets: {});
    }

    return Budget.fromJson(raw);
  }

  Future<void> saveBudget(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, budget.toJson());
  }

  Future<void> setTotalBudget(double value) async {
    final b = await loadBudget();
    final newB = b.copyWith(total: value);
    await saveBudget(newB);
  }

  Future<void> setCategoryBudget(String key, double value) async {
    final b = await loadBudget();
    final updated = {...b.categoryBudgets, key: value};
    await saveBudget(b.copyWith(categoryBudgets: updated));
  }

  Future<void> deleteCategoryBudget(String key) async {
    final b = await loadBudget();
    final updated = {...b.categoryBudgets};
    updated.remove(key);
    await saveBudget(b.copyWith(categoryBudgets: updated));
  }
}
