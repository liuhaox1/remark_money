import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/savings_plan.dart';
import '../services/meta_sync_notifier.dart';
import '../services/savings_plan_delete_queue.dart';

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
    MetaSyncNotifier.instance.notifySavingsPlansChanged(plan.bookId);
    return all.where((p) => p.bookId == plan.bookId).toList();
  }

  Future<void> deletePlan({
    required String bookId,
    required String planId,
  }) async {
    final all = await _loadAll();
    all.removeWhere((p) => p.id == planId);
    await savePlans(all);
    await SavingsPlanDeleteQueue.instance.enqueue(bookId, planId);
    MetaSyncNotifier.instance.notifySavingsPlansChanged(bookId);
  }

  Future<void> replacePlansForBook(String bookId, List<SavingsPlan> plans) async {
    final all = await _loadAll();
    all.removeWhere((p) => p.bookId == bookId);
    all.addAll(plans);
    await savePlans(all);
  }

  Future<List<SavingsPlan>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => SavingsPlan.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }
}
