import 'dart:convert';

/// 成就类型
enum AchievementType {
  basic,      // 基础成就
  consecutive, // 连续成就
  feature,    // 功能成就
  data,       // 数据成就
}

/// 成就模型
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon; // 图标名称或emoji
  final AchievementType type;
  final int target; // 目标值
  final int current; // 当前值
  final bool unlocked; // 是否已解锁
  final DateTime? unlockedAt; // 解锁时间

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.target,
    this.current = 0,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    AchievementType? type,
    int? target,
    int? current,
    bool? unlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      target: target ?? this.target,
      current: current ?? this.current,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type.name,
      'target': target,
      'current': current,
      'unlocked': unlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      type: AchievementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AchievementType.basic,
      ),
      target: map['target'] as int,
      current: map['current'] as int? ?? 0,
      unlocked: map['unlocked'] as bool? ?? false,
      unlockedAt: map['unlockedAt'] != null
          ? DateTime.parse(map['unlockedAt'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());
  factory Achievement.fromJson(String source) =>
      Achievement.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// 用户统计模型
class UserStats {
  final int consecutiveDays; // 连续记账天数
  final int totalDays; // 累计记账天数
  final int thisMonthCount; // 本月记账次数
  final int totalRecords; // 累计记账条数
  final DateTime? lastRecordDate; // 最后记账日期
  final List<DateTime> checkInDates; // 签到日期列表
  final DateTime? lastCheckInDate; // 最后签到日期
  final int consecutiveCheckInDays; // 连续签到天数

  UserStats({
    this.consecutiveDays = 0,
    this.totalDays = 0,
    this.thisMonthCount = 0,
    this.totalRecords = 0,
    this.lastRecordDate,
    this.checkInDates = const [],
    this.lastCheckInDate,
    this.consecutiveCheckInDays = 0,
  });

  UserStats copyWith({
    int? consecutiveDays,
    int? totalDays,
    int? thisMonthCount,
    int? totalRecords,
    DateTime? lastRecordDate,
    List<DateTime>? checkInDates,
    DateTime? lastCheckInDate,
    int? consecutiveCheckInDays,
  }) {
    return UserStats(
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      totalDays: totalDays ?? this.totalDays,
      thisMonthCount: thisMonthCount ?? this.thisMonthCount,
      totalRecords: totalRecords ?? this.totalRecords,
      lastRecordDate: lastRecordDate ?? this.lastRecordDate,
      checkInDates: checkInDates ?? this.checkInDates,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      consecutiveCheckInDays: consecutiveCheckInDays ?? this.consecutiveCheckInDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consecutiveDays': consecutiveDays,
      'totalDays': totalDays,
      'thisMonthCount': thisMonthCount,
      'totalRecords': totalRecords,
      'lastRecordDate': lastRecordDate?.toIso8601String(),
      'checkInDates': checkInDates.map((d) => d.toIso8601String()).toList(),
      'lastCheckInDate': lastCheckInDate?.toIso8601String(),
      'consecutiveCheckInDays': consecutiveCheckInDays,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      consecutiveDays: map['consecutiveDays'] as int? ?? 0,
      totalDays: map['totalDays'] as int? ?? 0,
      thisMonthCount: map['thisMonthCount'] as int? ?? 0,
      totalRecords: map['totalRecords'] as int? ?? 0,
      lastRecordDate: map['lastRecordDate'] != null
          ? DateTime.parse(map['lastRecordDate'] as String)
          : null,
      checkInDates: (map['checkInDates'] as List<dynamic>?)
              ?.map((d) => DateTime.parse(d as String))
              .toList() ??
          [],
      lastCheckInDate: map['lastCheckInDate'] != null
          ? DateTime.parse(map['lastCheckInDate'] as String)
          : null,
      consecutiveCheckInDays: map['consecutiveCheckInDays'] as int? ?? 0,
    );
  }

  String toJson() => json.encode(toMap());
  factory UserStats.fromJson(String source) =>
      UserStats.fromMap(json.decode(source) as Map<String, dynamic>);
}

