import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/bank_brands.dart';
import '../models/account.dart';
import 'account_form_page.dart';

Widget _buildSvgLeading(String assetPath, Color backgroundColor) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
    ),
    padding: const EdgeInsets.all(10),
    child: SvgPicture.asset(
      assetPath,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    ),
  );
}

Widget _buildIconLeading(IconData icon, Color color) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 24),
  );
}

class AddAccountTypePage extends StatelessWidget {
  const AddAccountTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const options = _options;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('添加账户'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          final option = options[index];
          return Container(
            color: cs.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              leading: option.svgAsset != null
                  ? _buildSvgLeading(option.svgAsset!, option.color)
                  : _buildIconLeading(option.icon, option.color),
              title: Text(
                option.title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  option.subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            trailing: Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
            onTap: () async {
                if (option.subtype == AccountSubtype.savingCard) {
                  final result = await Navigator.push<AccountKind>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BankSelectionPage(option: option),
                    ),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(context, result);
                  }
                  return;
                }
                if (option.subtype == AccountSubtype.creditCard) {
                  final result = await Navigator.push<AccountKind>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreditCardSelectionPage(option: option),
                    ),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(context, result);
                  }
                  return;
                }
                if (option.subtype == AccountSubtype.virtual) {
                  final result = await Navigator.push<AccountKind>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VirtualAccountSelectionPage(option: option),
                    ),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(context, result);
                  }
                  return;
                }
                if (option.subtype == AccountSubtype.invest) {
                  final result = await Navigator.push<AccountKind>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvestAccountSelectionPage(option: option),
                    ),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(context, result);
                  }
                  return;
                }
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
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemCount: options.length,
      ),
    );
  }
}

class AccountTypeOption {
  const AccountTypeOption({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.subtype,
    required this.icon,
    required this.color,
    this.svgAsset,
  });

  final String title;
  final String subtitle;
  final AccountKind kind;
  final AccountSubtype subtype;
  final IconData icon;
  final Color color;
  final String? svgAsset;
}

const List<AccountTypeOption> _options = [
  AccountTypeOption(
    title: '现金',
    subtitle: '钱包/备用金等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.cash,
    icon: Icons.attach_money,
    color: Color(0xFF00C853),
  ),
  AccountTypeOption(
    title: '储蓄卡',
    subtitle: '借记卡/储蓄卡',
    kind: AccountKind.asset,
    subtype: AccountSubtype.savingCard,
    icon: Icons.credit_card_rounded,
    color: Color(0xFFFFA000),
  ),
  AccountTypeOption(
    title: '信用卡',
    subtitle: '信用卡/花呗/白条等',
    kind: AccountKind.liability,
    subtype: AccountSubtype.creditCard,
    icon: Icons.credit_card_rounded,
    color: Color(0xFFFFC400),
  ),
  AccountTypeOption(
    title: '虚拟账户',
    subtitle: '支付宝/微信等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.virtual,
    icon: Icons.qr_code_2_outlined,
    color: Color(0xFFFFCA28),
  ),
  AccountTypeOption(
    title: '投资账户',
    subtitle: '股票/基金等',
    kind: AccountKind.asset,
    subtype: AccountSubtype.invest,
    icon: Icons.trending_up,
    color: Color(0xFFFFB300),
  ),
  AccountTypeOption(
    title: '负债',
    subtitle: '贷款/借入等',
    kind: AccountKind.liability,
    subtype: AccountSubtype.loan,
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFFF7043),
  ),
  AccountTypeOption(
    title: '自定义资产',
    subtitle: '其它资产账户',
    kind: AccountKind.asset,
    subtype: AccountSubtype.customAsset,
    icon: Icons.view_in_ar_outlined,
    color: Color(0xFF7E57C2),
  ),
];

class BankSelectionPage extends StatelessWidget {
  const BankSelectionPage({super.key, required this.option});

  final AccountTypeOption option;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('选择银行'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kSupportedBankBrands.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
        itemBuilder: (context, index) {
          final brand = kSupportedBankBrands[index];
          return Container(
            color: cs.surface,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: brand.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  brand.shortName,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: brand.color,
                  ),
                ),
              ),
              title: Text(
                brand.displayName,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
              onTap: () async {
                final result = await Navigator.push<AccountKind>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountFormPage(
                      kind: option.kind,
                      subtype: option.subtype,
                      initialBrandKey: brand.key,
                      presetName: brand.displayName,
                      customTitle: null,
                      showAdvancedSettings: false,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class CreditCardSelectionPage extends StatelessWidget {
  const CreditCardSelectionPage({super.key, required this.option});

  final AccountTypeOption option;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('选择信用卡'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kSupportedCreditCardBrands.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
        itemBuilder: (context, index) {
          final brand = kSupportedCreditCardBrands[index];
          return Container(
            color: cs.surface,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: brand.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  brand.shortName,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: brand.color,
                  ),
                ),
              ),
              title: Text(
                brand.displayName,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
              onTap: () async {
                final result = await Navigator.push<AccountKind>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountFormPage(
                      kind: option.kind,
                      subtype: option.subtype,
                      initialBrandKey: brand.key,
                      presetName: brand.displayName,
                      customTitle: null,
                      showAdvancedSettings: false,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _VirtualAccountOption {
  const _VirtualAccountOption({
    required this.title,
    required this.subtitle,
    required this.presetName,
    required this.color,
    required this.icon,
    this.svgAsset,
    this.showAdvancedSettings = false,
  });

  final String title;
  final String subtitle;
  final String presetName;
  final Color color;
  final IconData icon;
  final String? svgAsset;
  final bool showAdvancedSettings;
}

const List<_VirtualAccountOption> _virtualOptions = [
  _VirtualAccountOption(
    title: '支付宝',
    subtitle: '支付宝余额/余额宝',
    presetName: '支付宝',
    color: Color(0xFF0AA1E4),
    icon: Icons.currency_yuan,
    svgAsset: 'assets/brands/alipay.svg',
  ),
  _VirtualAccountOption(
    title: '微信',
    subtitle: '微信零钱/零钱通',
    presetName: '微信',
    color: Color(0xFF22B573),
    icon: Icons.wechat_rounded,
    svgAsset: 'assets/brands/wechat.svg',
  ),
  _VirtualAccountOption(
    title: '其他虚拟账户',
    subtitle: '京东、云闪付等',
    presetName: '虚拟账户',
    color: Color(0xFFFFCA28),
    icon: Icons.account_balance_wallet_outlined,
    showAdvancedSettings: true,
  ),
];

class VirtualAccountSelectionPage extends StatelessWidget {
  const VirtualAccountSelectionPage({super.key, required this.option});

  final AccountTypeOption option;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('添加虚拟账户'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _virtualOptions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
        itemBuilder: (context, index) {
          final item = _virtualOptions[index];
          return Container(
            color: cs.surface,
            child: ListTile(
              leading: item.svgAsset != null
                  ? _buildSvgLeading(item.svgAsset!, item.color)
                  : _buildIconLeading(item.icon, item.color),
              title: Text(
                item.title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
              onTap: () async {
                final result = await Navigator.push<AccountKind>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountFormPage(
                      kind: option.kind,
                      subtype: option.subtype,
                      presetName: item.presetName,
                      customTitle: null,
                      showAdvancedSettings: item.showAdvancedSettings,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _InvestAccountOption {
  const _InvestAccountOption({
    required this.title,
    required this.subtitle,
    required this.presetName,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String presetName;
  final Color color;
  final IconData icon;
}

const List<_InvestAccountOption> _investOptions = [
  _InvestAccountOption(
    title: '股票',
    subtitle: '股票账户',
    presetName: '股票',
    color: Color(0xFFFFB300),
    icon: Icons.trending_up,
  ),
  _InvestAccountOption(
    title: '基金',
    subtitle: '基金账户',
    presetName: '基金',
    color: Color(0xFFFFC400),
    icon: Icons.account_balance,
  ),
  _InvestAccountOption(
    title: '其他',
    subtitle: '其他投资账户',
    presetName: '投资账户',
    color: Color(0xFFFFD54F),
    icon: Icons.account_balance_wallet_outlined,
  ),
];

class InvestAccountSelectionPage extends StatelessWidget {
  const InvestAccountSelectionPage({super.key, required this.option});

  final AccountTypeOption option;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('选择投资账户'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _investOptions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
        itemBuilder: (context, index) {
          final item = _investOptions[index];
          return Container(
            color: cs.surface,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              title: Text(
                item.title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
              onTap: () async {
                final result = await Navigator.push<AccountKind>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountFormPage(
                      kind: option.kind,
                      subtype: option.subtype,
                      presetName: item.presetName,
                      customTitle: item.presetName == '投资账户' ? '其他投资账户' : null,
                      showAdvancedSettings: false,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
