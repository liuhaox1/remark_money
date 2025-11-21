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
import '../utils/date_utils.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/budget_progress.dart';
import '../widgets/chart_bar.dart';
import '../widgets/chart_pie.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final TextEditingController _totalCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _categoryCtrls = {};
  String? _syncedBookId;

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
    final budgetEntry = budgetProvider.budgetForBook(bookId);
    final period = budgetProvider.currentPeriodRange(bookId, now);
    final bookBudget = budgetEntry;
    final monthAnchor = period.start;

    _syncControllers(
      bookId: bookId,
      categories: categories,
      budget: budgetEntry,
    );

    // 实际支出统计（只作为进度展示，不做明细）
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

    // 仅展示「有预算」或「本月有支出」的分类，避免页面太乱
    final displayExpenseCats = expenseCats.where((cat) {
      final spentValue = expenseSpent[cat.key] ?? 0;
      final catBudget = bookBudget.categoryBudgets[cat.key] ?? 0;
      return spentValue > 0 || catBudget > 0;
    }).toList();

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
                        _buildTotalBudgetEditor(cs, bookId),
                        const SizedBox(height: 24),
                        // TODO: 饼图区域在后续步骤补全
                        const _SectionHeader(
                          title: AppStrings.spendCategoryBudget,
                          subtitle: AppStrings.spendCategorySubtitle,
                        ),
                        const SizedBox(height: 8),
                        if (displayExpenseCats.isEmpty)
                          const _EmptyHint(
                            text: AppStrings.emptySpendCategory,
                          )
                        else
                          ...displayExpenseCats.map(
                            (cat) => _CategoryBudgetTile(
                              category: cat,
                              controller: _categoryCtrls[cat.key]!,
                              spent: expenseSpent[cat.key] ?? 0,
                              budget: bookBudget.categoryBudgets[cat.key],
                            ),
                          ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              // 预留：后续使用增加分类预算入口
                            },
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
                        : remaining <= 0
                            ? AppStrings.budgetOverspendTodayTip
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
    this.budget,
  });

  final Category category;
  final TextEditingController controller;
  final double spent;
  final double? budget;

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
                        : '${AppStrings.expenseThisMonthPrefix}¥${spent.toStringAsFixed(0)}',
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
