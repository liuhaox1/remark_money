import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_scope.dart';

class CategoryDeleteQueue {
  CategoryDeleteQueue._();

  static final CategoryDeleteQueue instance = CategoryDeleteQueue._();

  static const _keyBase = 'category_delete_queue_v1';

  String get _key => UserScope.key(_keyBase);

  Future<bool> _canAdoptLegacy(SharedPreferences prefs) async {
    final uid = UserScope.userId;
    if (uid <= 0) return false;
    return (prefs.getInt('sync_owner_user_id') ?? 0) == uid;
  }

  Future<Map<String, List<String>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_key);
    if ((raw == null || raw.isEmpty) && await _canAdoptLegacy(prefs)) {
      final legacy = prefs.getString(_keyBase);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          await prefs.setString(_key, legacy);
          await prefs.remove(_keyBase);
          raw = legacy;
        } catch (_) {}
      }
    }
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded.map((e) => e.toString()).toList();
        final cleaned =
            list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        return {
          'default-book': cleaned,
        };
      }
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final out = <String, List<String>>{};
        map.forEach((bookId, v) {
          if (v is List) {
            out[bookId] =
                v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          }
        });
        return out;
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<List<String>> loadForBook(String bookId) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final all = await loadAll();
    return all[bid] ?? const <String>[];
  }

  Future<void> enqueue(String bookId, String key) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final k = key.trim();
    if (k.isEmpty) return;
    final current = await loadAll();
    final list = (current[bid] ?? const <String>[]).toList();
    if (list.contains(k)) return;
    list.add(k);
    final next = <String, List<String>>{
      ...current,
      bid: list,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clearBook(String bookId) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final current = await loadAll();
    if (!current.containsKey(bid)) return;
    final next = <String, List<String>>{...current}..remove(bid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
