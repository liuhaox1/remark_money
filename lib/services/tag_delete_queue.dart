import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TagDeleteQueue {
  TagDeleteQueue._();

  static final TagDeleteQueue instance = TagDeleteQueue._();

  static const _key = 'tag_delete_queue_v1';

  Future<Map<String, List<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final out = <String, List<String>>{};
      decoded.forEach((bookId, v) {
        if (v is List) {
          out[bookId] = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<void> enqueue({required String bookId, required String tagId}) async {
    final b = bookId.trim();
    final t = tagId.trim();
    if (b.isEmpty || t.isEmpty) return;
    final current = await load();
    final next = <String, List<String>>{...current};
    final list = (next[b] ?? const <String>[]).toList();
    if (!list.contains(t)) list.add(t);
    next[b] = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clearBook(String bookId) async {
    final b = bookId.trim();
    if (b.isEmpty) return;
    final current = await load();
    if (!current.containsKey(b)) return;
    final next = <String, List<String>>{...current}..remove(b);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }
}

