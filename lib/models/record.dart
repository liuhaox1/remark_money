import 'dart:convert';

enum TransactionDirection { out, income }

class Record {
  final String id;
  /// 服务器自增ID（同步成功后由后端下发），本地新建时为空
  final int? serverId;
  final int? serverVersion;
  final int? createdByUserId;
  final int? updatedByUserId;

  /// 金额为绝对值，方向由 [direction] 控制。
  final double amount;
  final String remark;
  final DateTime date;
  final String categoryKey;
  final String bookId;
  final String accountId;
  final TransactionDirection direction;
  final bool includeInStats;
  final String? pairId;

  const Record({
    required this.id,
    this.serverId,
    this.serverVersion,
    this.createdByUserId,
    this.updatedByUserId,
    required this.amount,
    required this.remark,
    required this.date,
    required this.categoryKey,
    required this.bookId,
    required this.accountId,
    required this.direction,
    this.includeInStats = true,
    this.pairId,
  });

  Record copyWith({
    String? id,
    int? serverId,
    int? serverVersion,
    int? createdByUserId,
    int? updatedByUserId,
    double? amount,
    String? remark,
    DateTime? date,
    String? categoryKey,
    String? bookId,
    String? accountId,
    TransactionDirection? direction,
    bool? includeInStats,
    String? pairId,
  }) {
    return Record(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      serverVersion: serverVersion ?? this.serverVersion,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
      date: date ?? this.date,
      categoryKey: categoryKey ?? this.categoryKey,
      bookId: bookId ?? this.bookId,
      accountId: accountId ?? this.accountId,
      direction: direction ?? this.direction,
      includeInStats: includeInStats ?? this.includeInStats,
      pairId: pairId ?? this.pairId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serverId': serverId,
      'serverVersion': serverVersion,
      'createdByUserId': createdByUserId,
      'updatedByUserId': updatedByUserId,
      'amount': amount,
      'remark': remark,
      'date': date.toIso8601String(),
      'categoryKey': categoryKey,
      'bookId': bookId,
      'accountId': accountId,
      'direction': direction == TransactionDirection.income ? 'in' : 'out',
      'includeInStats': includeInStats,
      'pairId': pairId,
      // legacy sign field for兼容
      'signedAmount': signedAmount,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    final rawDirection = map['direction'] as String?;
    TransactionDirection direction;
    double rawAmount = (map['amount'] as num).toDouble();

    if (rawDirection != null) {
      if (rawDirection == 'in') {
        direction = TransactionDirection.income;
      } else {
        direction = TransactionDirection.values.firstWhere(
          (d) => d.name == rawDirection,
          orElse: () => TransactionDirection.out,
        );
      }
    } else {
      // 兼容旧数据：正为支出，负为收入
      direction = rawAmount < 0
          ? TransactionDirection.income
          : TransactionDirection.out;
      rawAmount = rawAmount.abs();
    }

    return Record(
      id: map['id'] as String,
      serverId: map['serverId'] as int?,
      serverVersion: map['serverVersion'] as int?,
      createdByUserId: (map['createdByUserId'] as num?)?.toInt(),
      updatedByUserId: (map['updatedByUserId'] as num?)?.toInt(),
      amount: rawAmount,
      remark: map['remark'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryKey: map['categoryKey'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
      accountId: map['accountId'] as String? ?? '',
      direction: direction,
      includeInStats: map['includeInStats'] as bool? ?? true,
      pairId: map['pairId'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Record.fromJson(String source) =>
      Record.fromMap(json.decode(source) as Map<String, dynamic>);

  bool get isExpense => direction == TransactionDirection.out;

  bool get isIncome => direction == TransactionDirection.income;

  double get absAmount => amount.abs();

  double get incomeValue => isIncome ? absAmount : 0;

  double get expenseValue => isExpense ? absAmount : 0;

  /// 保持兼容的带符号金额，支出为正，收入为负。
  double get signedAmount => isExpense ? absAmount : -absAmount;
}
