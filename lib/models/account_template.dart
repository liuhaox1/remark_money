import 'dart:convert';

import 'account.dart';

/// 账户模板：用于快速创建常用账户
class AccountTemplate {
  const AccountTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.subtype,
    required this.icon,
    this.brandColor,
    this.description,
    this.defaultName,
    this.category, // 用于分组，如"常用账户"、"银行"等
    this.extraFields = const [],
  });

  /// 模板唯一ID
  final String id;

  /// 模板显示名称
  final String name;

  /// 账户类型
  final AccountKind kind;

  /// 账户子类型
  final AccountSubtype subtype;

  /// 图标名称或IconData标识
  final String icon;

  /// 品牌色（可选）
  final int? brandColor;

  /// 描述
  final String? description;

  /// 默认账户名称（如果为空则使用name）
  final String? defaultName;

  /// 分类标签（用于分组展示）
  final String? category;

  /// 额外字段配置（如信用卡额度、账单日等）
  final List<TemplateField> extraFields;

  String get displayName => defaultName ?? name;

  Account toAccount({
    String? customName,
    double initialBalance = 0,
    Map<String, dynamic>? extraValues,
  }) {
    return Account(
      id: '',
      name: customName ?? displayName,
      kind: kind,
      subtype: subtype.code,
      type: _mapSubtypeToType(subtype),
      icon: icon,
      initialBalance: initialBalance,
      currentBalance: initialBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind.name,
      'subtype': subtype.code,
      'icon': icon,
      'brandColor': brandColor,
      'description': description,
      'defaultName': defaultName,
      'category': category,
      'extraFields': extraFields.map((f) => f.toMap()).toList(),
    };
  }

  factory AccountTemplate.fromMap(Map<String, dynamic> map) {
    return AccountTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      kind: AccountKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => AccountKind.asset,
      ),
      subtype: AccountSubtype.fromCode(map['subtype']),
      icon: map['icon'] as String,
      brandColor: map['brandColor'] as int?,
      description: map['description'] as String?,
      defaultName: map['defaultName'] as String?,
      category: map['category'] as String?,
      extraFields: (map['extraFields'] as List<dynamic>?)
              ?.map((e) => TemplateField.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String toJson() => json.encode(toMap());

  factory AccountTemplate.fromJson(String source) =>
      AccountTemplate.fromMap(json.decode(source) as Map<String, dynamic>);

  AccountType _mapSubtypeToType(AccountSubtype subtype) {
    switch (subtype) {
      case AccountSubtype.cash:
        return AccountType.cash;
      case AccountSubtype.savingCard:
        return AccountType.bankCard;
      case AccountSubtype.creditCard:
        return AccountType.loan;
      case AccountSubtype.virtual:
        return AccountType.eWallet;
      case AccountSubtype.invest:
        return AccountType.investment;
      case AccountSubtype.loan:
        return AccountType.loan;
      case AccountSubtype.receivable:
        return AccountType.lend;
      case AccountSubtype.customAsset:
        return AccountType.other;
    }
  }
}

/// 模板字段配置
class TemplateField {
  const TemplateField({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.required = false,
    this.defaultValue,
    this.validation,
  });

  final String key;
  final String label;
  final FieldType type;
  final String? hint;
  final bool required;
  final dynamic defaultValue;
  final String? validation; // 验证规则描述

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'type': type.name,
      'hint': hint,
      'required': required,
      'defaultValue': defaultValue,
      'validation': validation,
    };
  }

  factory TemplateField.fromMap(Map<String, dynamic> map) {
    return TemplateField(
      key: map['key'] as String,
      label: map['label'] as String,
      type: FieldType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => FieldType.text,
      ),
      hint: map['hint'] as String?,
      required: map['required'] as bool? ?? false,
      defaultValue: map['defaultValue'],
      validation: map['validation'] as String?,
    );
  }
}

enum FieldType {
  text,
  number,
  date,
  select,
}
