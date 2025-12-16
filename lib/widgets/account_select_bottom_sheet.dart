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
      final tt = Theme.of(context).textTheme;
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
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前还没有可用账户，请先添加账户。',
                  style: tt.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.87),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '知道了',
                      style: tt.labelLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
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
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onSurface,
                    ),
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
                      style: tt.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '余额 ${account.currentBalance.toStringAsFixed(2)}',
                      style: tt.bodyMedium?.copyWith(
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
