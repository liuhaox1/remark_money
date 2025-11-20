import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/budget_progress.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final TextEditingController _totalCtrl = TextEditingController();
  final Map<String, TextEditingController> _categoryCtrls = {};
  String? _syncedBookId;

  @override
  void dispose() {
    _totalCtrl.dispose();
    for (final ctrl in _categoryCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _syncControllers({
    required String bookId,
    required List<Category> categories,
    required BudgetEntry budget,
  }) {
    final bookChanged = _syncedBookId != bookId;
    if (bookChanged) {
      _totalCtrl.text =
          budget.total == 0 ? '' : budget.total.toStringAsFixed(0);
      for (final ctrl in _categoryCtrls.values) {
        ctrl.dispose();
      }
      _categoryCtrls.clear();
    }

    final categoryKeys = categories.map((c) => c.key).toSet();
    final removedKeys = _categoryCtrls.keys
        .where((key) => !categoryKeys.contains(key))
        .toList();
    for (final key in removedKeys) {
      _categoryCtrls.remove(key)?.dispose();
    }

    for (final cat in categories) {
      if (!_categoryCtrls.containsKey(cat.key) || bookChanged) {
        _categoryCtrls[cat.key]?.dispose();
        _categoryCtrls[cat.key] = TextEditingController(
          text: budget.categoryBudgets[cat.key]?.toStringAsFixed(0) ?? '',
        );
      }
    }

    _syncedBookId = bookId;
  }

  Future<void> _saveBudget(String bookId) async {
    final provider = context.read<BudgetProvider>();
    final total = double.tryParse(_totalCtrl.text.trim()) ?? 0;
    final categoryBudgets = <String, double>{};

    _categoryCtrls.forEach((key, controller) {
      final raw = controller.text.trim();
      if (raw.isEmpty) return;
      final value = double.tryParse(raw);
      if (value != null && value > 0) {
        categoryBudgets[key] = value;
      }
    });

    await provider.updateBudgetForBook(
      bookId: bookId,
      totalBudget: total,
      categoryBudgets: categoryBudgets,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.budgetSaved)),
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
    final incomeCats = categories.where((c) => !c.isExpense).toList();
    final now = DateTime.now();
    final monthAnchor = DateTime(now.year, now.month, 1);
    final bookBudget = budgetProvider.budgetForBook(bookId);

    _syncControllers(
      bookId: bookId,
      categories: categories,
      budget: bookBudget,
    );

    final monthRecords =
        recordProvider.recordsForMonth(bookId, now.year, now.month);
    final expenseSpent = <String, double>{};
    final incomeSpent = <String, double>{};
    final expenseRecords = <String, List<Record>>{};
    final incomeRecords = <String, List<Record>>{};
    double totalExpense = 0;

    for (final record in monthRecords) {
      final map = record.isExpense ? expenseSpent : incomeSpent;
      final recordsMap = record.isExpense ? expenseRecords : incomeRecords;
      map[record.categoryKey] =
          (map[record.categoryKey] ?? 0) + record.absAmount;
      recordsMap.putIfAbsent(record.categoryKey, () => []).add(record);
      if (record.isExpense) {
        totalExpense += record.absAmount;
      }
    }

    final remaining = (bookBudget.total - totalExpense);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _BudgetSummaryCard(
                  month: monthAnchor,
                  totalBudget: bookBudget.total,
                  used: totalExpense,
                  remaining: remaining,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalBudgetEditor(cs),
                        const SizedBox(height: 24),
                        const _SectionHeader(
                          title: AppStrings.spendCategoryBudget,
                          subtitle: AppStrings.spendCategorySubtitle,
                        ),
                        const SizedBox(height: 8),
                        if (expenseCats.isEmpty)
                          const _EmptyHint(
                            text: AppStrings.emptySpendCategory,
                          )
                        else
                          ...expenseCats.map(
                            (cat) => _CategoryBudgetTile(
                              category: cat,
                              controller: _categoryCtrls[cat.key]!,
                              spent: expenseSpent[cat.key] ?? 0,
                              budget: bookBudget.categoryBudgets[cat.key],
                              records:
                                  expenseRecords[cat.key] ?? const <Record>[],
                              onViewDetail: () => _showCategoryDetails(
                                cat,
                                expenseRecords[cat.key] ?? const <Record>[],
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        const _SectionHeader(
                          title: AppStrings.incomeCategoryBudget,
                          subtitle: AppStrings.incomeCategorySubtitle,
                        ),
                        const SizedBox(height: 8),
                        if (incomeCats.isEmpty)
                          const _EmptyHint(
                            text: AppStrings.emptyIncomeCategory,
                          )
                        else
                          ...incomeCats.map(
                            (cat) => _CategoryBudgetTile(
                              category: cat,
                              controller: _categoryCtrls[cat.key]!,
                              spent: incomeSpent[cat.key] ?? 0,
                              budget: bookBudget.categoryBudgets[cat.key],
                              isIncome: true,
                              records:
                                  incomeRecords[cat.key] ?? const <Record>[],
                              onViewDetail: () => _showCategoryDetails(
                                cat,
                                incomeRecords[cat.key] ?? const <Record>[],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _saveBudget(bookId),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              AppStrings.saveBookBudget,
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

  Widget _buildTotalBudgetEditor(ColorScheme cs) {
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
        ],
      ),
    );
  }

  Future<void> _showCategoryDetails(
    Category category,
    List<Record> records,
  ) async {
    if (records.isEmpty) return;
    final sorted = [...records]..sort(
        (a, b) => b.date.compareTo(a.date),
      );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(category.icon,
                        color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.categoryMonthlyDetail(category.name),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final record = sorted[index];
                      final amount = record.absAmount.toStringAsFixed(2);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          record.remark.isEmpty
                              ? AppStrings.emptyRemark
                              : record.remark,
                        ),
                        subtitle: Text(DateUtilsX.ymd(record.date)),
                        trailing: Text(
                          record.isExpense ? '-¥$amount' : '+¥$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: record.isExpense
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.month,
    required this.totalBudget,
    required this.used,
    required this.remaining,
  });

  final DateTime month;
  final double totalBudget;
  final double used;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final remainingDays =
        DateUtilsX.lastDayOfMonth(month).day - DateTime.now().day + 1;
    final safeDays = remainingDays.clamp(1, 31);
    final daily = remaining > 0 ? remaining / safeDays : 0;
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
            const SizedBox(height: 12),
            BudgetProgress(total: totalBudget, used: used),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalBudget <= 0
                        ? AppStrings.budgetTip
                        : '${AppStrings.budgetTodaySuggestionPrefix}${daily.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
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
    required this.controller,
    required this.spent,
    required this.records,
    this.budget,
    this.isIncome = false,
    required this.onViewDetail,
  });

  final Category category;
  final TextEditingController controller;
  final double spent;
  final double? budget;
  final bool isIncome;
  final List<Record> records;
  final VoidCallback onViewDetail;

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
              SizedBox(
                width: 110,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.budgetInputHint,
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceVariant.withOpacity(0.25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
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
                        : (isIncome
                            ? '${AppStrings.receivableThisMonthPrefix}¥${spent.toStringAsFixed(0)}'
                            : '${AppStrings.expenseThisMonthPrefix}¥${spent.toStringAsFixed(0)}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                  const Spacer(),
                  if (records.isNotEmpty)
                    TextButton.icon(
                      onPressed: onViewDetail,
                      icon: const Icon(Icons.list_alt, size: 14),
                      label: const Text(AppStrings.viewDetails),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
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
