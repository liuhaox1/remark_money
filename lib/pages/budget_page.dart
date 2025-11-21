import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/budget_progress.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final TextEditingController _totalCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 统一的金额输入过滤器：仅允许数字和小数点
  static final TextInputFormatter _digitsAndDotFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  @override
  void dispose() {
    _totalCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    final truncated = value.truncateToDouble();
    if (value == truncated) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  double? _parseAmount(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final normalized = text.startsWith('.') ? '0$text' : text;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    if (value <= 0) return null;
    final clamped = value.clamp(0, 999999999.99);
    return double.parse(clamped.toStringAsFixed(2));
  }

  Future<void> _saveTotalBudget(String bookId) async {
    final provider = context.read<BudgetProvider>();
    final parsed = _parseAmount(_totalCtrl.text);
    final total = parsed ?? 0;

    await provider.setTotal(bookId, total);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.budgetSaved)),
    );
  }

  Future<void> _openPeriodSheet(String bookId, int currentDay) async {
    int selectedDay = currentDay.clamp(1, 28);

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.budgetPeriodSettingTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.budgetPeriodSettingDesc,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final selected = day == selectedDay;
                    return GestureDetector(
                      onTap: () {
                        selectedDay = day;
                        (ctx as Element).markNeedsBuild();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(selectedDay),
                    child: const Text(AppStrings.ok),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    final provider = context.read<BudgetProvider>();
    await provider.setPeriodStartDay(bookId, result);
  }

  Future<void> _onResetBudget(String bookId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.resetBookBudget),
            content: const Text(AppStrings.resetBookBudgetConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(AppStrings.ok),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final provider = context.read<BudgetProvider>();
    await provider.resetBudgetForBook(bookId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.budgetSaved)),
    );
  }
  Future<void> _editCategoryBudget({
    required String bookId,
    required Category category,
    required double? currentBudget,
  }) async {
    final controller = TextEditingController(
      text: currentBudget != null && currentBudget > 0
          ? _formatAmount(currentBudget)
          : '',
    );

    final result = await showDialog<_EditBudgetResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('为「${category.name}」设置预算'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_digitsAndDotFormatter],
          decoration: const InputDecoration(
            prefixText: '¥ ',
            hintText: AppStrings.budgetInputHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          if (currentBudget != null && currentBudget > 0)
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(const _EditBudgetResult(deleted: true)),
              child: const Text(AppStrings.deleteBudget),
            ),
          FilledButton(
            onPressed: () {
              final parsed = _parseAmount(controller.text);
              if (parsed == null) {
                Navigator.of(ctx)
                    .pop(const _EditBudgetResult(deleted: true));
              } else {
                Navigator.of(ctx).pop(
                  _EditBudgetResult(deleted: false, value: parsed),
                );
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    final provider = context.read<BudgetProvider>();

    if (result.deleted || (result.value ?? 0) <= 0) {
      await provider.deleteCategoryBudget(bookId, category.key);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.categoryBudgetDeleted)),
      );
      return;
    }

    await provider.setCategoryBudget(bookId, category.key, result.value!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.categoryBudgetSaved)),
    );
  }

  Future<void> _addCategoryBudget({
    required String bookId,
    required List<Category> expenseCategories,
    required BudgetEntry budgetEntry,
    required Map<String, double> expenseSpent,
  }) async {
    final existingKeys = budgetEntry.categoryBudgets.keys.toSet();
    final candidates = expenseCategories
        .where((c) => !existingKeys.contains(c.key))
        .toList(growable: false);
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所有支出分类都已设置预算，可直接点击分类右侧进行调整。'),
        ),
      );
      return;
    }

    candidates.sort((a, b) {
      final sa = expenseSpent[a.key] ?? 0;
      final sb = expenseSpent[b.key] ?? 0;
      return sb.compareTo(sa);
    });

    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.addCategoryBudget,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '优先为本期花得多的分类设置预算，有助于更好地控制支出。',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cat = candidates[index];
                    final spent = expenseSpent[cat.key] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        child: Icon(
                          cat.icon,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(cat.name),
                      subtitle: Text(
                        '${AppStrings.expenseThisPeriodPrefix}¥${spent.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(cat.key),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedKey == null) return;

    final category =
        expenseCategories.firstWhere((element) => element.key == selectedKey);

    await _editCategoryBudget(
      bookId: bookId,
      category: category,
      currentBudget: null,
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bookProvider = context.watch<BookProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final budgetProvider = context.watch<BudgetProvider>();

    final bookId = bookProvider.activeBookId;
    final categories = categoryProvider.categories;
    final expenseCats = categories.where((c) => c.isExpense).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budgetEntry = budgetProvider.budgetForBook(bookId);
    final period = budgetProvider.currentPeriodRange(bookId, now);
    final bookBudget = budgetEntry;
    final startMonth = period.start.month.toString().padLeft(2, '0');
    final startDay = period.start.day.toString().padLeft(2, '0');
    final endMonth = period.end.month.toString().padLeft(2, '0');
    final endDay = period.end.day.toString().padLeft(2, '0');
    final periodLabel = '周期: $startMonth.$startDay - $endMonth.$endDay';
    final periodPillText = '每月 ${budgetEntry.periodStartDay} 日';
    final totalExpense = recordProvider.periodExpense(
      bookId: bookId,
      start: period.start,
      end: period.end,
    );
    final expenseSpent = recordProvider.periodCategoryExpense(
      bookId: bookId,
      start: period.start,
      end: period.end,
    );

    final remaining = (budgetEntry.total - totalExpense);
    final periodDaysLeft = period.end.difference(today).inDays + 1;
    final safeDaysLeft = periodDaysLeft < 0 ? 0 : periodDaysLeft;
    final dailyAllowance =
        safeDaysLeft > 0 ? (remaining / safeDaysLeft) : 0.0;
    final weekEndCandidate = today.add(Duration(days: 7 - today.weekday));
    final weekEnd =
        weekEndCandidate.isAfter(period.end) ? period.end : weekEndCandidate;
    final weekDaysLeft = weekEnd.difference(today).inDays + 1;
    final safeWeekDays = weekDaysLeft < 0 ? 0 : weekDaysLeft;
    final weeklyAllowance =
        safeWeekDays > 0 ? dailyAllowance * safeWeekDays : 0.0;

    final displayExpenseCats = expenseCats.where((cat) {
      final spentValue = expenseSpent[cat.key] ?? 0;
      final catBudget = bookBudget.categoryBudgets[cat.key] ?? 0;
      return spentValue > 0 || catBudget > 0;
    }).toList();
    final categoryBudgetSum = bookBudget.categoryBudgets.values
        .where((v) => v > 0)
        .fold(0.0, (a, b) => a + b);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(AppStrings.budget),
        actions: [
          PopupMenuButton<_BudgetMenuAction>(
            onSelected: (value) async {
              if (value == _BudgetMenuAction.reset) {
                await _onResetBudget(bookId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _BudgetMenuAction.reset,
                child: Text(AppStrings.resetBookBudget),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _BudgetSummaryCard(
                  month: period.start,
                  totalBudget: budgetEntry.total,
                  used: totalExpense,
                  remaining: remaining,
                  periodLabel: periodLabel,
                  periodPillText: periodPillText,
                  onTapCycle: () =>
                      _openPeriodSheet(bookId, budgetEntry.periodStartDay),
                  dailyAllowance: dailyAllowance,
                  weeklyAllowance: weeklyAllowance,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalBudgetEditor(cs, bookId),
                        const SizedBox(height: 24),
                        const _SectionHeader(
                          title: AppStrings.spendCategoryBudget,
                          subtitle: AppStrings.spendCategorySubtitlePeriod,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.budgetCategoryRelationHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.65),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${AppStrings.budgetCategorySummaryPrefix} ¥${categoryBudgetSum.toStringAsFixed(0)}'
                          '${budgetEntry.total > 0 ? ' · 占总预算 ${(categoryBudgetSum / budgetEntry.total * 100).toStringAsFixed(1)}%' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: categoryBudgetSum > budgetEntry.total &&
                                    budgetEntry.total > 0
                                ? AppColors.danger
                                : cs.onSurface.withOpacity(0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (displayExpenseCats.isEmpty)
                          const _EmptyHint(
                            text: AppStrings.budgetCategoryEmptyHint,
                          )
                        else
                          ...displayExpenseCats.map(
                            (cat) => _CategoryBudgetTile(
                              category: cat,
                              spent: expenseSpent[cat.key] ?? 0,
                              budget: bookBudget.categoryBudgets[cat.key],
                              onEdit: () => _editCategoryBudget(
                                bookId: bookId,
                                category: cat,
                                currentBudget:
                                    bookBudget.categoryBudgets[cat.key],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _addCategoryBudget(
                              bookId: bookId,
                              expenseCategories: expenseCats,
                              budgetEntry: bookBudget,
                              expenseSpent: expenseSpent,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text(
                              AppStrings.addCategoryBudget,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBudgetEditor(ColorScheme cs, String bookId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.monthTotalBudget,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_digitsAndDotFormatter],
            decoration: InputDecoration(
              prefixText: '¥ ',
              hintText: AppStrings.monthBudgetHint,
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.budgetDescription,
            style: TextStyle(
              fontSize: 12,
              color: cs.outline,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _saveTotalBudget(bookId),
              icon: const Icon(Icons.save_outlined),
              label: const Text(AppStrings.save),
            ),
          ),
        ],
      ),
    );
  }
}
class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.month,
    required this.totalBudget,
    required this.used,
    required this.remaining,
    required this.periodLabel,
    required this.periodPillText,
    required this.onTapCycle,
    required this.dailyAllowance,
    required this.weeklyAllowance,
  });

  final DateTime month;
  final double totalBudget;
  final double used;
  final double remaining;
  final String periodLabel;
  final String periodPillText;
  final VoidCallback onTapCycle;
  final double dailyAllowance;
  final double weeklyAllowance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusText = totalBudget <= 0
        ? AppStrings.budgetNotSet
        : AppStrings.budgetRemainingLabel(remaining, remaining < 0);
    final statusColor = totalBudget <= 0
        ? cs.outline
        : remaining >= 0
            ? AppColors.success
            : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.15),
                    Colors.white,
                  ],
                ),
          color: isDark ? cs.surface : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.bookMonthBudgetTitle(month),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const BookSelectorButton(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    periodLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onTapCycle,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      periodPillText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BudgetProgress(total: totalBudget, used: used),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AllowanceStat(
                    label: '日均可用',
                    value: '¥${dailyAllowance.toStringAsFixed(0)}',
                    background: cs.surfaceVariant.withOpacity(0.25),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AllowanceStat(
                    label: '本周可用',
                    value: '¥${weeklyAllowance.toStringAsFixed(0)}',
                    background: cs.primary.withOpacity(0.12),
                    icon: Icons.view_week_outlined,
                    iconColor: cs.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllowanceStat extends StatelessWidget {
  const _AllowanceStat({
    required this.label,
    required this.value,
    required this.background,
    required this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final Color background;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? cs.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.outline),
        ),
      ],
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.category,
    required this.spent,
    required this.onEdit,
    this.budget,
  });

  final Category category;
  final double spent;
  final double? budget;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBudget = budget != null && budget! > 0;
    final double? remaining = hasBudget ? budget! - spent : null;
    final isOverspend = remaining != null && remaining < 0;
    final progress =
        hasBudget ? (spent / budget!).clamp(0.0, 1.0) : (spent > 0 ? 1.0 : 0.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  budget != null && budget! > 0
                      ? AppStrings.edit
                      : AppStrings.setBudget,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    hasBudget
                        ? AppStrings.budgetUsedLabel(spent, budget)
                        : '${AppStrings.expenseThisPeriodPrefix}¥${spent.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: hasBudget ? progress : (spent > 0 ? 1 : 0),
                  backgroundColor: cs.surfaceVariant.withOpacity(0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    !hasBudget
                        ? cs.primary.withOpacity(0.6)
                        : isOverspend
                            ? AppColors.danger
                            : cs.primary,
                  ),
                ),
              ),
              if (hasBudget && remaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppStrings.budgetRemainingLabel(
                      remaining,
                      isOverspend,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverspend ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

enum _BudgetMenuAction {
  reset,
}

class _EditBudgetResult {
  const _EditBudgetResult({required this.deleted, this.value});

  final bool deleted;
  final double? value;
}
