import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_tokens.dart';

class BudgetProgress extends StatelessWidget {
  const BudgetProgress({
    super.key,
    required this.total,
    required this.used,
  });

  final double total;
  final double used;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final remaining = (total - used).clamp(0, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _line(AppStrings.monthBudget, total, AppColors.primary(context)),
            _line(AppStrings.spent, used, AppColors.danger),
            _line(AppStrings.remain, remaining, AppColors.success),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: progress,
            backgroundColor: cs.surfaceVariant.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1 ? AppColors.danger : AppColors.primary(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥ ${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
