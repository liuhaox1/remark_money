import 'package:shared_preferences/shared_preferences.dart';
import 'user_stats_service.dart';

/// 记账提醒服务
class ReminderService {
  static const String _reminderEnabledKey = 'reminder_enabled';
  static const String _reminderTimeKey = 'reminder_time';
  static const String _lastReminderDateKey = 'last_reminder_date';
  

  /// 检查是否需要提醒记账
  static Future<bool> shouldRemind() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_reminderEnabledKey) ?? false;
    if (!enabled) return false;

    final lastReminder = prefs.getString(_lastReminderDateKey);
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    
    // 今天已经提醒过了
    if (lastReminder != null && lastReminder.startsWith(todayStr)) {
      return false;
    }

    // 检查今天是否已经记账
    final stats = await UserStatsService.getStats();
    if (stats.lastRecordDate != null) {
      final lastDate = DateTime(
        stats.lastRecordDate!.year,
        stats.lastRecordDate!.month,
        stats.lastRecordDate!.day,
      );
      final todayDate = DateTime(today.year, today.month, today.day);
      if (lastDate.isAtSameMomentAs(todayDate)) {
        // 今天已经记账了
        return false;
      }
    }

    // 检查提醒时间
    final reminderTime = prefs.getString(_reminderTimeKey);
    if (reminderTime != null) {
      final timeParts = reminderTime.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 20;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      
      final now = DateTime.now();
      final reminderDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // 如果还没到提醒时间，不提醒
      if (now.isBefore(reminderDateTime)) {
        return false;
      }
    }

    return true;
  }

  /// 标记已提醒
  static Future<void> markReminded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReminderDateKey, DateTime.now().toIso8601String());
  }

  /// 启用/禁用提醒
  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
  }

  /// 设置提醒时间（格式：HH:mm）
  static Future<void> setReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderTimeKey, time);
  }

  /// 获取提醒时间
  static Future<String> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reminderTimeKey) ?? '20:00';
  }

  /// 获取提醒是否启用
  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderEnabledKey) ?? false;
  }
}
