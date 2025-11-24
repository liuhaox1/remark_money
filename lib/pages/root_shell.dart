import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/account_edit_sheet.dart';
import '../widgets/quick_add_sheet.dart';
import 'account_detail_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'analysis_page.dart';

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

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }

  void _handleDestination(int value) {
    if (value == 2) {
      _openQuickAddSheet();
      return;
    }
    final mappedIndex = value > 2 ? value - 1 : value;
    setState(() => _index = mappedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final buildStart = DateTime.now();
    final cs = Theme.of(context).colorScheme;
    final scaffold = Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.12),
        selectedIndex: _index >= 2 ? _index + 1 : _index,
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
        onDestinationSelected: _handleDestination,
      ),
    );
    debugPrint(
      'RootShell build: ${DateTime.now().difference(buildStart).inMilliseconds}ms',
    );
    return scaffold;
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

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountProvider = context.watch<AccountProvider>();
    final savingGoalProvider = context.watch<SavingGoalProvider>();

    final totalAssets = accountProvider.totalAssets;
    final totalDebts = accountProvider.totalDebts;
    final netWorth = accountProvider.netWorth;
    final accounts = accountProvider.accounts;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _AssetSummaryCard(
                  totalAssets: totalAssets,
                  totalDebts: totalDebts,
                  netWorth: netWorth,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: accounts.isEmpty
                        ? const _EmptyAccounts()
                        : _AccountList(
                            accounts: accounts,
                            savingGoalProvider: savingGoalProvider,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAccount(context, accountProvider),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addAccount),
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
    final isDark = theme.brightness == Brightness.dark;
    final netColor = AppColors.amount(netWorth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.18),
                    Colors.white,
                  ],
                ),
          color: isDark ? cs.surface : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.netWorth,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatAmount(netWorth),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: netColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.totalAssets,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatAmount(totalAssets),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.totalDebts,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatAmount(totalDebts),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final absValue = value.abs();
    if (absValue >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    } else if (absValue >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    } else {
      return value.toStringAsFixed(2);
    }
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.savingGoalProvider,
  });

  final List<Account> accounts;
  final SavingGoalProvider savingGoalProvider;

  @override
  Widget build(BuildContext context) {
    final assetList =
        accounts.where((a) => a.kind == AccountKind.asset).toList();
    final debtList =
        accounts.where((a) => a.kind == AccountKind.liability).toList();
    final lendList = accounts.where((a) => a.kind == AccountKind.lend).toList();

    return ListView(
      children: [
        if (assetList.isNotEmpty)
          _AccountGroup(
            title: '资产账户',
            accounts: assetList,
            savingGoalProvider: savingGoalProvider,
          ),
        if (debtList.isNotEmpty)
          _AccountGroup(
            title: '负债账户',
            accounts: debtList,
            savingGoalProvider: savingGoalProvider,
          ),
        if (lendList.isNotEmpty)
          _AccountGroup(
            title: '借出账户',
            accounts: lendList,
            savingGoalProvider: savingGoalProvider,
          ),
      ],
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({
    required this.title,
    required this.accounts,
    required this.savingGoalProvider,
  });

  final String title;
  final List<Account> accounts;
  final SavingGoalProvider savingGoalProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final account in accounts)
                _AccountTile(
                  account: account,
                  isLast: account == accounts.last,
                  savingGoalProvider: savingGoalProvider,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isLast,
    required this.savingGoalProvider,
  });

  final Account account;
  final bool isLast;
  final SavingGoalProvider savingGoalProvider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDebt = account.isDebt;
    final amountColor = isDebt ? Colors.orange : cs.primary;
    final icon = _iconForAccount(account);
    final goal = savingGoalProvider.goalForAccount(account.id);
    final goalProgress =
        goal == null ? 0.0 : savingGoalProvider.amountProgress(goal);
    final contributed =
        goal == null ? 0.0 : savingGoalProvider.contributedAmount(goal.id);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountDetailPage(accountId: account.id),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleForAccount(account),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  account.currentBalance.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          if (goal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: goalProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '目标：${goal.name} · 已完成 ¥${contributed.toStringAsFixed(0)} / ¥${goal.targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 54,
              endIndent: 12,
              color: cs.outlineVariant.withOpacity(0.4),
            ),
        ],
      ),
    );
  }

  IconData _iconForAccount(Account account) {
    switch (account.type) {
      case AccountType.cash:
        return Icons.account_balance_wallet_outlined;
      case AccountType.bankCard:
        return Icons.credit_card;
      case AccountType.eWallet:
        return Icons.payment;
      case AccountType.investment:
        return Icons.savings_outlined;
      case AccountType.loan:
        return Icons.trending_down;
      case AccountType.lend:
        return Icons.swap_horiz_outlined;
      case AccountType.other:
      default:
        return Icons.account_balance_outlined;
    }
  }

  String _subtitleForAccount(Account account) {
    if (account.kind == AccountKind.liability) return '负债账户';
    if (account.kind == AccountKind.lend) return '借出账户';
    switch (account.type) {
      case AccountType.cash:
        return AppStrings.cash;
      case AccountType.bankCard:
        return AppStrings.bankCard;
      case AccountType.eWallet:
        return AppStrings.payAccount;
      case AccountType.investment:
        return AppStrings.investment;
      case AccountType.loan:
        return AppStrings.borrow;
      case AccountType.lend:
        return '借出';
      case AccountType.other:
      default:
        return AppStrings.other;
    }
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: cs.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            AppStrings.emptyAccountsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(AppStrings.emptyAccountsSubtitle),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                _openAddAccount(context, context.read<AccountProvider>()),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.addAccount),
          ),
        ],
      ),
    );
  }
}

Future<void> _openAddAccount(
  BuildContext context,
  AccountProvider accountProvider,
) async {
  final assetBefore = accountProvider.byKind(AccountKind.asset).length;
  final hasDebtBefore =
      accountProvider.byKind(AccountKind.liability).isNotEmpty;
  final createdKind = await showAccountEditSheet(context);
  if (createdKind == null) return;

  final assetAfter = accountProvider.byKind(AccountKind.asset).length;
  final hasDebtAfter =
      accountProvider.byKind(AccountKind.liability).isNotEmpty;
  if (createdKind == AccountKind.asset &&
      assetBefore == 0 &&
      !hasDebtBefore &&
      !hasDebtAfter) {
    await _promptAddDebt(context, accountProvider);
  }
}

Future<void> _promptAddDebt(
  BuildContext context,
  AccountProvider accountProvider,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('添加负债账户'),
      content: const Text('要不要顺便添加一个负债账户，让净资产更真实？'),
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
    await showAccountEditSheet(
      context,
      initialKind: AccountKind.liability,
    );
  }
}
