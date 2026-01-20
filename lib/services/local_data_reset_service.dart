import 'dart:io';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../repository/repository_factory.dart';
import 'user_scope.dart';

class LocalDataResetService {
  static const int _dbVersionMarker = 8;

  static Future<void> wipeAllLocalData() async {
    await _stopUsingDatabase();
    await _deleteAllDatabaseFiles();
    await _clearSharedPreferences();
    await RepositoryFactory.resetMigrationState();
  }

  /// Wipe local data that should not survive switching accounts.
  ///
  /// Keeps general app settings (theme, etc.) intact.
  static Future<void> wipeAccountScopedLocalData() async {
    await _stopUsingDatabase();
    await _deleteCurrentScopedDatabaseFiles();
    await _clearAccountScopedSharedPreferences();
  }

  static Future<void> _stopUsingDatabase() async {
    try {
      await DatabaseHelper().close();
    } catch (_) {}
  }

  static String _dbFileNameForUser(int userId) {
    if (userId <= 0) return 'remark_money_guest.db';
    return 'remark_money_u$userId.db';
  }

  static Future<void> _deleteCurrentScopedDatabaseFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/${_dbFileNameForUser(UserScope.userId)}';
      await _deleteDbAtPath(dbPath);
    } catch (_) {}
  }

  static Future<void> _deleteAllDatabaseFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFiles = <String>{};

      await for (final entity in Directory(dir.path).list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (!name.startsWith('remark_money')) continue;
        if (!name.endsWith('.db')) continue;
        dbFiles.add(entity.path);
      }

      // Always include the legacy db name in case it's still around.
      dbFiles.add('${dir.path}/remark_money.db');

      for (final p in dbFiles) {
        await _deleteDbAtPath(p);
      }
    } catch (_) {}
  }

  static Future<void> _deleteDbAtPath(String dbPath) async {
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
  }

  static Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 视为“全新安装”，避免 DatabaseHelper 打开后尝试从 SharedPreferences 迁移。
    await prefs.setBool('db_migration_completed_v$_dbVersionMarker', true);
    // 视为“全新安装”，避免 DatabaseHelper 打开后尝试从 SharedPreferences 迁移。
    await prefs.setBool('db_migration_completed_v$_dbVersionMarker', true);
    await prefs.setBool('db_migration_completed_v1', true);
    await prefs.setBool('use_shared_preferences', false);
  }

  static Future<void> _clearAccountScopedSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = UserScope.userId;
    final scopePrefix = UserScope.prefix;

    final scopedPrefixes = <String>[scopePrefix];
    if (uid > 0) {
      scopedPrefixes.addAll([
        'sync_outbox_u${uid}_',
        'meta_sync_last_ms_u${uid}_',
        'sync_v2_last_change_id_u${uid}_',
        'sync_v2_conflicts_u${uid}_',
        'sync_v2_summary_checked_at_u${uid}_',
      ]);
    } else {
      scopedPrefixes.add('sync_outbox_');
    }

    final canClearLegacy = uid <= 0 || (prefs.getInt('sync_owner_user_id') ?? 0) == uid;
    final legacyExactKeys = <String>{
      'books_v1',
      'active_book_v1',
      'records_v1',
      'budget_v1',
      'recurring_records_v1',
      'record_templates_v1',
      'savings_plans_v1',
      'tags_v1',
      'record_tags_v1',
      'accounts_v1',
      'account_delete_queue_v1',
      'category_delete_queue_v1',
      'tag_delete_queue_v1',
      'savings_plan_delete_queue_v1',
    };
    final legacyPrefixes = <String>[
      'accounts_v1_',
      'categories_v1_',
      'book_invite_code_',
    ];

    final keys = prefs.getKeys().toList(growable: false);
    for (final k in keys) {
      final matchesScoped = scopedPrefixes.any((p) {
        if (p == 'sync_outbox_' && k.startsWith('sync_outbox_u')) return false;
        return k.startsWith(p);
      });
      final matchesLegacy =
          canClearLegacy && (legacyExactKeys.contains(k) || legacyPrefixes.any(k.startsWith));

      if (matchesScoped || matchesLegacy) {
        try {
          await prefs.remove(k);
        } catch (_) {}
      }
    }
  }
}
