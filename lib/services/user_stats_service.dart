import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 用户统计数据服务
class UserStatsService {
  static const String _keyLastRecordDate = 'user_stats_last_record_date';
  static const String _keyConsecutiveDays = 'user_stats_consecutive_days';
  static const String _keyTotalDays = 'user_stats_total_days';
  static const String _keyTotalRecords = 'user_stats_total_records';
  static const String _keyCheckInDates = 'user_stats_check_in_dates';
  static const String _keyLastCheckInDate = 'user_stats_last_check_in_date';
  static const String _keyThisMonthCount = 'user_stats_this_month_count';
  static const String _keyLastMonth = 'user_stats_last_month';

  /// 用户统计数据模型
  static Future<UserStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    final lastRecordDateStr = prefs.getString(_keyLastRecordDate);
    final lastRecordDate = lastRecordDateStr != null 
        ? DateTime.tryParse(lastRecordDateStr) 
        : null;
    
    final consecutiveDays = prefs.getInt(_keyConsecutiveDays) ?? 0;
    final totalDays = prefs.getInt(_keyTotalDays) ?? 0;
    final totalRecords = prefs.getInt(_keyTotalRecords) ?? 0;
    final thisMonthCount = prefs.getInt(_keyThisMonthCount) ?? 0;
    
    // 获取签到日期列表
    final checkInDatesStr = prefs.getString(_keyCheckInDates);
    final checkInDates = checkInDatesStr != null
        ? (jsonDecode(checkInDatesStr) as List)
            .map((e) => DateTime.parse(e as String))
            .toList()
        : <DateTime>[];
    
    final lastCheckInDateStr = prefs.getString(_keyLastCheckInDate);
    final lastCheckInDate = lastCheckInDateStr != null
        ? DateTime.tryParse(lastCheckInDateStr)
        : null;

    return UserStats(
      consecutiveDays: consecutiveDays,
      totalDays: totalDays,
      totalRecords: totalRecords,
      thisMonthCount: thisMonthCount,
      lastRecordDate: lastRecordDate,
      checkInDates: checkInDates,
      lastCheckInDate: lastCheckInDate,
    );
  }

  /// 记录一次记账
  static Future<void> recordTransaction() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final lastRecordDateStr = prefs.getString(_keyLastRecordDate);
    final lastRecordDate = lastRecordDateStr != null
        ? DateTime.tryParse(lastRecordDateStr)
        : null;
    
    int consecutiveDays = prefs.getInt(_keyConsecutiveDays) ?? 0;
    int totalDays = prefs.getInt(_keyTotalDays) ?? 0;
    int totalRecords = prefs.getInt(_keyTotalRecords) ?? 0;
    int thisMonthCount = prefs.getInt(_keyThisMonthCount) ?? 0;
    final lastMonth = prefs.getInt(_keyLastMonth);
    
    // 更新总记录数
    totalRecords++;
    
    // 更新本月记录数
    if (lastMonth != now.month) {
      // 新月份，重置本月计数
      thisMonthCount = 1;
      await prefs.setInt(_keyLastMonth, now.month);
    } else {
      thisMonthCount++;
    }
    
    // 更新连续记账天数
    if (lastRecordDate == null) {
      // 首次记账
      consecutiveDays = 1;
      totalDays = 1;
    } else {
      final lastDate = DateTime(lastRecordDate.year, lastRecordDate.month, lastRecordDate.day);
      final daysDiff = today.difference(lastDate).inDays;
      
      if (daysDiff == 0) {
        // 同一天，不更新连续天数
      } else if (daysDiff == 1) {
        // 连续记账
        consecutiveDays++;
        if (totalDays == 0) totalDays = 1;
        totalDays++;
      } else {
        // 中断了，重置连续天数
        consecutiveDays = 1;
        if (totalDays == 0) totalDays = 1;
        totalDays++;
      }
    }
    
    // 保存数据
    await prefs.setString(_keyLastRecordDate, today.toIso8601String());
    await prefs.setInt(_keyConsecutiveDays, consecutiveDays);
    await prefs.setInt(_keyTotalDays, totalDays);
    await prefs.setInt(_keyTotalRecords, totalRecords);
    await prefs.setInt(_keyThisMonthCount, thisMonthCount);
  }

  /// 签到
  static Future<bool> checkIn() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final lastCheckInDateStr = prefs.getString(_keyLastCheckInDate);
    final lastCheckInDate = lastCheckInDateStr != null
        ? DateTime.tryParse(lastCheckInDateStr)
        : null;
    
    // 检查今天是否已签到
    if (lastCheckInDate != null) {
      final lastDate = DateTime(lastCheckInDate.year, lastCheckInDate.month, lastCheckInDate.day);
      if (today.isAtSameMomentAs(lastDate)) {
        return false; // 今天已签到
      }
    }
    
    // 获取签到日期列表
    final checkInDatesStr = prefs.getString(_keyCheckInDates);
    final checkInDates = checkInDatesStr != null
        ? (jsonDecode(checkInDatesStr) as List)
            .map((e) => DateTime.parse(e as String))
            .toList()
        : <DateTime>[];
    
    // 添加今天的签到
    checkInDates.add(today);
    
    // 只保留最近365天的签到记录
    final oneYearAgo = today.subtract(const Duration(days: 365));
    checkInDates.removeWhere((date) => date.isBefore(oneYearAgo));
    
    // 保存数据
    await prefs.setString(_keyLastCheckInDate, today.toIso8601String());
    await prefs.setString(_keyCheckInDates, jsonEncode(
        checkInDates.map((d) => d.toIso8601String()).toList()));
    
    return true; // 签到成功
  }

  /// 检查今天是否已签到
  static Future<bool> isCheckedInToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final lastCheckInDateStr = prefs.getString(_keyLastCheckInDate);
    if (lastCheckInDateStr == null) return false;
    
    final lastCheckInDate = DateTime.tryParse(lastCheckInDateStr);
    if (lastCheckInDate == null) return false;
    
    final lastDate = DateTime(lastCheckInDate.year, lastCheckInDate.month, lastCheckInDate.day);
    return today.isAtSameMomentAs(lastDate);
  }

  /// 更新记录统计（兼容旧代码）
  static Future<void> updateRecordStats(DateTime date) async {
    await recordTransaction();
  }

  /// 获取连续签到天数
  static Future<int> getConsecutiveCheckInDays() async {
    final prefs = await SharedPreferences.getInstance();
    final checkInDatesStr = prefs.getString(_keyCheckInDates);
    if (checkInDatesStr == null) return 0;
    
    final checkInDates = (jsonDecode(checkInDatesStr) as List)
        .map((e) => DateTime.parse(e as String))
        .toList();
    
    if (checkInDates.isEmpty) return 0;
    
    // 按日期排序（最新的在前）
    checkInDates.sort((a, b) => b.compareTo(a));
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 计算连续签到天数
    int consecutiveDays = 0;
    DateTime expectedDate = today;
    
    for (final date in checkInDates) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly.isAtSameMomentAs(expectedDate)) {
        consecutiveDays++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return consecutiveDays;
  }
}

/// 用户统计数据模型
class UserStats {
  final int consecutiveDays;
  final int totalDays;
  final int totalRecords;
  final int thisMonthCount;
  final DateTime? lastRecordDate;
  final List<DateTime> checkInDates;
  final DateTime? lastCheckInDate;

  UserStats({
    required this.consecutiveDays,
    required this.totalDays,
    required this.totalRecords,
    required this.thisMonthCount,
    this.lastRecordDate,
    required this.checkInDates,
    this.lastCheckInDate,
  });
}
