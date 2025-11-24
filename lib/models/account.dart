import 'dart:convert';

enum AccountType {
  cash,
  bankCard,
  eWallet,
  investment,
  loan,
  lend,
  other,
}

/// 账户的主类型，用于计算净资产和分组展示。
enum AccountKind {
  asset,
  liability,
  lend,
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.includeInTotal,
    required this.kind,
    this.currency = 'CNY',
    this.sortOrder = 0,
    this.initialBalance = 0,
    this.currentBalance = 0,
    this.counterparty,
    this.interestRate,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String icon;
  final bool includeInTotal;
  final AccountKind kind;
  final String currency;
  final int sortOrder;
  final double initialBalance;
  final double currentBalance;
  final String? counterparty;
  final double? interestRate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get balance => currentBalance;

  bool get isDebt => kind == AccountKind.liability;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? icon,
    bool? includeInTotal,
    String? currency,
    int? sortOrder,
    double? initialBalance,
    double? currentBalance,
    AccountKind? kind,
    String? counterparty,
    double? interestRate,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currency: currency ?? this.currency,
      sortOrder: sortOrder ?? this.sortOrder,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      kind: kind ?? this.kind,
      counterparty: counterparty ?? this.counterparty,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'icon': icon,
      'includeInTotal': includeInTotal,
      'currency': currency,
      'sortOrder': sortOrder,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'kind': kind.name,
      'counterparty': counterparty,
      'interestRate': interestRate,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      // legacy fields
      'balance': currentBalance,
      'isDebt': isDebt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    final parsedKind = () {
      final rawKind = map['kind'] as String?;
      if (rawKind != null) {
        return AccountKind.values.firstWhere(
          (k) => k.name == rawKind,
          orElse: () => AccountKind.asset,
        );
      }
      final legacyIsDebt = map['isDebt'] as bool? ?? false;
      return legacyIsDebt ? AccountKind.liability : AccountKind.asset;
    }();

    final parsedBalance = (map['currentBalance'] as num?)?.toDouble() ??
        (map['balance'] as num?)?.toDouble() ??
        0;

    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AccountType.cash,
      ),
      icon: map['icon'] as String? ?? 'wallet',
      includeInTotal: map['includeInTotal'] as bool? ?? true,
      currency: map['currency'] as String? ?? 'CNY',
      sortOrder: map['sortOrder'] as int? ?? 0,
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ??
          (map['balance'] as num?)?.toDouble() ??
          0,
      currentBalance: parsedBalance,
      kind: parsedKind,
      counterparty: map['counterparty'] as String?,
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      createdAt:
          map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Account.fromJson(String source) =>
      Account.fromMap(json.decode(source) as Map<String, dynamic>);
}

