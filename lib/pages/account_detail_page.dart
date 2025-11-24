import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/saving_goal.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../widgets/account_edit_sheet.dart';

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final account = accountProvider.byId(accountId);
    final savingGoalProvider = context.watch<SavingGoalProvider>();
    final goal = savingGoalProvider.goalForAccount(accountId);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await showAccountEditSheet(context, account: account);
              if (result != null && context.mounted) Navigator.pop(context);
            },
          ),
        ],
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
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kindLabel(account.kind),
                      style: TextStyle(color: cs.outline),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      account.currentBalance.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
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
            if (goal != null) _buildGoalCard(context, goal, savingGoalProvider),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '操作',
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
            if (account.kind == AccountKind.asset && goal == null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openGoalSheet(context, accountId),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('设置存款目标'),
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

  Widget _buildGoalCard(
    BuildContext context,
    SavingGoal goal,
    SavingGoalProvider provider,
  ) {
    final contributed = provider.contributedAmount(goal.id);
    final progress = provider.amountProgress(goal);
    final timeProgress = provider.timeProgress(goal);
    final status = provider.resolveStatus(goal);
    final cs = Theme.of(context).colorScheme;
    final remain = (goal.targetAmount - contributed).clamp(0, goal.targetAmount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _statusLabel(status),
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 6),
            Text(
              '已完成 ¥${contributed.toStringAsFixed(0)} / 目标 ¥${goal.targetAmount.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 4),
            Text('剩余金额 ¥${remain.toStringAsFixed(0)}'),
            const SizedBox(height: 4),
            Text('时间进度 ${(timeProgress * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }

  void _openTransferSheet(BuildContext context, Account account) {
    final amountCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: toAccountId,
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => toAccountId = v),
                    decoration: const InputDecoration(
                      labelText: '转入账户',
                      border: OutlineInputBorder(),
                    ),
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
                  TextField(
                    controller: feeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '手续费（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) return;
                      final fee = double.tryParse(feeCtrl.text.trim()) ?? 0;
                      final targetId = toAccountId;
                      if (targetId == null) return;
                      final bookId =
                          context.read<BookProvider>().activeBookId;
                      await context.read<RecordProvider>().transfer(
                            accountProvider: context.read<AccountProvider>(),
                            fromAccountId: account.id,
                            toAccountId: targetId,
                            amount: amount,
                            fee: fee,
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

  void _openGoalSheet(BuildContext context, String accountId) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime? endDate;

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
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365 * 5)),
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
                            child: Text(
                              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                            ),
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
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365 * 5)),
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
                                  : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
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
                      if (amount == null || amount <= 0) return;
                      final goal = SavingGoal(
                        id: '',
                        name: nameCtrl.text.trim().isEmpty
                            ? '存款目标'
                            : nameCtrl.text.trim(),
                        accountId: accountId,
                        targetAmount: amount,
                        startDate: startDate,
                        endDate: endDate,
                        status: SavingGoalStatus.active,
                      );
                      await context.read<SavingGoalProvider>().addGoal(goal);
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
  }

  String _statusLabel(SavingGoalStatus status) {
    switch (status) {
      case SavingGoalStatus.completed:
        return '已完成';
      case SavingGoalStatus.overdue:
        return '已逾期';
      case SavingGoalStatus.pending:
        return '未开始';
      case SavingGoalStatus.active:
      default:
        return '进行中';
    }
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
}
