import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/record_provider.dart';
import '../providers/book_provider.dart';
import '../theme/app_tokens.dart';
import 'budget_progress.dart';

class HomeBudgetBar extends StatelessWidget {
  const HomeBudgetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budgetProvider = context.watch<BudgetProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final bookProvider = context.watch<BookProvider>();
    final now = DateTime.now();

    final total = budgetProvider.budget.total;
    final expense = recordProvider.monthExpense(now, bookProvider.activeBookId);

    return Container(
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
      child: total <= 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      "预算未设�?,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "去预算页设置一个月度预算，方便掌握支出节奏�?,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            )
          : BudgetProgress(total: total, used: expense),
    );
  }
}


