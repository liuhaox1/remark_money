import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/brand_logo_avatar.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';
import 'account_detail_page.dart';
import 'add_account_type_page.dart';
import 'add_record_page.dart';
import 'analysis_page.dart';
import 'home_page.dart';
import 'profile_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    const HomePage(),
    const AnalysisPage(),
    const AssetsPage(),
    const ProfilePage(),
  ];

  Future<void> _openQuickAddPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRecordPage()),
    );
  }

  void _handleDestination(int value) {
    if (value == 2) {
      _openQuickAddPage();
      return;
    }
    final mapped = value > 2 ? value - 1 : value;
    setState(() => _index = mapped);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.12),
        selectedIndex: _index >= 2 ? _index + 1 : _index,
        onDestinationSelected: _handleDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: AppStrings.navStats,
          ),
          NavigationDestination(
            icon: _RecordNavIcon(color: cs.primary),
            selectedIcon: _RecordNavIcon(color: cs.primary),
            label: AppStrings.navRecord,
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: AppStrings.navAssets,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AssetsPageBody();
  }
}

class _AssetsPageBody extends StatelessWidget {
  const _AssetsPageBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accountProvider = context.watch<AccountProvider>();

    final accounts = accountProvider.accounts;
    final totalAssets = accountProvider.totalAssets;
    final totalDebts = accountProvider.totalDebts;
    final netWorth = accountProvider.netWorth;
    final grouped = _groupAccounts(accounts);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: accounts.isEmpty
                ? _EmptyAccounts(
                    onAdd: () => _startAddAccountFlow(context),
                  )
                : Column(
                    children: [
                      _AssetSummaryCard(
                        totalAssets: totalAssets,
                        totalDebts: totalDebts,
                        netWorth: netWorth,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                        child: Text(
                                      '账户余额来自你的记账记录。如不准确，请进入账户详情页，点击"调整余额"进行修正。',
                          style: TextStyle(
                                        fontSize: 11,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.65),
                          ),
                        ),
                      ),
                                ],
                              ),
                            ),
                            if (_hasAnyBalanceIssue(accounts)) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.danger.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '检测到异常余额，请及时检查',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 快速操作栏
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _openTransferSheet(context, accounts),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '转账',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _startAddAccountFlow(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 18,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '添加账户',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            for (final group in grouped)
                              _AccountGroupPanel(
                                group: group,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AssetSummaryCard extends StatelessWidget {
  const _AssetSummaryCard({
    required this.totalAssets,
    required this.totalDebts,
    required this.netWorth,
  });

  final double totalAssets;
  final double totalDebts;
  final double netWorth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final netColor = AppColors.amount(netWorth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withOpacity(0.18),
              cs.surface,
            ],
          ),
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.netWorth,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatAmount(netWorth),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('资产', totalAssets, cs),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem('负债', totalDebts, cs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    }
    return value.toStringAsFixed(2);
  }

  Widget _buildStatItem(String label, double value, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.75),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatAmount(value),
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AccountGroupPanel extends StatelessWidget {
  const _AccountGroupPanel({
    required this.group,
  });

  final _AccountGroupData group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
                group.title,
            style: TextStyle(
              fontSize: 14,
                  fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.9),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (final account in group.accounts)
                _AccountTile(
                  account: account,
                  isLast: account == group.accounts.last,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isLast,
  });

  final Account account;
  final bool isLast;

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除账户"${account.name}"吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final accountProvider = context.read<AccountProvider>();
      await accountProvider.deleteAccount(account.id);

      if (context.mounted) {
        ErrorHandler.showSuccess(context, '账户已删除');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDebt = account.kind == AccountKind.liability;
    final hasIssue = _hasBalanceIssue(account);
    final amountColor = cs.onSurface;
    final icon = _iconForAccount(account);

    final tileContent = InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountDetailPage(accountId: account.id),
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                BrandLogoAvatar(
                  size: 38,
                  brandKey: account.brandKey,
                  icon: icon,
                  iconColor: cs.primary,
                  backgroundColor: cs.primary.withOpacity(0.08),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleForAccount(account),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text(
                  account.currentBalance.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor.withOpacity(0.9),
                  ),
                ),
                    if (hasIssue) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 10,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '异常',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 60,
              endIndent: 12,
              color: cs.outlineVariant.withOpacity(0.3),
              thickness: 0.5,
            ),
        ],
      ),
    );

    return Slidable(
      key: ValueKey(account.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _handleDelete(context),
            backgroundColor: AppColors.danger,
            foregroundColor: cs.onError,
            label: '删除',
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: tileContent,
    );
  }

  IconData _iconForAccount(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    switch (subtype) {
      case AccountSubtype.cash:
        return Icons.account_balance_wallet_outlined;
      case AccountSubtype.savingCard:
        return Icons.credit_card;
      case AccountSubtype.creditCard:
        return Icons.credit_score_outlined;
      case AccountSubtype.virtual:
        return Icons.qr_code_2_outlined;
      case AccountSubtype.invest:
        return Icons.savings_outlined;
      case AccountSubtype.loan:
        return Icons.trending_down;
      case AccountSubtype.receivable:
        return Icons.swap_horiz_outlined;
      case AccountSubtype.customAsset:
        return Icons.category_outlined;
    }
  }

  String _subtitleForAccount(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    switch (subtype) {
      case AccountSubtype.cash:
        return '现金';
      case AccountSubtype.savingCard:
        return '储蓄卡';
      case AccountSubtype.creditCard:
        return '信用卡 / 花呗';
      case AccountSubtype.virtual:
        return '虚拟账户';
      case AccountSubtype.invest:
        return '投资账户';
      case AccountSubtype.loan:
        return '贷款 / 借入';
      case AccountSubtype.receivable:
        return '应收 / 借出';
      case AccountSubtype.customAsset:
        return '自定义资产';
    }
  }

  bool _hasBalanceIssue(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    // 储蓄卡、现金等资产账户不应该有负余额
    if (account.kind == AccountKind.asset && 
        (subtype == AccountSubtype.savingCard || subtype == AccountSubtype.cash) &&
        account.currentBalance < 0) {
      return true;
    }
    return false;
  }
}

bool _hasAnyBalanceIssue(List<Account> accounts) {
  for (final account in accounts) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    if (account.kind == AccountKind.asset && 
        (subtype == AccountSubtype.savingCard || subtype == AccountSubtype.cash) &&
        account.currentBalance < 0) {
      return true;
    }
  }
  return false;
}

void _openTransferSheet(BuildContext context, List<Account> accounts) {
  final amountCtrl = TextEditingController();
  String? fromAccountId;
  String? toAccountId;

  // 过滤出资产账户（不包括负债账户）
  final assetAccounts = accounts.where((a) {
    return a.kind != AccountKind.liability;
  }).toList();

  if (assetAccounts.isEmpty) {
    ErrorHandler.showWarning(context, '至少需要两个资产账户才能进行转账');
    return;
  }

  // 默认选择第一个和第二个账户
  if (assetAccounts.length >= 2) {
    fromAccountId = assetAccounts[0].id;
    toAccountId = assetAccounts[1].id;
  } else {
    fromAccountId = assetAccounts[0].id;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '账户间转账',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                // 转出账户选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '转出账户',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final selectedId = await showAccountSelectBottomSheet(
                          context,
                          assetAccounts,
                          selectedAccountId: fromAccountId,
                          title: '选择转出账户',
                        );
                        if (selectedId != null) {
                          setState(() {
                            fromAccountId = selectedId;
                            // 如果转出账户和转入账户相同，自动选择另一个账户
                            if (selectedId == toAccountId && assetAccounts.length > 1) {
                              toAccountId = assetAccounts
                                  .firstWhere((a) => a.id != selectedId)
                                  .id;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fromAccountId != null
                                    ? assetAccounts.firstWhere((a) => a.id == fromAccountId).name
                                    : '请选择转出账户',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: fromAccountId != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 转入账户选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '转入账户',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final availableAccounts = assetAccounts
                            .where((a) => a.id != fromAccountId)
                            .toList();
                        if (availableAccounts.isEmpty) {
                          ErrorHandler.showWarning(context, '没有可选的转入账户');
                          return;
                        }
                        final selectedId = await showAccountSelectBottomSheet(
                          context,
                          availableAccounts,
                          selectedAccountId: toAccountId,
                          title: '选择转入账户',
                        );
                        if (selectedId != null) {
                          setState(() => toAccountId = selectedId);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                toAccountId != null
                                    ? assetAccounts.firstWhere((a) => a.id == toAccountId).name
                                    : '请选择转入账户',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: toAccountId != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            final amountStr = amountCtrl.text.trim();
                            final amount = double.tryParse(amountStr);
                            
                            // 验证金额
                            final amountError = Validators.validateAmount(amount);
                            if (amountError != null) {
                              ErrorHandler.showError(ctx, amountError);
                              return;
                            }
                            
                            final fromId = fromAccountId;
                            final toId = toAccountId;
                            if (fromId == null || toId == null) {
                              ErrorHandler.showError(ctx, '请选择转出和转入账户');
                              return;
                            }
                            if (fromId == toId) {
                              ErrorHandler.showError(ctx, '转出账户和转入账户不能相同');
                              return;
                            }
                            
                            final bookId = context.read<BookProvider>().activeBookId;
                            await context.read<RecordProvider>().transfer(
                              accountProvider: context.read<AccountProvider>(),
                              fromAccountId: fromId,
                              toAccountId: toId,
                              amount: amount!,
                              fee: 0,
                              bookId: bookId,
                            );
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ErrorHandler.showSuccess(context, '转账成功');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ErrorHandler.handleAsyncError(context, e);
                            }
                          }
                        },
                        child: const Text('确认转账'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 96,
            color: cs.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            '从第一个账户开始，看清你的资产',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '添加你的现金、银行卡或借款账户，净资产一目了然。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
        ],
      ),
    );
  }
}

class _AccountGroupData {
  const _AccountGroupData({required this.title, required this.accounts});

  final String title;
  final List<Account> accounts;
}

class _GroupDefinition {
  const _GroupDefinition({
    required this.title,
    required this.kind,
    required this.subtypes,
  });

  final String title;
  final AccountKind kind;
  final List<String> subtypes;
}

List<_AccountGroupData> _groupAccounts(List<Account> accounts) {
  final definitions = [
    _GroupDefinition(
      title: '现金',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.cash.code],
    ),
    _GroupDefinition(
      title: '储蓄卡',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.savingCard.code],
    ),
    _GroupDefinition(
      title: '信用卡',
      kind: AccountKind.liability,
      subtypes: [AccountSubtype.creditCard.code],
    ),
    _GroupDefinition(
      title: '虚拟账户',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.virtual.code],
    ),
    _GroupDefinition(
      title: '投资账户',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.invest.code],
    ),
    _GroupDefinition(
      title: '自定义资产',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.customAsset.code],
    ),
    _GroupDefinition(
      title: '负债（贷款 / 借入）',
      kind: AccountKind.liability,
      subtypes: [AccountSubtype.loan.code],
    ),
  ];

  final handled = <String>{};
  final result = <_AccountGroupData>[];

  for (final def in definitions) {
    final list = accounts.where((a) {
      if (handled.contains(a.id)) return false;
      final belongs = def.subtypes.contains(a.subtype) && a.kind == def.kind;
      return belongs;
    }).toList();
    if (list.isNotEmpty) {
      handled.addAll(list.map((e) => e.id));
      result.add(_AccountGroupData(title: def.title, accounts: list));
    }
  }

  final leftovers = accounts.where((a) => !handled.contains(a.id)).toList();
  if (leftovers.isNotEmpty) {
    result.add(_AccountGroupData(title: '其他账户', accounts: leftovers));
  }
  return result;
}

Future<AccountKind?> _startAddAccountFlow(BuildContext context) async {
  final accountProvider = context.read<AccountProvider>();
  final assetBefore = accountProvider.byKind(AccountKind.asset).length;
  final hasDebtBefore =
      accountProvider.byKind(AccountKind.liability).isNotEmpty;

  final createdKind = await Navigator.push<AccountKind>(
    context,
    MaterialPageRoute(builder: (_) => const AddAccountTypePage()),
  );
  if (createdKind == null) return null;

  final assetAfter = accountProvider.byKind(AccountKind.asset).length;
  final hasDebtAfter = accountProvider.byKind(AccountKind.liability).isNotEmpty;
  if (createdKind == AccountKind.asset &&
      assetBefore == 0 &&
      !hasDebtBefore &&
      !hasDebtAfter &&
      context.mounted) {
    await _promptAddDebt(context);
  }
  return createdKind;
}

Future<void> _promptAddDebt(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('添加负债账户'),
      content: const Text('要不要顺便把负债账户也加进去？这样净资产会更真实。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('以后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('添加负债账户'),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    await Navigator.push<AccountKind>(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountTypePage()),
    );
  }
}


class _RecordNavIcon extends StatelessWidget {
  const _RecordNavIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.add,
        size: 26,
        color: cs.onPrimary,
      ),
    );
  }
}
