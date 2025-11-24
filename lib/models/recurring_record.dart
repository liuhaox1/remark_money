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
  final RecurringPeriodType periodType;
  final DateTime nextDate;

  const RecurringRecordPlan({
    required this.id,
    required this.bookId,
    required this.categoryKey,
    required this.accountId,
    required this.direction,
    required this.includeInStats,
    required this.amount,
    required this.remark,
    required this.periodType,
    required this.nextDate,
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
    RecurringPeriodType? periodType,
    DateTime? nextDate,
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
      periodType: periodType ?? this.periodType,
      nextDate: nextDate ?? this.nextDate,
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
      'periodType': periodType == RecurringPeriodType.weekly ? 'week' : 'month',
      'nextDate': nextDate.toIso8601String(),
    };
  }

  factory RecurringRecordPlan.fromMap(Map<String, dynamic> map) {
    final rawDirection = map['direction'] as String? ?? 'out';
    final direction = rawDirection == 'in'
        ? TransactionDirection.income
        : TransactionDirection.out;
    final rawPeriod = map['periodType'] as String? ?? 'month';
    final periodType =
        rawPeriod == 'week' ? RecurringPeriodType.weekly : RecurringPeriodType.monthly;
    return RecurringRecordPlan(
      id: map['id'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      categoryKey: map['categoryKey'] as String,
      accountId: map['accountId'] as String,
      direction: direction,
      includeInStats: map['includeInStats'] as bool? ?? true,
      amount: (map['amount'] as num).toDouble(),
      remark: map['remark'] as String? ?? '',
      periodType: periodType,
      nextDate: DateTime.parse(map['nextDate'] as String),
    );
  }
}

