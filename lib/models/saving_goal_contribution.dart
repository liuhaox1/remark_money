import 'dart:convert';

class SavingGoalContribution {
  const SavingGoalContribution({
    required this.id,
    required this.goalId,
    required this.transactionId,
    required this.amount,
    required this.date,
  });

  final String id;
  final String goalId;
  final String transactionId;
  final double amount;
  final DateTime date;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'transactionId': transactionId,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory SavingGoalContribution.fromMap(Map<String, dynamic> map) {
    return SavingGoalContribution(
      id: map['id'] as String,
      goalId: map['goalId'] as String,
      transactionId: map['transactionId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavingGoalContribution.fromJson(String source) =>
      SavingGoalContribution.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );
}
