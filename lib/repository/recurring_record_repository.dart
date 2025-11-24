import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recurring_record.dart';

class RecurringRecordRepository {
  static const _key = 'recurring_records_v1';

  Future<List<RecurringRecordPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => RecurringRecordPlan.fromMap(
              jsonDecode(e) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> savePlans(List<RecurringRecordPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = plans.map((p) => jsonEncode(p.toMap())).toList();
    await prefs.setStringList(_key, payload);
  }

  /// Insert or replace a plan based on its id.
  Future<List<RecurringRecordPlan>> upsert(RecurringRecordPlan plan) async {
    final list = await loadPlans();
    final index = list.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      list[index] = plan;
    } else {
      list.add(plan);
    }
    await savePlans(list);
    return list;
  }

  Future<List<RecurringRecordPlan>> remove(String id) async {
    final list = await loadPlans();
    list.removeWhere((p) => p.id == id);
    await savePlans(list);
    return list;
  }
}

