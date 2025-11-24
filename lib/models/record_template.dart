import '../models/record.dart';

/// A lightweight template for quickly creating records.
class RecordTemplate {
  final String id;
  final String categoryKey;
  final String accountId;
  final TransactionDirection direction;
  final bool includeInStats;
  final String remark;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const RecordTemplate({
    required this.id,
    required this.categoryKey,
    required this.accountId,
    required this.direction,
    required this.includeInStats,
    required this.remark,
    required this.createdAt,
    this.lastUsedAt,
  });

  RecordTemplate copyWith({
    String? id,
    String? categoryKey,
    String? accountId,
    TransactionDirection? direction,
    bool? includeInStats,
    String? remark,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return RecordTemplate(
      id: id ?? this.id,
      categoryKey: categoryKey ?? this.categoryKey,
      accountId: accountId ?? this.accountId,
      direction: direction ?? this.direction,
      includeInStats: includeInStats ?? this.includeInStats,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryKey': categoryKey,
      'accountId': accountId,
      'direction': direction == TransactionDirection.income ? 'in' : 'out',
      'includeInStats': includeInStats,
      'remark': remark,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory RecordTemplate.fromMap(Map<String, dynamic> map) {
    final rawDirection = map['direction'] as String? ?? 'out';
    final direction = rawDirection == 'in'
        ? TransactionDirection.income
        : TransactionDirection.out;
    return RecordTemplate(
      id: map['id'] as String,
      categoryKey: map['categoryKey'] as String,
      accountId: map['accountId'] as String,
      direction: direction,
      includeInStats: map['includeInStats'] as bool? ?? true,
      remark: map['remark'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.tryParse(map['lastUsedAt'] as String? ?? '')
          : null,
    );
  }
}

