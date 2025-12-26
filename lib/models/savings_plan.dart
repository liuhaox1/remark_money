import 'dart:convert';

enum SavingsPlanType {
  flexible('flexible'),
  countdown('countdown'),
  monthlyFixed('monthly_fixed'),
  weeklyFixed('weekly_fixed');

  const SavingsPlanType(this.code);
  final String code;

  static SavingsPlanType fromCode(String? code) {
    return SavingsPlanType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => SavingsPlanType.flexible,
    );
  }
}

class SavingsPlan {
  const SavingsPlan({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.includeInStats,
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion,
    this.savedAmount = 0,
    this.archived = false,
    this.startDate,
    this.endDate,
    this.monthlyDay,
    this.monthlyAmount,
    this.weeklyWeekday,
    this.weeklyAmount,
    this.executedCount = 0,
    this.lastExecutedAt,
    this.defaultFromAccountId,
  });

  final String id;
  final String bookId;
  final String accountId;
  final String name;
  final SavingsPlanType type;
  final double targetAmount;
  final bool includeInStats;
  final double savedAmount;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncVersion;

  final DateTime? startDate;
  final DateTime? endDate;

  final int? monthlyDay;
  final double? monthlyAmount;

  /// 1..7 (Mon..Sun)
  final int? weeklyWeekday;
  final double? weeklyAmount;

  final int executedCount;
  final DateTime? lastExecutedAt;

  final String? defaultFromAccountId;

  SavingsPlan copyWith({
    String? id,
    String? bookId,
    String? accountId,
    String? name,
    SavingsPlanType? type,
    double? targetAmount,
    bool? includeInStats,
    double? savedAmount,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
    DateTime? startDate,
    DateTime? endDate,
    int? monthlyDay,
    double? monthlyAmount,
    int? weeklyWeekday,
    double? weeklyAmount,
    int? executedCount,
    DateTime? lastExecutedAt,
    String? defaultFromAccountId,
  }) {
    return SavingsPlan(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      includeInStats: includeInStats ?? this.includeInStats,
      savedAmount: savedAmount ?? this.savedAmount,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      weeklyWeekday: weeklyWeekday ?? this.weeklyWeekday,
      weeklyAmount: weeklyAmount ?? this.weeklyAmount,
      executedCount: executedCount ?? this.executedCount,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      defaultFromAccountId: defaultFromAccountId ?? this.defaultFromAccountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'accountId': accountId,
      'name': name,
      'type': type.code,
      'targetAmount': targetAmount,
      'includeInStats': includeInStats,
      'savedAmount': savedAmount,
      'archived': archived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (syncVersion != null) 'syncVersion': syncVersion,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'monthlyDay': monthlyDay,
      'monthlyAmount': monthlyAmount,
      'weeklyWeekday': weeklyWeekday,
      'weeklyAmount': weeklyAmount,
      'executedCount': executedCount,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      'defaultFromAccountId': defaultFromAccountId,
    };
  }

  factory SavingsPlan.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? s) => s == null ? null : DateTime.tryParse(s);
    double parseDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return SavingsPlan(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      accountId: map['accountId'] as String,
      name: map['name'] as String? ?? '存钱计划',
      type: SavingsPlanType.fromCode(map['type'] as String?),
      targetAmount: parseDouble(map['targetAmount']),
      includeInStats: (map['includeInStats'] as bool?) ?? false,
      savedAmount: map['savedAmount'] == null ? 0 : parseDouble(map['savedAmount']),
      archived: (map['archived'] as bool?) ?? false,
      createdAt: parseDate(map['createdAt'] as String?) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt'] as String?) ?? DateTime.now(),
      syncVersion: (map['syncVersion'] is num)
          ? (map['syncVersion'] as num).toInt()
          : int.tryParse((map['syncVersion'] ?? '').toString()),
      startDate: parseDate(map['startDate'] as String?),
      endDate: parseDate(map['endDate'] as String?),
      monthlyDay: map['monthlyDay'] as int?,
      monthlyAmount: map['monthlyAmount'] == null ? null : parseDouble(map['monthlyAmount']),
      weeklyWeekday: map['weeklyWeekday'] as int?,
      weeklyAmount: map['weeklyAmount'] == null ? null : parseDouble(map['weeklyAmount']),
      executedCount: (map['executedCount'] as int?) ?? 0,
      lastExecutedAt: parseDate(map['lastExecutedAt'] as String?),
      defaultFromAccountId: map['defaultFromAccountId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  static SavingsPlan fromJson(String s) =>
      SavingsPlan.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
