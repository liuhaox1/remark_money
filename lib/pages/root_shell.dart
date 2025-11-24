import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/saving_goal.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../theme/app_tokens.dart';
import 'add_account_type_page.dart';
import 'add_record_page.dart';
import 'account_detail_page.dart';
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

  Future<void> _openQuickAddSheet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRecordPage()),
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
    final grouped = _groupAccounts(accounts);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('资产总览'),
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
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            for (final group in grouped)
                              _AccountGroupPanel(
                                group: group,
                                savingGoalProvider: savingGoalProvider,
                                onAdd: () => _startAddAccountFlow(context),
                              ),
                            const SizedBox(height: 12),
                            _SavingGoalSection(
                              savingGoalProvider: savingGoalProvider,
                              accountProvider: accountProvider,
                              onAddGoal: () => _openGoalSheet(context),
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
    final isDark = theme.brightness == Brightness.dark;
    final netColor = AppColors.amount(netWorth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            Text(
              AppStrings.netWorth,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatAmount(netWorth),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: netColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '资产 ${_formatAmount(totalAssets)}    负债 ${_formatAmount(totalDebts)}',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
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

class _AccountGroupPanel extends StatelessWidget {
  const _AccountGroupPanel({
    required this.group,
    required this.savingGoalProvider,
    required this.onAdd,
  });

  final _AccountGroupData group;
  final SavingGoalProvider savingGoalProvider;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Row(
            children: [
              Text(
                group.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加账户'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final account in group.accounts)
                _AccountTile(
                  account: account,
                  isLast: account == group.accounts.last,
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
    final isDebt = account.kind == AccountKind.liability;
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
                    fontSize: 15,
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
                    '目标 ${goal.name} · 已完成 ¥${contributed.toStringAsFixed(0)} / ¥${goal.targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 56,
              endIndent: 12,
              color: cs.outlineVariant.withOpacity(0.4),
            ),
        ],
      ),
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
        return '贷款/借入';
      case AccountSubtype.receivable:
        return '应收/借出';
      case AccountSubtype.customAsset:
        return '自定义资产';
    }
  }
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
            '从第一个账户开始，看清你的钱',
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

class _SavingGoalSection extends StatelessWidget {
  const _SavingGoalSection({
    required this.savingGoalProvider,
    required this.accountProvider,
    required this.onAddGoal,
  });

  final SavingGoalProvider savingGoalProvider;
  final AccountProvider accountProvider;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final goals = savingGoalProvider.goals;
    if (goals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '给资产账户设置一个存款目标，跟踪进度更有动力。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              FilledButton(
                onPressed: onAddGoal,
                child: const Text('新建目标'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '存款目标',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onAddGoal,
                  child: const Text('新建目标'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final goal in goals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _SavingGoalTile(
                  goal: goal,
                  accountProvider: accountProvider,
                  savingGoalProvider: savingGoalProvider,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavingGoalTile extends StatelessWidget {
  const _SavingGoalTile({
    required this.goal,
    required this.accountProvider,
    required this.savingGoalProvider,
  });

  final SavingGoal goal;
  final AccountProvider accountProvider;
  final SavingGoalProvider savingGoalProvider;

  @override
  Widget build(BuildContext context) {
    final progress = savingGoalProvider.amountProgress(goal);
    final contributed = savingGoalProvider.contributedAmount(goal.id);
    final account = accountProvider.byId(goal.accountId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${account?.name ?? ''} · 已存 ¥${contributed.toStringAsFixed(0)} / ¥${goal.targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text('${(progress * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}

class _AccountGroupData {
  _AccountGroupData({required this.title, required this.accounts});

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
      title: '负债（贷款/借入）',
      kind: AccountKind.liability,
      subtypes: [AccountSubtype.loan.code],
    ),
    _GroupDefinition(
      title: '债权（应收/借出）',
      kind: AccountKind.lend,
      subtypes: [AccountSubtype.receivable.code],
    ),
  ];

  final handled = <String>{};
  final result = <_AccountGroupData>[];
  for (final def in definitions) {
    final list = accounts.where((a) {
      if (handled.contains(a.id)) return false;
      final belongs =
          def.subtypes.contains(a.subtype) && a.kind == def.kind;
      return belongs;
    }).toList();
    if (list.isNotEmpty) {
      handled.addAll(list.map((e) => e.id));
      result.add(_AccountGroupData(title: def.title, accounts: list));
    }
  }

  final leftovers =
      accounts.where((a) => !handled.contains(a.id)).toList();
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
  final hasDebtAfter =
      accountProvider.byKind(AccountKind.liability).isNotEmpty;
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

Future<void> _openGoalSheet(BuildContext context) async {
  final accountProvider = context.read<AccountProvider>();
  final savingGoalProvider = context.read<SavingGoalProvider>();
  final accounts = accountProvider.byKind(AccountKind.asset);
  if (accounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先添加资产账户')),
    );
    return;
  }

  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String? selectedAccountId = accounts.first.id;
  DateTime startDate = DateTime.now();
  DateTime? endDate;

  await showModalBottomSheet(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '新建存款目标',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '目标名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '目标金额',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAccountId,
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedAccountId = v),
                  decoration: const InputDecoration(
                    labelText: '绑定账户',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '起始日期',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDate(startDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: startDate,
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '截止日期（可选）',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            endDate == null
                                ? '未设置'
                                : _formatDate(endDate!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0 || selectedAccountId == null) {
                      return;
                    }
                    final goal = SavingGoal(
                      id: '',
                      name: nameCtrl.text.trim().isEmpty
                          ? '存款目标'
                          : nameCtrl.text.trim(),
                      accountId: selectedAccountId!,
                      targetAmount: amount,
                      startDate: startDate,
                      endDate: endDate,
                      status: SavingGoalStatus.active,
                    );
                    await savingGoalProvider.addGoal(goal);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('保存目标'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  nameCtrl.dispose();
  amountCtrl.dispose();
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
