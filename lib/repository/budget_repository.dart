import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../services/user_scope.dart';

class BudgetRepository {
  static const _keyBase = 'budget_v1';
  String get _key => UserScope.key(_keyBase);

  Future<Budget> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) {
      return Budget.empty();
    }

    try {
      return Budget.fromJson(raw);
    } catch (_) {
      return Budget.empty();
    }
  }

  Future<void> saveBudget(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, budget.toJson());
  }
}
