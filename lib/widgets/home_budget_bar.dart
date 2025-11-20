import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import 'budget_progress.dart';

class HomeBudgetBar extends StatelessWidget {
  const HomeBudgetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final budgetProvider = context.watch<BudgetProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final bookProvider = context.watch<BookProvider>();
    final now = DateTime.now();

    final bookId = bookProvider.activeBookId;
    final total = budgetProvider.budgetForBook(bookId).total;
    final expense = recordProvider.monthExpense(now, bookId);
    final remaining = total - expense;
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft =
        DateUtilsX.lastDayOfMonth(now).difference(today).inDays + 1;
    final dailyAllowance = daysLeft > 0 ? (remaining / daysLeft) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  AppStrings.homeBudgetTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/budget'),
                  child: const Text(AppStrings.homeBudgetDetail),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (total <= 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text(
                        AppStrings.homeBudgetNotSetTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppStrings.homeBudgetNotSetDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/budget'),
                    child: const Text(AppStrings.homeBudgetSetNow),
                  ),
                ],
              )
            else ...[
              BudgetProgress(total: total, used: expense),
              const SizedBox(height: 12),
              Row(
                children: [
                  _HomeBudgetStat(
                    label: AppStrings.homeBudgetRemaining,
                    value: '¥${remaining.toStringAsFixed(0)}',
                    color:
                        remaining >= 0 ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  _HomeBudgetStat(
                    label: AppStrings.homeBudgetTodayAvailable,
                    value: '¥${dailyAllowance.toStringAsFixed(0)}',
                    color: cs.primary,
                  ),
                  const SizedBox(width: 12),
                  _HomeBudgetStat(
                    label: AppStrings.homeBudgetDaysLeft,
                    value: AppStrings.hoursInDays(daysLeft),
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeBudgetStat extends StatelessWidget {
  const _HomeBudgetStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
