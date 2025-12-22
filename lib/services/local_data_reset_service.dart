import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../repository/repository_factory.dart';

class LocalDataResetService {
  static const int _dbVersionMarker = 8;

  static Future<void> wipeAllLocalData() async {
    await _stopUsingDatabase();
    await _deleteDatabaseFiles();
    await _clearSharedPreferences();
    await RepositoryFactory.resetMigrationState();
  }

  static Future<void> _stopUsingDatabase() async {
    try {
      await DatabaseHelper().close();
    } catch (_) {}
  }

  static Future<void> _deleteDatabaseFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/remark_money.db';

      try {
        await deleteDatabase(dbPath);
      } catch (_) {}

      for (final suffix in const ['', '-wal', '-shm']) {
        try {
          final file = File('$dbPath$suffix');
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 视为“全新安装”，避免 DatabaseHelper 打开后尝试从 SharedPreferences 迁移。
    await prefs.setBool('db_migration_completed_v$_dbVersionMarker', true);
    await prefs.setBool('db_migration_completed_v1', true);
    await prefs.setBool('use_shared_preferences', false);
  }
}
