import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bank_brands.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/brand_logo_avatar.dart';
import '../widgets/account_select_bottom_sheet.dart';
import 'account_form_page.dart';

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final account = accountProvider.byId(accountId);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('账户详情')),
        body: const Center(child: Text('账户不存在')),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final actions = _buildActions(context, account);

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (account.brandKey != null)
                          _BrandBadge(brandKey: account.brandKey!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kindLabel(account.kind),
                      style: TextStyle(color: cs.outline),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          account.currentBalance.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _getBalanceColor(account, cs),
                          ),
                        ),
                        if (_hasBalanceIssue(account)) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getBalanceIssueText(account),
                                  style: TextStyle(
                                    fontSize: 11,
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
                    const SizedBox(height: 4),
                    Text(
                      '初始余额：${account.initialBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                    if (account.counterparty != null &&
                        account.counterparty!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('对方：${account.counterparty!}'),
                    ],
                    if (account.dueDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '预计结清：${account.dueDate!.year}-${account.dueDate!.month.toString().padLeft(2, '0')}-${account.dueDate!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '账户管理',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openAdjustBalanceSheet(context, account),
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('调整余额'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            side: BorderSide(color: cs.primary),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<AccountKind>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountFormPage(
                                  kind: account.kind,
                                  subtype: AccountSubtype.fromCode(account.subtype),
                                  account: account,
                                ),
                              ),
                            );
                            if (result != null && context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('编辑账户'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            side: BorderSide(color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '账户操作',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, Account account) {
    final cs = Theme.of(context).colorScheme;
    final buttons = <Widget>[];

    Widget actionButton(String label, VoidCallback onTap) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: BorderSide(color: cs.primary),
        ),
        child: Text(label),
      );
    }

    if (account.kind == AccountKind.asset) {
      buttons.add(
        actionButton('转账', () => _openTransferSheet(context, account)),
      );
    }

    if (account.kind == AccountKind.liability) {
      buttons.add(
        actionButton('新增借款', () => _openBorrowSheet(context, account)),
      );
      buttons.add(
        actionButton('还款', () => _openRepaySheet(context, account)),
      );
    }

    if (account.kind == AccountKind.lend) {
      buttons.add(
        actionButton('借给对方', () => _openLendSheet(context, account)),
      );
      buttons.add(
        actionButton('收回借款', () => _openReceiveSheet(context, account)),
      );
    }

    return buttons;
  }

  void _openTransferSheet(BuildContext context, Account account) {
    final amountCtrl = TextEditingController();
    String? toAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final accounts = context.read<AccountProvider>().accounts.where((a) {
          return a.kind != AccountKind.liability && a.id != account.id;
        }).toList();
        if (accounts.isNotEmpty && toAccountId == null) {
          toAccountId = accounts.first.id;
        }
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
                          final selectedId = await showAccountSelectBottomSheet(
                            context,
                            accounts,
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
                                      ? accounts.firstWhere((a) => a.id == toAccountId).name
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final targetId = toAccountId;
                      if (targetId == null) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().transfer(
                            accountProvider: context.read<AccountProvider>(),
                            fromAccountId: account.id,
                            toAccountId: targetId,
                            amount: amount,
                            fee: 0,
                            bookId: bookId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openBorrowSheet(BuildContext context, Account account) {
    final amountCtrl = TextEditingController();
    String? assetAccountId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final assets = context
            .read<AccountProvider>()
            .accounts
            .where((a) => a.kind == AccountKind.asset)
            .toList();
        if (assets.isNotEmpty && assetAccountId == null) {
          assetAccountId = assets.first.id;
        }
        final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '新增借款',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assetAccountId,
                    items: assets
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => assetAccountId = v),
                    decoration: const InputDecoration(
                      labelText: '资金进入账户',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '借款金额',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final targetId = assetAccountId;
                      if (targetId == null) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().borrow(
                            accountProvider: context.read<AccountProvider>(),
                            debtAccountId: account.id,
                            assetAccountId: targetId,
                            amount: amount,
                            bookId: bookId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openRepaySheet(BuildContext context, Account account) {
    final principalCtrl = TextEditingController();
    final interestCtrl = TextEditingController();
    String? assetAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final assets = context
            .read<AccountProvider>()
            .accounts
            .where((a) => a.kind == AccountKind.asset)
            .toList();
        if (assets.isNotEmpty && assetAccountId == null) {
          assetAccountId = assets.first.id;
        }
        final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '还款',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assetAccountId,
                    items: assets
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => assetAccountId = v),
                    decoration: const InputDecoration(
                      labelText: '还款资金来源',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: principalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '本金金额',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: interestCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '利息（可选，计入支出）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final principal =
                          double.tryParse(principalCtrl.text.trim()) ?? 0;
                      final interest =
                          double.tryParse(interestCtrl.text.trim()) ?? 0;
                      final sourceId = assetAccountId;
                      if (sourceId == null || principal <= 0) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().repay(
                            accountProvider: context.read<AccountProvider>(),
                            debtAccountId: account.id,
                            assetAccountId: sourceId,
                            principal: principal,
                            interest: interest,
                            bookId: bookId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openLendSheet(BuildContext context, Account account) {
    final amountCtrl = TextEditingController();
    String? assetAccountId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final assets = context
            .read<AccountProvider>()
            .accounts
            .where((a) => a.kind == AccountKind.asset)
            .toList();
        if (assets.isNotEmpty && assetAccountId == null) {
          assetAccountId = assets.first.id;
        }
        final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '借给对方',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assetAccountId,
                    items: assets
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => assetAccountId = v),
                    decoration: const InputDecoration(
                      labelText: '资金来源账户',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '借出金额',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final sourceId = assetAccountId;
                      if (sourceId == null) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().lendOut(
                            accountProvider: context.read<AccountProvider>(),
                            lendAccountId: account.id,
                            assetAccountId: sourceId,
                            amount: amount,
                            bookId: bookId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openReceiveSheet(BuildContext context, Account account) {
    final amountCtrl = TextEditingController();
    String? assetAccountId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final assets = context
            .read<AccountProvider>()
            .accounts
            .where((a) => a.kind == AccountKind.asset)
            .toList();
        if (assets.isNotEmpty && assetAccountId == null) {
          assetAccountId = assets.first.id;
        }
        final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '收回借款',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assetAccountId,
                    items: assets
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => assetAccountId = v),
                    decoration: const InputDecoration(
                      labelText: '收款账户',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '收回金额',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final destId = assetAccountId;
                      if (destId == null) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().receiveLend(
                            accountProvider: context.read<AccountProvider>(),
                            lendAccountId: account.id,
                            assetAccountId: destId,
                            amount: amount,
                            bookId: bookId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _kindLabel(AccountKind kind) {
    switch (kind) {
      case AccountKind.asset:
        return '资产账户';
      case AccountKind.liability:
        return '负债账户';
      case AccountKind.lend:
        return '借出账户';
    }
  }

  Color _getBalanceColor(Account account, ColorScheme cs) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    // 储蓄卡、现金等资产账户不应该有负余额
    if (account.kind == AccountKind.asset && 
        (subtype == AccountSubtype.savingCard || subtype == AccountSubtype.cash) &&
        account.currentBalance < 0) {
      return AppColors.danger;
    }
    return AppColors.amount(account.currentBalance);
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

  String _getBalanceIssueText(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    if (subtype == AccountSubtype.savingCard) {
      return '储蓄卡余额异常';
    }
    if (subtype == AccountSubtype.cash) {
      return '现金余额异常';
    }
    return '余额异常';
  }

  void _openAdjustBalanceSheet(BuildContext context, Account account) {
    final balanceCtrl = TextEditingController(
      text: account.currentBalance.toStringAsFixed(2),
    );
    final initialBalanceCtrl = TextEditingController(
      text: account.initialBalance.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '调整账户余额',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '如果账户余额与实际不符，可以调整初始余额来修正。调整后，当前余额会自动同步更新。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: initialBalanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '初始余额',
                  helperText: '修改初始余额以修正历史偏差',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '当前余额',
                  helperText: '当前账户的实际余额',
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
                        final newInitialBalance = double.tryParse(initialBalanceCtrl.text.trim());
                        final newCurrentBalance = double.tryParse(balanceCtrl.text.trim());
                        
                        if (newInitialBalance == null || newCurrentBalance == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请输入有效的金额')),
                          );
                          return;
                        }

                        final accountProvider = context.read<AccountProvider>();
                        final currentAccount = accountProvider.byId(account.id);
                        if (currentAccount == null) return;
                        
                        // 计算初始余额的调整量
                        final initialBalanceDelta = newInitialBalance - account.initialBalance;
                        // 计算当前余额的调整量
                        final currentBalanceDelta = newCurrentBalance - account.currentBalance;
                        
                        // 如果初始余额有变化，先调整初始余额（这会自动更新currentBalance）
                        if (initialBalanceDelta.abs() > 0.01) {
                          await accountProvider.adjustInitialBalance(
                            account.id,
                            newInitialBalance,
                          );
                        }
                        
                        // 然后调整当前余额到目标值（考虑初始余额调整的影响）
                        final finalBalanceDelta = currentBalanceDelta - initialBalanceDelta;
                        if (finalBalanceDelta.abs() > 0.01) {
                          await accountProvider.adjustBalance(account.id, finalBalanceDelta);
                        }

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.brandKey});

  final String brandKey;

  @override
  Widget build(BuildContext context) {
    final brand = findBankBrand(brandKey);
    if (brand == null || brand.key == 'custom') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: brand.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        brand.shortName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: brand.color,
        ),
      ),
    );
  }
}
