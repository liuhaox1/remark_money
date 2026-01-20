import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_scope.dart';

class RecurringPlanDeleteQueue {
  RecurringPlanDeleteQueue._();

  static final RecurringPlanDeleteQueue instance = RecurringPlanDeleteQueue._();

  static const _keyBase = 'recurring_plan_delete_queue_v1';

  String get _key => UserScope.key(_keyBase);

  Future<bool> _canAdoptLegacy(SharedPreferences prefs) async {
    final uid = UserScope.userId;
    if (uid <= 0) return false;
    return (prefs.getInt('sync_owner_user_id') ?? 0) == uid;
  }

  Future<Map<String, List<String>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_key);
    if ((raw == null || raw.trim().isEmpty) && await _canAdoptLegacy(prefs)) {
      final legacy = prefs.getString(_keyBase);
      if (legacy != null && legacy.trim().isNotEmpty) {
        try {
          await prefs.setString(_key, legacy);
          await prefs.remove(_keyBase);
          raw = legacy;
        } catch (_) {}
      }
    }
    if (raw == null || raw.trim().isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      final result = <String, List<String>>{};
      decoded.forEach((k, v) {
        final bookId = k.toString();
        if (v is List) {
          result[bookId] = v.map((e) => e.toString()).toList();
        }
      });
      return result;
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> _saveAll(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<List<String>> loadForBook(String bookId) async {
    final all = await _loadAll();
    return all[bookId]?.toList(growable: false) ?? const <String>[];
  }

  Future<void> enqueue(String bookId, String planId) async {
    if (bookId.isEmpty || planId.isEmpty) return;
    final all = await _loadAll();
    final list = all[bookId] ?? <String>[];
    if (!list.contains(planId)) {
      list.add(planId);
    }
    all[bookId] = list;
    await _saveAll(all);
  }

  Future<void> clearBook(String bookId) async {
    final all = await _loadAll();
    all.remove(bookId);
    await _saveAll(all);
  }
}

