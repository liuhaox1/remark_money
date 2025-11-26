import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
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
