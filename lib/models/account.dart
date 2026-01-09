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

enum AccountKind {
  asset,
  liability,
  lend,
}

enum AccountSubtype {
  cash('cash'),
  savingCard('saving_card'),
  creditCard('credit_card'),
  virtual('virtual'),
  invest('invest'),
  loan('loan'),
  receivable('receivable'),
  customAsset('custom_asset');

  const AccountSubtype(this.code);
  final String code;

  static AccountSubtype fromCode(String? code) {
    return AccountSubtype.values.firstWhere(
      (value) => value.code == code,
      orElse: () => AccountSubtype.cash,
    );
  }
}

class Account {
  const Account({
    required this.id,
    this.bookId = 'default-book',
    this.serverId,
    this.syncVersion,
    required this.name,
    required this.kind,
    this.subtype = 'cash',
    this.type = AccountType.cash,
    this.icon = 'wallet',
    this.includeInTotal = true,
    this.includeInOverview = true,
    this.currency = 'CNY',
    this.sortOrder = 0,
    this.initialBalance = 0,
    this.currentBalance = 0,
    this.counterparty,
    this.interestRate,
    this.dueDate,
    this.note,
    this.brandKey,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookId;
  final int? serverId; // 服务器自增ID
  final int? syncVersion; // server monotonic sync version
  final String name;
  final AccountKind kind;
  final String subtype;
  final AccountType type;
  final String icon;
  final bool includeInTotal;
  final bool includeInOverview;
  final String currency;
  final int sortOrder;
  final double initialBalance;
  final double currentBalance;
  final String? counterparty;
  final double? interestRate;
  final DateTime? dueDate;
  final String? note;
  final String? brandKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get balance => currentBalance;

  bool get isDebt => kind == AccountKind.liability;

  Account copyWith({
    String? id,
    String? bookId,
    int? serverId,
    int? syncVersion,
    String? name,
    AccountKind? kind,
    String? subtype,
    AccountType? type,
    String? icon,
    bool? includeInTotal,
    bool? includeInOverview,
    String? currency,
    int? sortOrder,
    double? initialBalance,
    double? currentBalance,
    String? counterparty,
    double? interestRate,
    DateTime? dueDate,
    String? note,
    String? brandKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      serverId: serverId ?? this.serverId,
      syncVersion: syncVersion ?? this.syncVersion,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      subtype: subtype ?? this.subtype,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      includeInOverview: includeInOverview ?? this.includeInOverview,
      currency: currency ?? this.currency,
      sortOrder: sortOrder ?? this.sortOrder,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      counterparty: counterparty ?? this.counterparty,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      brandKey: brandKey ?? this.brandKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // 客户端临时ID（首次上传时使用）
      'bookId': bookId,
      'serverId': serverId, // 服务器ID（如果已同步）
      'syncVersion': syncVersion,
      'name': name,
      'category': kind.name,
      'kind': kind.name,
      'subtype': subtype,
      'type': type.name,
      'icon': icon,
      'includeInTotal': includeInTotal,
      'includeInOverview': includeInOverview,
      'currency': currency,
      'sortOrder': sortOrder,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'counterparty': counterparty,
      'interestRate': interestRate,
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'brandKey': brandKey,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      // legacy fields
      'balance': currentBalance,
      'isDebt': isDebt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    bool _asBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s.isEmpty) return false;
        if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
        if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
      }
      return false;
    }

    final parsedKind = () {
      final rawKind = map['category'] as String? ?? map['kind'] as String?;
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

    final rawType = map['type'] as String?;
    // 服务器返回时，id是serverId（int），需要生成临时ID
    // 客户端上传时，id是临时ID（String），serverId是已同步的服务器ID
    final serverId = map['id'] is int ? map['id'] as int? : map['serverId'] as int?;
    final clientId = map['id'] is String ? map['id'] as String? : null;
    final rawBookId = (map['bookId'] ?? map['book_id'])?.toString().trim();
    final bookId = (rawBookId != null && rawBookId.isNotEmpty) ? rawBookId : 'default-book';
    final syncVersionRaw = map['syncVersion'] ?? map['sync_version'];
    final syncVersion = syncVersionRaw is num
        ? syncVersionRaw.toInt()
        : (syncVersionRaw is String ? int.tryParse(syncVersionRaw) : null);
    return Account(
      id: clientId ?? (serverId != null ? 'server_$serverId' : _generateTempId()),
      bookId: bookId,
      serverId: serverId,
      syncVersion: syncVersion,
      name: map['name'] as String,
      kind: parsedKind,
      subtype: map['subtype'] as String? ?? _mapLegacySubtype(rawType),
      type: AccountType.values.firstWhere(
        (t) => t.name == rawType,
        orElse: () => AccountType.cash,
      ),
      icon: map['icon'] as String? ?? 'wallet',
      includeInTotal: (map.containsKey('includeInTotal') || map.containsKey('include_in_total'))
          ? _asBool(map['includeInTotal'] ?? map['include_in_total'])
          : ((map.containsKey('includeInOverview') || map.containsKey('include_in_overview'))
              ? _asBool(map['includeInOverview'] ?? map['include_in_overview'])
              : true),
      includeInOverview: (map.containsKey('includeInOverview') || map.containsKey('include_in_overview'))
          ? _asBool(map['includeInOverview'] ?? map['include_in_overview'])
          : ((map.containsKey('includeInTotal') || map.containsKey('include_in_total'))
              ? _asBool(map['includeInTotal'] ?? map['include_in_total'])
              : true),
      currency: map['currency'] as String? ?? 'CNY',
      sortOrder: map['sortOrder'] as int? ?? 0,
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ??
          (map['balance'] as num?)?.toDouble() ??
          0,
      currentBalance: parsedBalance,
      counterparty: map['counterparty'] as String?,
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      note: map['note'] as String?,
      brandKey: map['brandKey'] as String?,
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

String _generateTempId() {
  return DateTime.now().millisecondsSinceEpoch.toString() + 
      (100000 + (DateTime.now().microsecond % 900000)).toString();
}

String _mapLegacySubtype(String? rawType) {
  switch (rawType) {
    case 'bankCard':
      return AccountSubtype.savingCard.code;
    case 'eWallet':
      return AccountSubtype.virtual.code;
    case 'investment':
      return AccountSubtype.invest.code;
    case 'loan':
      return AccountSubtype.loan.code;
    case 'lend':
      return AccountSubtype.receivable.code;
    case 'other':
      return AccountSubtype.customAsset.code;
    case 'cash':
    default:
      return AccountSubtype.cash.code;
  }
}
