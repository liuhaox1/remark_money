import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_plan.dart';

class SavingsPlanRepository {
  static const _key = 'savings_plans_v1';

  Future<List<SavingsPlan>> loadPlans({required String bookId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final list = raw
        .map((e) => SavingsPlan.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .where((p) => p.bookId == bookId)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> savePlans(List<SavingsPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        plans.map((p) => jsonEncode(p.toMap())).toList(growable: false);
    await prefs.setStringList(_key, payload);
  }

  Future<List<SavingsPlan>> upsertPlan(SavingsPlan plan) async {
    final all = await _loadAll();
    final idx = all.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      all[idx] = plan;
    } else {
      all.insert(0, plan);
    }
    await savePlans(all);
    return all.where((p) => p.bookId == plan.bookId).toList();
  }

  Future<List<SavingsPlan>> deletePlan(String id) async {
    final all = await _loadAll();
    all.removeWhere((p) => p.id == id);
    await savePlans(all);
    return all;
  }

  Future<List<SavingsPlan>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => SavingsPlan.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }
}

