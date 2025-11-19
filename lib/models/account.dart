import 'dart:convert';

enum AccountType {
  cash,
  bankCard,
  eWallet,
  investment,
  loan,
  other,
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.balance,
    required this.isDebt,
    required this.includeInTotal,
    this.currency = 'CNY',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final AccountType type;
  final String icon;
  final double balance;
  final bool isDebt;
  final bool includeInTotal;
  final String currency;
  final int sortOrder;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? icon,
    double? balance,
    bool? isDebt,
    bool? includeInTotal,
    String? currency,
    int? sortOrder,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      balance: balance ?? this.balance,
      isDebt: isDebt ?? this.isDebt,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currency: currency ?? this.currency,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'icon': icon,
      'balance': balance,
      'isDebt': isDebt,
      'includeInTotal': includeInTotal,
      'currency': currency,
      'sortOrder': sortOrder,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AccountType.cash,
      ),
      icon: map['icon'] as String? ?? 'wallet',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      isDebt: map['isDebt'] as bool? ?? false,
      includeInTotal: map['includeInTotal'] as bool? ?? true,
      currency: map['currency'] as String? ?? 'CNY',
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Account.fromJson(String source) =>
      Account.fromMap(json.decode(source) as Map<String, dynamic>);
}

