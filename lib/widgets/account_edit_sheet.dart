import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

Future<AccountKind?> showAccountEditSheet(
  BuildContext context, {
  Account? account,
  AccountKind? initialKind,
}) async {
  final isEditing = account != null;
  final accountProvider = context.read<AccountProvider>();

  final nameController = TextEditingController(text: account?.name ?? '');
  final balanceController = TextEditingController(
    text: (account?.currentBalance ?? account?.initialBalance ?? 0).toString(),
  );
  final counterpartyController =
      TextEditingController(text: account?.counterparty ?? '');
  final interestController = TextEditingController(
    text: account?.interestRate?.toString() ?? '',
  );
  DateTime? dueDate = account?.dueDate;

  AccountKind kind = account?.kind ?? initialKind ?? AccountKind.asset;
  AccountType type = account?.type ??
      (kind == AccountKind.liability
          ? AccountType.loan
          : kind == AccountKind.lend
              ? AccountType.lend
              : AccountType.cash);
  bool includeInTotal = account?.includeInTotal ?? true;

  final result = await showModalBottomSheet<AccountKind>(
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
                          isEditing
                              ? AppStrings.editAccount
                              : AppStrings.newAccount,
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
                        labelText: AppStrings.accountName,
                        hintText: AppStrings.accountNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '账户类型',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<AccountKind>(
                      segments: const [
                        ButtonSegment(
                          value: AccountKind.asset,
                          label: Text('资产'),
                        ),
                        ButtonSegment(
                          value: AccountKind.liability,
                          label: Text('负债'),
                        ),
                        ButtonSegment(
                          value: AccountKind.lend,
                          label: Text('借出'),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: (set) {
                        setState(() {
                          kind = set.first;
                          if (kind == AccountKind.liability) {
                            type = AccountType.loan;
                          } else if (kind == AccountKind.lend) {
                            type = AccountType.lend;
                          } else {
                            type = AccountType.cash;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      value: type,
                      decoration:
                          const InputDecoration(labelText: AppStrings.accountType),
                      items: const [
                        DropdownMenuItem(
                          value: AccountType.cash,
                          child: Text(AppStrings.cash),
                        ),
                        DropdownMenuItem(
                          value: AccountType.bankCard,
                          child: Text(AppStrings.bankCard),
                        ),
                        DropdownMenuItem(
                          value: AccountType.eWallet,
                          child: Text(AppStrings.payAccount),
                        ),
                        DropdownMenuItem(
                          value: AccountType.investment,
                          child: Text(AppStrings.investment),
                        ),
                        DropdownMenuItem(
                          value: AccountType.loan,
                          child: Text(AppStrings.debtAccount),
                        ),
                        DropdownMenuItem(
                          value: AccountType.lend,
                          child: Text('借出账户'),
                        ),
                        DropdownMenuItem(
                          value: AccountType.other,
                          child: Text(AppStrings.other),
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
                        labelText: '初始/当前余额',
                        hintText: AppStrings.balanceHint,
                      ),
                    ),
                    if (kind != AccountKind.asset) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: counterpartyController,
                        decoration: const InputDecoration(
                          labelText: '对方名称（可选）',
                          hintText: '如：银行、朋友姓名',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: interestController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '利率（年化，可选）',
                        hintText: '例如 4.2',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 5)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setState(() => dueDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '预计还清日期（可选）',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          dueDate == null
                              ? AppStrings.pleaseSelect
                              : '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(AppStrings.includeInTotal),
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
                              if (context.mounted) Navigator.pop(context, null);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text(AppStrings.deleteAccount),
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
                              includeInTotal: includeInTotal,
                              initialBalance: balance,
                              currentBalance: balance,
                              kind: kind,
                              counterparty: counterpartyController.text.trim().isEmpty
                                  ? null
                                  : counterpartyController.text.trim(),
                              interestRate: double.tryParse(
                                interestController.text.trim(),
                              ),
                              dueDate: dueDate,
                            );
                            if (isEditing) {
                              await accountProvider.updateAccount(
                                base.copyWith(
                                  initialBalance: account?.initialBalance ?? balance,
                                ),
                              );
                            } else {
                              await accountProvider.addAccount(base);
                            }
                            if (context.mounted) Navigator.pop(context, kind);
                          },
                          child: Text(
                            isEditing ? AppStrings.save : AppStrings.add,
                          ),
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

  return result;
}
