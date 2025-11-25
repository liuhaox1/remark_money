import 'package:flutter/material.dart';

import '../models/account.dart';
import '../theme/app_tokens.dart';

/// 统一的账户选择 BottomSheet，保证视觉一致性和更好的商业化体验
Future<String?> showAccountSelectBottomSheet(
  BuildContext context,
  List<Account> accounts, {
  String? selectedAccountId,
  String title = '选择账户',
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      if (accounts.isEmpty) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '当前还没有可用账户，请先添加账户。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isSelected = account.id == selectedAccountId;
                  return ListTile(
                    title: Text(
                      account.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '余额 ${account.currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.amount(account.currentBalance),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, account.id),
                  );
                },
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

