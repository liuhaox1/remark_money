import 'dart:convert';

class Record {
  final String id;

  /// 支出为正，收入为负，方便在累计统计时统一处理
  final double amount;
  final String remark;
  final DateTime date;
  final String categoryKey;
  final String bookId;

  const Record({
    required this.id,
    required this.amount,
    required this.remark,
    required this.date,
    required this.categoryKey,
    required this.bookId,
  });

  Record copyWith({
    String? id,
    double? amount,
    String? remark,
    DateTime? date,
    String? categoryKey,
    String? bookId,
  }) {
    return Record(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
      date: date ?? this.date,
      categoryKey: categoryKey ?? this.categoryKey,
      bookId: bookId ?? this.bookId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'remark': remark,
      'date': date.toIso8601String(),
      'categoryKey': categoryKey,
      'bookId': bookId,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      remark: map['remark'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryKey: map['categoryKey'] as String,
      bookId: map['bookId'] as String? ?? 'default-book',
    );
  }

  String toJson() => json.encode(toMap());

  factory Record.fromJson(String source) =>
      Record.fromMap(json.decode(source) as Map<String, dynamic>);

  bool get isExpense => amount >= 0;

  bool get isIncome => amount < 0;

  double get absAmount => amount.abs();

  double get incomeValue => isIncome ? -amount : 0;

  double get expenseValue => isExpense ? amount : 0;
}
