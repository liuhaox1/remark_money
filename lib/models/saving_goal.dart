import 'dart:convert';

enum SavingGoalStatus { pending, active, completed, overdue }

class SavingGoal {
  const SavingGoal({
    required this.id,
    required this.name,
    required this.accountId,
    required this.targetAmount,
    required this.startDate,
    this.endDate,
    this.status = SavingGoalStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? startDate,
        updatedAt = updatedAt ?? createdAt ?? startDate;

  final String id;
  final String name;
  final String accountId;
  final double targetAmount;
  final DateTime startDate;
  final DateTime? endDate;
  final SavingGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavingGoal copyWith({
    String? id,
    String? name,
    String? accountId,
    double? targetAmount,
    DateTime? startDate,
    DateTime? endDate,
    SavingGoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountId': accountId,
      'targetAmount': targetAmount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      accountId: map['accountId'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate:
          map['endDate'] != null ? DateTime.tryParse(map['endDate']) : null,
      status: SavingGoalStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SavingGoalStatus.active,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavingGoal.fromJson(String source) =>
      SavingGoal.fromMap(json.decode(source) as Map<String, dynamic>);
}
