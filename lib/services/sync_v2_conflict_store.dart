import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncV2ConflictStore {
  static String _key(String bookId) => 'sync_v2_conflicts_$bookId';

  static Future<List<Map<String, dynamic>>> list(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(bookId)) ?? <String>[];
    final out = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        out.add((jsonDecode(s) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    return out;
  }

  static Future<void> remove(String bookId, {required String opId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(bookId)) ?? <String>[];
    if (raw.isEmpty) return;
    final next = <String>[];
    for (final s in raw) {
      try {
        final m = (jsonDecode(s) as Map).cast<String, dynamic>();
        if ((m['opId'] as String?) == opId) continue;
      } catch (_) {}
      next.add(s);
    }
    await prefs.setStringList(_key(bookId), next);
  }

  static Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookId));
  }

  static Future<void> addConflict(String bookId, Map<String, dynamic> conflict) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(bookId)) ?? <String>[];

    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = <String, dynamic>{
      'timeMs': now,
      ...conflict,
    };
    final opId = entry['opId'] as String?;

    final next = <String>[jsonEncode(entry)];
    for (final s in raw) {
      if (opId == null) {
        next.add(s);
        continue;
      }
      try {
        final m = (jsonDecode(s) as Map).cast<String, dynamic>();
        if ((m['opId'] as String?) == opId) continue;
      } catch (_) {}
      next.add(s);
    }

    // keep last 50
    if (next.length > 50) {
      next.removeRange(50, next.length);
    }

    await prefs.setStringList(_key(bookId), next);
  }

  static Future<int> count(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(bookId)) ?? <String>[]).length;
  }
}
