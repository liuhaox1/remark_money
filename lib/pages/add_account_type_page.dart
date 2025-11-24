import 'package:flutter/material.dart';

import '../models/account.dart';
import 'account_form_page.dart';

class AddAccountTypePage extends StatelessWidget {
  const AddAccountTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加账户'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            leading: Icon(option.icon, size: 28),
            title: Text(option.title),
            subtitle: Text(option.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push<AccountKind>(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountFormPage(
                    kind: option.kind,
                    subtype: option.subtype,
                  ),
                ),
              );
              if (result != null && context.mounted) {
                Navigator.pop(context, result);
              }
            },
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: options.length,
      ),
    );
  }
}

class _AccountTypeOption {
  const _AccountTypeOption({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.subtype,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final AccountKind kind;
  final AccountSubtype subtype;
  final IconData icon;
}

const List<_AccountTypeOption> _options = [
  _AccountTypeOption(
    title: '现金',
    subtitle: '钱包/备用金等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.cash,
    icon: Icons.savings_outlined,
  ),
  _AccountTypeOption(
    title: '储蓄卡',
    subtitle: '借记卡/储蓄卡',
    kind: AccountKind.asset,
    subtype: AccountSubtype.savingCard,
    icon: Icons.credit_card,
  ),
  _AccountTypeOption(
    title: '信用卡',
    subtitle: '信用卡/花呗/白条等',
    kind: AccountKind.liability,
    subtype: AccountSubtype.creditCard,
    icon: Icons.credit_card_rounded,
  ),
  _AccountTypeOption(
    title: '虚拟账户',
    subtitle: '支付宝/微信等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.virtual,
    icon: Icons.qr_code_2_outlined,
  ),
  _AccountTypeOption(
    title: '投资账户',
    subtitle: '股票/基金等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.invest,
    icon: Icons.show_chart,
  ),
  _AccountTypeOption(
    title: '负债账户',
    subtitle: '贷款/借入等',
    kind: AccountKind.liability,
    subtype: AccountSubtype.loan,
    icon: Icons.trending_down,
  ),
  _AccountTypeOption(
    title: '债权账户',
    subtitle: '应收/借出',
    kind: AccountKind.lend,
    subtype: AccountSubtype.receivable,
    icon: Icons.swap_horiz_outlined,
  ),
  _AccountTypeOption(
    title: '自定义资产',
    subtitle: '其它资产账户',
    kind: AccountKind.asset,
    subtype: AccountSubtype.customAsset,
    icon: Icons.category_outlined,
  ),
];
