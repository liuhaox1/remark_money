import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncV2ConflictStore {
  static const String _legacyPrefix = 'sync_v2_conflicts_';

  static Future<int?> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auth_user_id');
  }

  static String _key(String bookId, {required int? userId}) {
    if (userId == null) return '$_legacyPrefix$bookId';
    return '${_legacyPrefix}u${userId}_$bookId';
  }

  static Future<List<Map<String, dynamic>>> list(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    final raw =
        prefs.getStringList(_key(bookId, userId: uid)) ?? <String>[];
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
    final uid = prefs.getInt('auth_user_id');
    final raw =
        prefs.getStringList(_key(bookId, userId: uid)) ?? <String>[];
    if (raw.isEmpty) return;
    final next = <String>[];
    for (final s in raw) {
      try {
        final m = (jsonDecode(s) as Map).cast<String, dynamic>();
        if ((m['opId'] as String?) == opId) continue;
      } catch (_) {}
      next.add(s);
    }
    await prefs.setStringList(_key(bookId, userId: uid), next);
  }

  static Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = await _userId();
    await prefs.remove(_key(bookId, userId: uid));
    if (uid != null) {
      await prefs.remove(_key(bookId, userId: null));
    }
  }

  static Future<void> addConflict(String bookId, Map<String, dynamic> conflict) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    final raw =
        prefs.getStringList(_key(bookId, userId: uid)) ?? <String>[];

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

    await prefs.setStringList(_key(bookId, userId: uid), next);
    if (uid != null) {
      await prefs.remove(_key(bookId, userId: null));
    }
  }

  static Future<int> count(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    return (prefs.getStringList(_key(bookId, userId: uid)) ?? <String>[])
        .length;
  }
}
