import '../models/account.dart';
import '../models/account_template.dart';

/// 预定义的账户模板库
class AccountTemplates {
  static const List<AccountTemplate> all = [
    // 常用账户（推荐）
    ...commonAccounts,
    // 银行储蓄卡
    ...bankSavingCards,
    // 虚拟账户
    ...virtualAccounts,
    // 信用卡
    ...creditCards,
    // 投资账户
    ...investmentAccounts,
  ];

  /// 常用账户（首次推荐）
  static const List<AccountTemplate> commonAccounts = [
    AccountTemplate(
      id: 'cash',
      name: '现金',
      kind: AccountKind.asset,
      subtype: AccountSubtype.cash,
      icon: 'wallet',
      category: '常用账户',
      description: '钱包/备用金等',
    ),
    AccountTemplate(
      id: 'alipay',
      name: '支付宝',
      kind: AccountKind.asset,
      subtype: AccountSubtype.virtual,
      icon: 'alipay',
      brandColor: 0xFF1677FF, // 支付宝蓝
      category: '常用账户',
      description: '支付宝余额',
      defaultName: '支付宝',
    ),
    AccountTemplate(
      id: 'wechat',
      name: '微信',
      kind: AccountKind.asset,
      subtype: AccountSubtype.virtual,
      icon: 'wechat',
      brandColor: 0xFF07C160, // 微信绿
      category: '常用账户',
      description: '微信零钱',
      defaultName: '微信',
    ),
  ];

  /// 银行储蓄卡模板
  static const List<AccountTemplate> bankSavingCards = [
    AccountTemplate(
      id: 'icbc',
      name: '工商银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'icbc',
      brandColor: 0xFFC8102E, // 工行红
      category: '银行',
      description: '工商银行储蓄卡',
      defaultName: '工商银行',
    ),
    AccountTemplate(
      id: 'ccb',
      name: '建设银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'ccb',
      brandColor: 0xFF003E7E, // 建行蓝
      category: '银行',
      description: '建设银行储蓄卡',
      defaultName: '建设银行',
    ),
    AccountTemplate(
      id: 'abc',
      name: '农业银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'abc',
      brandColor: 0xFF009639, // 农行绿
      category: '银行',
      description: '农业银行储蓄卡',
      defaultName: '农业银行',
    ),
    AccountTemplate(
      id: 'boc',
      name: '中国银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'boc',
      brandColor: 0xFFC8102E, // 中行红
      category: '银行',
      description: '中国银行储蓄卡',
      defaultName: '中国银行',
    ),
    AccountTemplate(
      id: 'cmb',
      name: '招商银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'cmb',
      brandColor: 0xFFC8102E, // 招行红
      category: '银行',
      description: '招商银行储蓄卡',
      defaultName: '招商银行',
    ),
    AccountTemplate(
      id: 'bocom',
      name: '交通银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'bocom',
      brandColor: 0xFF003E7E, // 交行蓝
      category: '银行',
      description: '交通银行储蓄卡',
      defaultName: '交通银行',
    ),
    AccountTemplate(
      id: 'citic',
      name: '中信银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'citic',
      brandColor: 0xFFC8102E, // 中信红
      category: '银行',
      description: '中信银行储蓄卡',
      defaultName: '中信银行',
    ),
    AccountTemplate(
      id: 'spdb',
      name: '浦发银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'spdb',
      brandColor: 0xFF003E7E, // 浦发蓝
      category: '银行',
      description: '浦发银行储蓄卡',
      defaultName: '浦发银行',
    ),
    AccountTemplate(
      id: 'ceb',
      name: '光大银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'ceb',
      brandColor: 0xFF6B1E75, // 光大紫
      category: '银行',
      description: '光大银行储蓄卡',
      defaultName: '光大银行',
    ),
    AccountTemplate(
      id: 'cgb',
      name: '广发银行',
      kind: AccountKind.asset,
      subtype: AccountSubtype.savingCard,
      icon: 'cgb',
      brandColor: 0xFFC8102E, // 广发红
      category: '银行',
      description: '广发银行储蓄卡',
      defaultName: '广发银行',
    ),
  ];

  /// 虚拟账户模板
  static const List<AccountTemplate> virtualAccounts = [
    AccountTemplate(
      id: 'alipay_virtual',
      name: '支付宝',
      kind: AccountKind.asset,
      subtype: AccountSubtype.virtual,
      icon: 'alipay',
      brandColor: 0xFF1677FF,
      category: '虚拟账户',
      description: '支付宝余额',
      defaultName: '支付宝',
    ),
    AccountTemplate(
      id: 'wechat_virtual',
      name: '微信',
      kind: AccountKind.asset,
      subtype: AccountSubtype.virtual,
      icon: 'wechat',
      brandColor: 0xFF07C160,
      category: '虚拟账户',
      description: '微信零钱',
      defaultName: '微信',
    ),
    AccountTemplate(
      id: 'other_virtual',
      name: '其他虚拟账户',
      kind: AccountKind.asset,
      subtype: AccountSubtype.virtual,
      icon: 'qr_code',
      category: '虚拟账户',
      description: '其他虚拟支付平台',
    ),
  ];

  /// 信用卡模板
  static const List<AccountTemplate> creditCards = [
    AccountTemplate(
      id: 'icbc_credit',
      name: '工商银行信用卡',
      kind: AccountKind.liability,
      subtype: AccountSubtype.creditCard,
      icon: 'icbc',
      brandColor: 0xFFC8102E,
      category: '信用卡',
      description: '工商银行信用卡',
      defaultName: '工商银行信用卡',
      extraFields: [
        TemplateField(
          key: 'creditLimit',
          label: '信用额度',
          type: FieldType.number,
          hint: '请输入信用额度',
          required: false,
        ),
        TemplateField(
          key: 'billingDay',
          label: '账单日',
          type: FieldType.number,
          hint: '每月几号出账单（1-31）',
          required: false,
        ),
        TemplateField(
          key: 'dueDay',
          label: '还款日',
          type: FieldType.number,
          hint: '每月几号还款（1-31）',
          required: false,
        ),
      ],
    ),
    AccountTemplate(
      id: 'cmb_credit',
      name: '招商银行信用卡',
      kind: AccountKind.liability,
      subtype: AccountSubtype.creditCard,
      icon: 'cmb',
      brandColor: 0xFFC8102E,
      category: '信用卡',
      description: '招商银行信用卡',
      defaultName: '招商银行信用卡',
      extraFields: [
        TemplateField(
          key: 'creditLimit',
          label: '信用额度',
          type: FieldType.number,
          hint: '请输入信用额度',
          required: false,
        ),
        TemplateField(
          key: 'billingDay',
          label: '账单日',
          type: FieldType.number,
          hint: '每月几号出账单（1-31）',
          required: false,
        ),
        TemplateField(
          key: 'dueDay',
          label: '还款日',
          type: FieldType.number,
          hint: '每月几号还款（1-31）',
          required: false,
        ),
      ],
    ),
    AccountTemplate(
      id: 'huabei',
      name: '蚂蚁花呗',
      kind: AccountKind.liability,
      subtype: AccountSubtype.creditCard,
      icon: 'huabei',
      brandColor: 0xFF1677FF,
      category: '信用卡',
      description: '蚂蚁花呗',
      defaultName: '蚂蚁花呗',
      extraFields: [
        TemplateField(
          key: 'creditLimit',
          label: '花呗额度',
          type: FieldType.number,
          hint: '请输入花呗额度',
          required: false,
        ),
      ],
    ),
    AccountTemplate(
      id: 'baitiao',
      name: '京东白条',
      kind: AccountKind.liability,
      subtype: AccountSubtype.creditCard,
      icon: 'baitiao',
      brandColor: 0xFFE1251B,
      category: '信用卡',
      description: '京东白条',
      defaultName: '京东白条',
      extraFields: [
        TemplateField(
          key: 'creditLimit',
          label: '白条额度',
          type: FieldType.number,
          hint: '请输入白条额度',
          required: false,
        ),
      ],
    ),
  ];

  /// 投资账户模板
  static const List<AccountTemplate> investmentAccounts = [
    AccountTemplate(
      id: 'stock',
      name: '股票账户',
      kind: AccountKind.asset,
      subtype: AccountSubtype.invest,
      icon: 'stock',
      category: '投资账户',
      description: '股票/证券账户',
      defaultName: '股票账户',
    ),
    AccountTemplate(
      id: 'fund',
      name: '基金账户',
      kind: AccountKind.asset,
      subtype: AccountSubtype.invest,
      icon: 'fund',
      category: '投资账户',
      description: '基金账户',
      defaultName: '基金账户',
    ),
  ];

  /// 根据子类型获取模板列表
  static List<AccountTemplate> getBySubtype(AccountSubtype subtype) {
    return all.where((t) => t.subtype == subtype).toList();
  }

  /// 根据分类获取模板列表
  static List<AccountTemplate> getByCategory(String category) {
    return all.where((t) => t.category == category).toList();
  }

  /// 获取推荐模板（常用账户）
  static List<AccountTemplate> getRecommended() {
    return commonAccounts;
  }
}
