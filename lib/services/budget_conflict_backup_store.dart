import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BudgetConflictBackupStore {
  static String _key(String bookId) => 'budget_conflict_backup_$bookId';

  static Future<void> save(String bookId, Map<String, dynamic> budgetData) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'budget': budgetData,
    };
    await prefs.setString(_key(bookId), jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(bookId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookId));
  }
}

