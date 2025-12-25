import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CategoryDeleteQueue {
  CategoryDeleteQueue._();

  static final CategoryDeleteQueue instance = CategoryDeleteQueue._();

  static const _key = 'category_delete_queue_v1';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> enqueue(String key) async {
    final k = key.trim();
    if (k.isEmpty) return;
    final current = await load();
    if (current.contains(k)) return;
    final next = <String>[...current, k];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

