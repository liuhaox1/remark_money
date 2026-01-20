import '../models/record.dart';

enum RecurringPeriodType { weekly, monthly }

/// Basic recurring record plan, used to remind and prefill future records.
class RecurringRecordPlan {
  final String id;
  final String bookId;
  final String categoryKey;
  final String accountId;
  final TransactionDirection direction;
  final bool includeInStats;
  final double amount;
  final String remark;
  final bool enabled;
  final RecurringPeriodType periodType;
  final DateTime startDate;
  final DateTime nextDate;
  final DateTime? lastRunAt;
  final List<String> tagIds;
  final int? syncVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Weekly: 1-7 (Mon..Sun). When null, fallback to startDate.weekday.
  final int? weekday;

  /// Monthly: 1-31. When null, fallback to startDate.day.
  final int? monthDay;

  const RecurringRecordPlan({
    required this.id,
    required this.bookId,
    required this.categoryKey,
    required this.accountId,
    required this.direction,
    required this.includeInStats,
    required this.amount,
    required this.remark,
    this.enabled = true,
    required this.periodType,
    required this.startDate,
    required this.nextDate,
    this.lastRunAt,
    this.tagIds = const <String>[],
    this.syncVersion,
    this.createdAt,
    this.updatedAt,
    this.weekday,
    this.monthDay,
  });

  RecurringRecordPlan copyWith({
    String? id,
    String? bookId,
    String? categoryKey,
    String? accountId,
    TransactionDirection? direction,
    bool? includeInStats,
    double? amount,
    String? remark,
    bool? enabled,
    RecurringPeriodType? periodType,
    DateTime? startDate,
    DateTime? nextDate,
    DateTime? lastRunAt,
    List<String>? tagIds,
    int? syncVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? weekday,
    int? monthDay,
  }) {
    return RecurringRecordPlan(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      categoryKey: categoryKey ?? this.categoryKey,
      accountId: accountId ?? this.accountId,
      direction: direction ?? this.direction,
      includeInStats: includeInStats ?? this.includeInStats,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
      enabled: enabled ?? this.enabled,
      periodType: periodType ?? this.periodType,
      startDate: startDate ?? this.startDate,
      nextDate: nextDate ?? this.nextDate,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      tagIds: tagIds ?? this.tagIds,
      syncVersion: syncVersion ?? this.syncVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      weekday: weekday ?? this.weekday,
      monthDay: monthDay ?? this.monthDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'categoryKey': categoryKey,
      'accountId': accountId,
      'direction': direction == TransactionDirection.income ? 'in' : 'out',
      'includeInStats': includeInStats,
      'amount': amount,
      'remark': remark,
      'enabled': enabled,
      'periodType': periodType == RecurringPeriodType.weekly ? 'week' : 'month',
      'startDate': startDate.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'lastRunAt': lastRunAt?.toIso8601String(),
      'tagIds': tagIds,
      if (syncVersion != null) 'syncVersion': syncVersion,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'weekday': weekday,
      'monthDay': monthDay,
    };
  }

  factory RecurringRecordPlan.fromMap(Map<String, dynamic> map) {
    final rawDirection = map['direction'] as String? ?? 'out';
    final direction = rawDirection == 'in'
        ? TransactionDirection.income
        : TransactionDirection.out;
    final rawPeriod = map['periodType'] as String? ?? 'month';
    final periodType = rawPeriod == 'week'
        ? RecurringPeriodType.weekly
        : RecurringPeriodType.monthly;
    final enabled = map['enabled'] as bool? ?? true;
    DateTime? parseDate(String? s) => s == null ? null : DateTime.tryParse(s);
    final rawStart = map['startDate'] as String? ?? map['nextDate'] as String;
    final rawLast = map['lastRunAt'] as String?;
    final rawTags = map['tagIds'];
    final tagIds = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];
    final weekdayRaw = map['weekday'];
    final monthDayRaw = map['monthDay'];
    return RecurringRecordPlan(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      categoryKey: map['categoryKey'] as String,
      accountId: map['accountId'] as String,
      direction: direction,
      includeInStats: map['includeInStats'] as bool? ?? true,
      amount: (map['amount'] as num).toDouble(),
      remark: map['remark'] as String? ?? '',
      enabled: enabled,
      periodType: periodType,
      startDate: DateTime.parse(rawStart),
      nextDate: DateTime.parse(map['nextDate'] as String),
      lastRunAt: rawLast == null ? null : DateTime.parse(rawLast),
      tagIds: tagIds,
      syncVersion: (map['syncVersion'] is num)
          ? (map['syncVersion'] as num).toInt()
          : int.tryParse((map['syncVersion'] ?? '').toString()),
      createdAt: parseDate(map['createdAt'] as String?),
      updatedAt: parseDate(map['updatedAt'] as String?),
      weekday: weekdayRaw is int ? weekdayRaw : int.tryParse('$weekdayRaw'),
      monthDay: monthDayRaw is int ? monthDayRaw : int.tryParse('$monthDayRaw'),
    );
  }
}
