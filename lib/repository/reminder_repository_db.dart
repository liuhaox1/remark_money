import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/reminder_settings.dart';

/// 使用数据库的提醒仓库（新版本）
class ReminderRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _defaultId = 'default';

  /// 加载提醒设置
  Future<ReminderSettings> load() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.reminders,
        where: 'id = ?',
        whereArgs: [_defaultId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return ReminderSettings.defaults;
      }

      final map = maps.first;
      return ReminderSettings(
        enabled: (map['enabled'] as int) == 1,
        timeOfDay: TimeOfDay(
          hour: map['hour'] as int,
          minute: map['minute'] as int,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[ReminderRepositoryDb] load failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存提醒设置
  Future<void> save(ReminderSettings settings) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        Tables.reminders,
        {
          'id': _defaultId,
          'enabled': settings.enabled ? 1 : 0,
          'hour': settings.timeOfDay.hour,
          'minute': settings.timeOfDay.minute,
          'days': '[]', // 暂时不支持多天设置
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('[ReminderRepositoryDb] save failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

