import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../repository/repository_factory.dart';

class AppSettingsService {
  static final AppSettingsService instance = AppSettingsService._();
  AppSettingsService._();

  static const String keyHideAmountsAssets = 'hide_amounts_assets';

  Future<bool> getBool(
    String key, {
    bool defaultValue = false,
  }) async {
    try {
      if (RepositoryFactory.isUsingDatabase) {
        final db = await DatabaseHelper().database;
        final maps = await db.query(
          Tables.appSettings,
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (maps.isEmpty) return defaultValue;
        final raw = maps.first['value'] as String?;
        if (raw == null) return defaultValue;
        return raw == '1' || raw.toLowerCase() == 'true';
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      debugPrint('[AppSettingsService] getBool failed key=$key err=$e');
      return defaultValue;
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      if (RepositoryFactory.isUsingDatabase) {
        final db = await DatabaseHelper().database;
        await db.insert(
          Tables.appSettings,
          {
            'key': key,
            'value': value ? '1' : '0',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('[AppSettingsService] setBool failed key=$key value=$value err=$e');
      rethrow;
    }
  }
}
