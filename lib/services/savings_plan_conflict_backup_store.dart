import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavingsPlanConflictBackupStore {
  static String _key(String bookId) => 'savings_plan_conflict_backup_v1_$bookId';

  static Future<void> save(String bookId, List<Map<String, dynamic>> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'plans': plans,
    };
    await prefs.setString(_key(bookId), jsonEncode(payload));
  }
}

