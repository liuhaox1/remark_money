import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recurring_record.dart';
import '../services/meta_sync_notifier.dart';
import '../services/recurring_plan_delete_queue.dart';
import '../services/user_scope.dart';

class RecurringRecordRepository {
  static const _keyBase = 'recurring_records_v1';
  String get _key => UserScope.key(_keyBase);

  Future<List<RecurringRecordPlan>> loadPlansForBook(String bookId) async {
    final all = await loadPlans();
    return all.where((p) => p.bookId == bookId).toList(growable: false);
  }

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

  Future<void> replacePlansForBook(
      String bookId, List<RecurringRecordPlan> plans) async {
    final all = await loadPlans();
    all.removeWhere((p) => p.bookId == bookId);
    all.addAll(plans);
    await savePlans(all);
  }

  /// Insert or replace a plan based on its id.
  Future<List<RecurringRecordPlan>> upsert(RecurringRecordPlan plan) async {
    final list = await loadPlans();
    final now = DateTime.now();
    final index = list.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      final existing = list[index];
      list[index] = plan.copyWith(
        createdAt: existing.createdAt ?? plan.createdAt ?? now,
        updatedAt: now,
      );
    } else {
      list.add(plan.copyWith(
        createdAt: plan.createdAt ?? now,
        updatedAt: now,
      ));
    }
    await savePlans(list);
    MetaSyncNotifier.instance.notifyRecurringPlansChanged(plan.bookId);
    return list;
  }

  Future<List<RecurringRecordPlan>> remove(String id) async {
    final list = await loadPlans();
    String? bookId;
    for (final p in list) {
      if (p.id == id) {
        bookId = p.bookId;
        break;
      }
    }
    list.removeWhere((p) => p.id == id);
    await savePlans(list);
    if (bookId != null && bookId.isNotEmpty) {
      await RecurringPlanDeleteQueue.instance.enqueue(bookId, id);
      MetaSyncNotifier.instance.notifyRecurringPlansChanged(bookId);
    }
    return list;
  }
}
