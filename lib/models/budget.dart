import 'dart:convert';

class Budget {
  final Map<String, BudgetEntry> entries;

  const Budget({
    required this.entries,
  });

  factory Budget.empty() => const Budget(entries: {});

  BudgetEntry entryFor(String bookId) {
    return entries[bookId] ??
        const BudgetEntry(
          total: 0,
          categoryBudgets: {},
          periodStartDay: 1,
        );
  }

  Budget copyWith({
    Map<String, BudgetEntry>? entries,
  }) {
    return Budget(
      entries: entries ?? this.entries,
    );
  }

  Budget replaceEntry(String bookId, BudgetEntry entry) {
    final next = Map<String, BudgetEntry>.from(entries);
    next[bookId] = entry;
    return Budget(entries: next);
  }

  Map<String, dynamic> toMap() {
    return entries.map(
      (key, value) => MapEntry(key, value.toMap()),
    );
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    // 兼容旧版本只存 total/categoryBudgets 的结构
    if (map.containsKey('total') || map.containsKey('categoryBudgets')) {
      return Budget(entries: {
        'default-book': BudgetEntry(
          total: (map['total'] ?? 0).toDouble(),
          categoryBudgets: Map<String, double>.from(
            (map['categoryBudgets'] ?? {}),
          ),
          periodStartDay: 1,
        ),
      });
    }

    final parsed = <String, BudgetEntry>{};
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsed[key] = BudgetEntry.fromMap(value);
      } else if (value is Map) {
        parsed[key] = BudgetEntry.fromMap(Map<String, dynamic>.from(value));
      }
    });
    return Budget(entries: parsed);
  }

  String toJson() => json.encode(toMap());

  factory Budget.fromJson(String source) =>
      Budget.fromMap(json.decode(source) as Map<String, dynamic>);
}

class BudgetEntry {
  final double total;
  final Map<String, double> categoryBudgets;

  /// ??????1-28????? 1 ???
  final int periodStartDay;

  /// ????????????
  final double annualTotal;

  /// 年度分类预算（与月度分类预算分开存储）
  final Map<String, double> annualCategoryBudgets;

  const BudgetEntry({
    required this.total,
    required this.categoryBudgets,
    this.periodStartDay = 1,
    this.annualTotal = 0,
    this.annualCategoryBudgets = const {},
  });

  BudgetEntry copyWith({
    double? total,
    Map<String, double>? categoryBudgets,
    int? periodStartDay,
    double? annualTotal,
    Map<String, double>? annualCategoryBudgets,
  }) {
    return BudgetEntry(
      total: total ?? this.total,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      periodStartDay: periodStartDay ?? this.periodStartDay,
      annualTotal: annualTotal ?? this.annualTotal,
      annualCategoryBudgets:
          annualCategoryBudgets ?? this.annualCategoryBudgets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'categoryBudgets': categoryBudgets,
      'periodStartDay': periodStartDay,
      'annualTotal': annualTotal,
      'annualCategoryBudgets': annualCategoryBudgets,
    };
  }

  factory BudgetEntry.fromMap(Map<String, dynamic> map) {
    return BudgetEntry(
      total: (map['total'] ?? 0).toDouble(),
      categoryBudgets: Map<String, double>.from(
        (map['categoryBudgets'] ?? {}),
      ),
      periodStartDay: (map['periodStartDay'] as int?) ?? 1,
      annualTotal: (map['annualTotal'] ?? 0).toDouble(),
      annualCategoryBudgets: Map<String, double>.from(
        (map['annualCategoryBudgets'] ?? {}),
      ),
    );
  }
}
