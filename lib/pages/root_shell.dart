import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/account_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/quick_add_sheet.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'stats_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    const HomePage(),
    const StatsPage(),
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
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: _RecordNavIcon(color: cs.primary),
            selectedIcon: _RecordNavIcon(color: cs.primary),
            label: '记一笔',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '资产',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
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
                        : _AccountList(accounts: accounts),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditAccountSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('添加账户'),
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
              '资产',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
                        '总资产',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalAssets.toStringAsFixed(2),
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
                        '总负债',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalDebts.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
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
                        '净资产',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        netWorth.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: netColor,
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
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Account>>{};
    for (final account in accounts) {
      final key = _groupName(account.type, account.isDebt);
      groups.putIfAbsent(key, () => []).add(account);
    }

    final groupKeys = groups.keys.toList();

    return ListView.builder(
      itemCount: groupKeys.length,
      itemBuilder: (context, index) {
        final key = groupKeys[index];
        final list = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                key,
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
                  for (final account in list)
                    _AccountTile(
                      account: account,
                      isLast: account == list.last,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _groupName(AccountType type, bool isDebt) {
    if (isDebt) return '负债';
    switch (type) {
      case AccountType.cash:
      case AccountType.eWallet:
        return '现金与支付';
      case AccountType.bankCard:
        return '银行卡';
      case AccountType.investment:
        return '理财资产';
      case AccountType.other:
      default:
        return '其他';
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isLast,
  });

  final Account account;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDebt = account.isDebt;
    final amountColor = isDebt ? Colors.orange : cs.primary;
    final icon = _iconForAccount(account);

    return InkWell(
      onTap: () => _showEditAccountSheet(context, account: account),
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
                  account.balance.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
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
      case AccountType.other:
      default:
        return Icons.account_balance_outlined;
    }
  }

  String _subtitleForAccount(Account account) {
    if (account.isDebt) return '负债账户';
    switch (account.type) {
      case AccountType.cash:
        return '现金';
      case AccountType.bankCard:
        return '银行卡';
      case AccountType.eWallet:
        return '支付账户';
      case AccountType.investment:
        return '理财';
      case AccountType.loan:
        return '借贷';
      case AccountType.other:
      default:
        return '其他';
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
          Icon(Icons.account_balance_wallet_outlined,
              size: 80, color: cs.outline),
          const SizedBox(height: 12),
          const Text(
            '还没有添加任何资产账户',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('可以先添加“现金”“银行卡”等账户'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showEditAccountSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditAccountSheet(
  BuildContext context, {
  Account? account,
}) async {
  final isEditing = account != null;
  final accountProvider = context.read<AccountProvider>();

  final nameController = TextEditingController(text: account?.name ?? '');
  final balanceController =
      TextEditingController(text: account?.balance.toString() ?? '');
  AccountType type = account?.type ?? AccountType.cash;
  bool isDebt = account?.isDebt ?? false;
  bool includeInTotal = account?.includeInTotal ?? true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final viewInsets = MediaQuery.of(ctx).viewInsets;
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEditing ? '编辑账户' : '新增账户',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '账户名称',
                        hintText: '如 现金、招商银行卡',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      value: type,
                      decoration: const InputDecoration(labelText: '账户类型'),
                      items: const [
                        DropdownMenuItem(
                          value: AccountType.cash,
                          child: Text('现金'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.bankCard,
                          child: Text('银行卡'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.eWallet,
                          child: Text('支付账户'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.investment,
                          child: Text('理财资产'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.loan,
                          child: Text('负债账户'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.other,
                          child: Text('其他'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '当前余额',
                        hintText: '如 1000.00',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('这是负债账户'),
                      subtitle: const Text('如信用卡欠款、花呗等'),
                      value: isDebt,
                      onChanged: (value) {
                        setState(() => isDebt = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('计入总资产 / 净资产'),
                      value: includeInTotal,
                      onChanged: (value) {
                        setState(() => includeInTotal = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (isEditing)
                          TextButton.icon(
                            onPressed: () async {
                              await accountProvider.deleteAccount(account!.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('删除账户'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final balance = double.tryParse(
                                  balanceController.text.trim(),
                                ) ??
                                0;
                            if (name.isEmpty) return;
                            final base = Account(
                              id: account?.id ?? '',
                              name: name,
                              type: type,
                              icon: '',
                              balance: balance,
                              isDebt: isDebt,
                              includeInTotal: includeInTotal,
                            );
                            if (isEditing) {
                              await accountProvider.updateAccount(base);
                            } else {
                              await accountProvider.addAccount(base);
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Text(isEditing ? '保存' : '添加'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

