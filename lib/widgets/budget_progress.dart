import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_tokens.dart';

class BudgetProgress extends StatelessWidget {
  const BudgetProgress({
    super.key,
    required this.total,
    required this.used,
    this.totalLabel,
  });

  final double total;
  final double used;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final remaining = (total - used).clamp(0, double.infinity).toDouble();
    final labelColor = cs.onSurface.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _line(
              totalLabel ?? AppStrings.monthBudget,
              total,
              AppColors.primary(context),
              labelColor,
            ),
            _line(AppStrings.spent, used, AppColors.danger, labelColor),
            _line(AppStrings.remain, remaining, AppColors.success, labelColor),
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

  Widget _line(
    String label,
    double value,
    Color color,
    Color labelColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
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
