import 'dart:convert';

class Budget {
  final double total; // 总预算，可选
  final Map<String, double> categoryBudgets; // 按分类的预算

  Budget({
    required this.total,
    required this.categoryBudgets,
  });

  Budget copyWith({
    double? total,
    Map<String, double>? categoryBudgets,
  }) {
    return Budget(
      total: total ?? this.total,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'categoryBudgets': categoryBudgets,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      total: (map['total'] ?? 0).toDouble(),
      categoryBudgets: Map<String, double>.from(
        (map['categoryBudgets'] ?? {}),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory Budget.fromJson(String source) =>
      Budget.fromMap(json.decode(source));
}
