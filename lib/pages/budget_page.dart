import 'dart:math';
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
import '../utils/validators.dart';
import '../utils/error_handler.dart';
import '../utils/text_style_extensions.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/budget_progress.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int _initialTabIndex = 0;
  bool _tabIndexInitialized = false;

  final TextEditingController _totalCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 统一的金额输入过滤器：仅允许数字和小数点
  static final TextInputFormatter _digitsAndDotFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabIndexInitialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _initialTabIndex = args == 'year' ? 1 : 0;
    }
    _tabIndexInitialized = true;
  }

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
    try {
      final provider = context.read<BudgetProvider>();
      final parsed = _parseAmount(_totalCtrl.text);
      final total = parsed ?? 0;

      // 验证金额
      final amountError = Validators.validateAmount(total);
      if (amountError != null && total > 0) {
        if (!mounted) return;
        ErrorHandler.showError(context, amountError);
        return;
      }

      await provider.setTotal(bookId, total);

      if (!mounted) return;
      ErrorHandler.showSuccess(context, AppStrings.budgetSaved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
  }

  Future<void> _saveAnnualBudget(String bookId) async {
    try {
      final provider = context.read<BudgetProvider>();
      final parsed = _parseAmount(_totalCtrl.text);
      final total = parsed ?? 0;

      // 验证金额
      final amountError = Validators.validateAmount(total);
      if (amountError != null && total > 0) {
        if (!mounted) return;
        ErrorHandler.showError(context, amountError);
        return;
      }

      await provider.setAnnualTotal(bookId, total);

      if (!mounted) return;
      ErrorHandler.showSuccess(context, AppStrings.budgetSaved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
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
              Text(
                AppStrings.budgetPeriodSettingTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.budgetPeriodSettingDesc,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
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
                                ? Theme.of(context).colorScheme.onPrimary
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
                    child: Text(
                      AppStrings.cancel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
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

    if (!mounted) return;
    final provider = context.read<BudgetProvider>();
    await provider.setPeriodStartDay(bookId, result);
  }

  Future<void> _onResetBudget(String bookId) async {
    final confirmed = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            final media = MediaQuery.of(ctx);
            final bottomPadding = media.viewInsets.bottom + media.padding.bottom + 16;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 24,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppStrings.resetBookBudget,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.resetBookBudgetConfirm,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurface.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '该操作只会清空预算设置，不会删除任何记账记录。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                              color: cs.outline.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            AppStrings.cancel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            '确认重置',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    if (!mounted) return;
    try {
      final provider = context.read<BudgetProvider>();
      await provider.resetBudgetForBook(bookId);

      if (!mounted) return;
      ErrorHandler.showSuccess(context, AppStrings.budgetSaved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
  }

  Future<void> _showBudgetActionsSheet(String bookId) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final selected = await showModalBottomSheet<_BudgetMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.refresh,
                  color: cs.error,
                ),
                title: Text(
                  AppStrings.resetBookBudget,
                  style: TextStyle(
                    color: cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  '清空本账本的总预算和所有分类预算',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(_BudgetMenuAction.reset),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == _BudgetMenuAction.reset) {
      await _onResetBudget(bookId);
    }
  }

  Future<void> _editCategoryBudget({
    required String bookId,
    required Category category,
    required double? currentBudget,
    required bool isYear,
  }) async {
    final controller = TextEditingController(
      text: currentBudget != null && currentBudget > 0
          ? _formatAmount(currentBudget)
          : '',
    );

    final result = await showDialog<_EditBudgetResult>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(
            '为「${category.name}」设置预算',
            style: TextStyle(
              color: cs.onSurface,
            ),
          ),
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
              child: Text(
                AppStrings.cancel,
                style: TextStyle(
                  color: cs.onSurface,
                ),
              ),
            ),
            if (currentBudget != null && currentBudget > 0)
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(const _EditBudgetResult(deleted: true)),
                child: Text(
                  AppStrings.deleteBudget,
                  style: TextStyle(
                    color: cs.error,
                  ),
                ),
              ),
            FilledButton(
              onPressed: () {
                final parsed = _parseAmount(controller.text);
                if (parsed == null) {
                  Navigator.of(ctx).pop(const _EditBudgetResult(deleted: true));
                } else {
                  Navigator.of(ctx).pop(
                    _EditBudgetResult(deleted: false, value: parsed),
                  );
                }
              },
              child: const Text(AppStrings.save),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    final provider = context.read<BudgetProvider>();

    try {
      if (result.deleted || (result.value ?? 0) <= 0) {
        if (isYear) {
          await provider.deleteAnnualCategoryBudget(bookId, category.key);
        } else {
          await provider.deleteCategoryBudget(bookId, category.key);
        }
        if (!mounted) return;
        ErrorHandler.showSuccess(context, AppStrings.categoryBudgetDeleted);
        return;
      }

      if (isYear) {
        await provider.setAnnualCategoryBudget(
            bookId, category.key, result.value!);
      } else {
        await provider.setCategoryBudget(bookId, category.key, result.value!);
      }
      if (!mounted) return;
      ErrorHandler.showSuccess(context, AppStrings.categoryBudgetSaved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
  }

  Future<void> _addCategoryBudget({
    required String bookId,
    required List<Category> expenseCategories,
    required BudgetEntry budgetEntry,
    required Map<String, double> expenseSpent,
    required bool isYear,
  }) async {
    final existingKeys = (isYear
            ? budgetEntry.annualCategoryBudgets
            : budgetEntry.categoryBudgets)
        .keys
        .toSet();
    final candidates = expenseCategories
        .where((c) => !existingKeys.contains(c.key))
        .toList(growable: false);
    if (candidates.isEmpty) {
      if (!mounted) return;
      ErrorHandler.showInfo(context, '所有支出分类都已设置预算，可直接点击分类右侧进行调整。');
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
              Text(
                AppStrings.addCategoryBudget,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '优先为本期花得多的分类设置预算，有助于更好地控制支出。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                ),
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
                      title: Text(
                        cat.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${AppStrings.expenseThisPeriodPrefix}¥${spent.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

    if (!mounted) return;
    final category =
        expenseCategories.firstWhere((element) => element.key == selectedKey);

    await _editCategoryBudget(
      bookId: bookId,
      category: category,
      currentBudget: null,
      isYear: isYear,
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

    // 使用 FutureBuilder 异步加载预算数据
    return FutureBuilder<Map<String, _BudgetViewData>>(
      future: Future.wait([
        _buildViewData(
          view: _BudgetView.month,
          bookId: bookId,
          budgetEntry: budgetEntry,
          recordProvider: recordProvider,
          budgetProvider: budgetProvider,
          today: today,
        ),
        _buildViewData(
          view: _BudgetView.year,
          bookId: bookId,
          budgetEntry: budgetEntry,
          recordProvider: recordProvider,
          budgetProvider: budgetProvider,
          today: today,
        ),
      ]).then((results) => {
        'month': results[0],
        'year': results[1],
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('预算'),
              backgroundColor: Colors.transparent,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final monthData = snapshot.data?['month'];
        final yearData = snapshot.data?['year'];
        
        if (monthData == null || yearData == null) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('预算'),
              backgroundColor: Colors.transparent,
            ),
            body: const Center(child: Text('加载失败')),
          );
        }

        return DefaultTabController(
      length: 2,
      initialIndex: _initialTabIndex,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text(AppStrings.budget),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.tabMonth),
              Tab(text: AppStrings.tabYear),
            ],
          ),
          actions: [
            IconButton(
              tooltip: AppStrings.resetBookBudget,
              icon: const Icon(Icons.more_horiz),
              onPressed: () async {
                await _showBudgetActionsSheet(bookId);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      AppStrings.budgetDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTabContent(
                          cs: cs,
                          bookId: bookId,
                          budgetEntry: budgetEntry,
                          expenseCats: expenseCats,
                          data: monthData,
                          showPeriodPicker: true,
                        ),
                        _buildTabContent(
                          cs: cs,
                          bookId: bookId,
                          budgetEntry: budgetEntry,
                          expenseCats: expenseCats,
                          data: yearData,
                          showPeriodPicker: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      );
      },
    );
  }

  Widget _buildTabContent({
    required ColorScheme cs,
    required String bookId,
    required BudgetEntry budgetEntry,
    required List<Category> expenseCats,
    required _BudgetViewData data,
    required bool showPeriodPicker,
  }) {
    final isYearView = data.view == _BudgetView.year;
    final categoryBudgets = isYearView
        ? budgetEntry.annualCategoryBudgets
        : budgetEntry.categoryBudgets;

    final displayExpenseCats = expenseCats.where((cat) {
      final spentValue = data.expenseSpent[cat.key] ?? 0;
      final catBudget = categoryBudgets[cat.key] ?? 0;
      return spentValue > 0 || catBudget > 0;
    }).toList();

    final categoryBudgetSum =
        categoryBudgets.values.where((v) => v > 0).fold(0.0, (a, b) => a + b);

    return Column(
      children: [
        _BudgetSummaryCard(
          title: data.title,
          totalBudget: data.totalBudget,
          hasBudget: data.hasBudget,
          isYearView: isYearView,
          used: data.used,
          remaining: data.remaining,
          periodLabel: data.periodLabel,
          periodPillText: data.periodPillText,
          onTapCycle: showPeriodPicker
              ? () => _openPeriodSheet(bookId, budgetEntry.periodStartDay)
              : null,
          dailyAllowance: data.dailyAllowance,
          weeklyAllowance: data.weeklyAllowance,
          dailyAverage: data.dailyAverage,
          weeklyAverage: data.weeklyAverage,
          monthlyAverage: data.monthlyAverage,
          dailyRemaining: data.dailyRemaining,
          weeklyRemaining: data.weeklyRemaining,
          monthlyRemaining: data.monthlyRemaining,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalBudgetEditor(cs, bookId, isYear: !showPeriodPicker),
                const SizedBox(height: 16),
                _buildBudgetAlertCard(cs, data, isYearView),
                const SizedBox(height: 16),
                _buildBudgetAnalysisCard(context, cs, data, bookId, isYearView),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: AppStrings.spendCategoryBudget,
                  subtitle: '仅展示本期支出进度',
                ),
                const SizedBox(height: 6),
                Text(
                  '将总预算拆到分类，便于控制重点支出',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppStrings.budgetCategorySummaryPrefix} ¥${categoryBudgetSum.toStringAsFixed(0)}'
                  '${budgetEntry.total > 0 ? ' · 占预算 ${(categoryBudgetSum / budgetEntry.total * 100).toStringAsFixed(1)}%' : ''}',
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
                    text: '尚未设置分类预算。建议先为常用支出（如餐饮、购物）设置预算，可点击下方“增加分类预算”',
                  )
                else
                  ...displayExpenseCats.map(
                    (cat) => _CategoryBudgetTile(
                      category: cat,
                      spent: data.expenseSpent[cat.key] ?? 0,
                      budget: categoryBudgets[cat.key],
                      onEdit: () => _editCategoryBudget(
                        bookId: bookId,
                        category: cat,
                        currentBudget: categoryBudgets[cat.key],
                        isYear: isYearView,
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
                      budgetEntry: budgetEntry,
                      expenseSpent: data.expenseSpent,
                      isYear: isYearView,
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
    );
  }

  Future<_BudgetViewData> _buildViewData({
    required _BudgetView view,
    required String bookId,
    required BudgetEntry budgetEntry,
    required RecordProvider recordProvider,
    required BudgetProvider budgetProvider,
    required DateTime today,
  }) async {
    final isYear = view == _BudgetView.year;
    final period = isYear
        ? DateTimeRange(
            start: DateTime(today.year, 1, 1),
            end: DateTime(today.year, 12, 31),
          )
        : budgetProvider.currentPeriodRange(bookId, today);

    final totalBudget = isYear ? budgetEntry.annualTotal : budgetEntry.total;
    final hasBudget = totalBudget > 0;
    final used = await recordProvider.periodExpense(
      bookId: bookId,
      start: period.start,
      end: period.end,
    );
    final expenseSpent = await recordProvider.periodCategoryExpense(
      bookId: bookId,
      start: period.start,
      end: period.end,
    );
    final remaining = hasBudget ? (totalBudget - used) : 0.0;

    final clampedToday = today.isBefore(period.start)
        ? period.start
        : (today.isAfter(period.end) ? period.end : today);

    final daysElapsed =
        max(1, clampedToday.difference(period.start).inDays + 1);
    final daysLeft = max(0, period.end.difference(clampedToday).inDays + 1);
    final weeksElapsed = max(1, ((daysElapsed - 1) ~/ 7) + 1);
    final monthsElapsed = isYear ? max(1, min(12, clampedToday.month)) : 1;
    final monthsLeft = isYear ? max(1, 12 - monthsElapsed) : 1;

    final dailyAllowance =
        hasBudget && daysLeft > 0 ? remaining / daysLeft : 0.0;
    final weekEndCandidate =
        clampedToday.add(Duration(days: 7 - clampedToday.weekday));
    final weekEnd =
        weekEndCandidate.isAfter(period.end) ? period.end : weekEndCandidate;
    final weekDaysLeft = max(0, weekEnd.difference(clampedToday).inDays + 1);
    final weeklyAllowance =
        hasBudget && weekDaysLeft > 0 ? dailyAllowance * weekDaysLeft : 0.0;

    final dailyAverage = hasBudget ? used / max(1, daysElapsed) : 0.0;
    final weeklyAverage = hasBudget ? used / max(1, weeksElapsed) : 0.0;
    final monthlyAverage = hasBudget ? used / max(1, monthsElapsed) : 0.0;
    final monthlyRemaining =
        hasBudget && monthsLeft > 0 ? remaining / monthsLeft : remaining;

    final periodLabel =
        '周期: ${_formatDate(period.start)} - ${_formatDate(period.end)}';
    final periodPillText =
        isYear ? AppStrings.fullYear : '每月 ${budgetEntry.periodStartDay} 日';
    final title = isYear
        ? AppStrings.bookYearBudgetTitle(period.start.year)
        : AppStrings.bookMonthBudgetTitle(period.start);

    return _BudgetViewData(
      view: view,
      period: period,
      title: title,
      periodLabel: periodLabel,
      periodPillText: periodPillText,
      totalBudget: totalBudget,
      hasBudget: hasBudget,
      used: used,
      remaining: remaining,
      dailyAllowance: dailyAllowance,
      weeklyAllowance: weeklyAllowance,
      dailyAverage: dailyAverage,
      weeklyAverage: weeklyAverage,
      monthlyAverage: monthlyAverage,
      dailyRemaining: dailyAllowance,
      weeklyRemaining: weeklyAllowance,
      monthlyRemaining: monthlyRemaining,
      expenseSpent: expenseSpent,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  Widget _buildTotalBudgetEditor(ColorScheme cs, String bookId,
      {bool isYear = false}) {
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
                isYear ? AppStrings.yearBudget : AppStrings.monthTotalBudget,
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
              hintText:
                  isYear ? AppStrings.yearBudget : AppStrings.monthBudgetHint,
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
              onPressed: () =>
                  isYear ? _saveAnnualBudget(bookId) : _saveTotalBudget(bookId),
              icon: const Icon(Icons.save_outlined),
              label: const Text(AppStrings.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetViewData {
  const _BudgetViewData({
    required this.view,
    required this.period,
    required this.title,
    required this.periodLabel,
    required this.periodPillText,
    required this.totalBudget,
    required this.hasBudget,
    required this.used,
    required this.remaining,
    required this.dailyAllowance,
    required this.weeklyAllowance,
    required this.dailyAverage,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.dailyRemaining,
    required this.weeklyRemaining,
    required this.monthlyRemaining,
    required this.expenseSpent,
  });

  final _BudgetView view;
  final DateTimeRange period;
  final String title;
  final String periodLabel;
  final String periodPillText;
  final double totalBudget;
  final bool hasBudget;
  final double used;
  final double remaining;
  final double dailyAllowance;
  final double weeklyAllowance;
  final double dailyAverage;
  final double weeklyAverage;
  final double monthlyAverage;
  final double dailyRemaining;
  final double weeklyRemaining;
  final double monthlyRemaining;
  final Map<String, double> expenseSpent;
}

enum _BudgetView { month, year }

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.title,
    required this.totalBudget,
    required this.isYearView,
    required this.used,
    required this.remaining,
    required this.periodLabel,
    required this.periodPillText,
    required this.hasBudget,
    this.onTapCycle,
    required this.dailyAllowance,
    required this.weeklyAllowance,
    required this.dailyAverage,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.dailyRemaining,
    required this.weeklyRemaining,
    required this.monthlyRemaining,
  });

  final String title;
  final double totalBudget;
  final bool isYearView;
  final double used;
  final double remaining;
  final String periodLabel;
  final String periodPillText;
  final bool hasBudget;
  final VoidCallback? onTapCycle;
  final double dailyAllowance;
  final double weeklyAllowance;
  final double dailyAverage;
  final double weeklyAverage;
  final double monthlyAverage;
  final double dailyRemaining;
  final double weeklyRemaining;
  final double monthlyRemaining;

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
                    cs.surface,
                  ],
                ),
          color: isDark ? cs.surface : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: cs.onSurface.withOpacity(0.05),
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
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
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
            BudgetProgress(
              total: totalBudget,
              used: used,
              totalLabel: isYearView
                  ? AppStrings.yearBudgetBalance
                  : AppStrings.monthBudget,
            ),
            if (hasBudget) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AllowanceStat(
                      label: '每日可用',
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AvgStatTile(
                      title: AppStrings.avgDailySpend,
                      value: '¥${dailyAverage.toStringAsFixed(0)}',
                      sub:
                          '${AppStrings.remainingToday}: ¥${dailyRemaining.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AvgStatTile(
                      title: AppStrings.avgWeeklySpend,
                      value: '¥${weeklyAverage.toStringAsFixed(0)}',
                      sub:
                          '${AppStrings.remainingWeek}: ¥${weeklyRemaining.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AvgStatTile(
                      title: AppStrings.avgMonthlySpend,
                      value: '¥${monthlyAverage.toStringAsFixed(0)}',
                      sub:
                          '${AppStrings.remainingMonth}: ¥${monthlyRemaining.toStringAsFixed(0)}',
                    ),
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

class _AvgStatTile extends StatelessWidget {
  const _AvgStatTile({
    required this.title,
    required this.value,
    required this.sub,
  });

  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.outline,
          ),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                  ),
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
                      color: cs.onSurface,
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
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withOpacity(0.75),
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

  /// 构建预算提醒卡片
  Widget _buildBudgetAlertCard(
    ColorScheme cs,
    _BudgetViewData data,
    bool isYearView,
  ) {
    if (data.totalBudget <= 0) return const SizedBox.shrink();

    final usedPercent = (data.used / data.totalBudget * 100);
    final remaining = data.totalBudget - data.used;
    final now = DateTime.now();
    final daysInPeriod = isYearView
        ? DateTime(now.year, 12, 31).difference(DateTime(now.year, 1, 1)).inDays + 1
        : DateTime(now.year, now.month + 1, 0).day;
    final daysUsed = isYearView
        ? now.difference(DateTime(now.year, 1, 1)).inDays + 1
        : now.day;
    final daysLeft = daysInPeriod - daysUsed;
    final dailyAllowance = daysLeft > 0 ? remaining / daysLeft : 0;

    String alertText = '';
    Color alertColor = cs.primary;
    IconData alertIcon = Icons.info_outline;

    if (usedPercent >= 100) {
      alertText = '预算已用完，建议控制支出';
      alertColor = AppColors.danger;
      alertIcon = Icons.warning;
    } else if (usedPercent >= 80) {
      alertText = '预算已用${usedPercent.toStringAsFixed(0)}%，剩余${daysLeft}天，建议控制支出';
      alertColor = Colors.orange;
      alertIcon = Icons.warning_amber;
    } else if (usedPercent >= 50) {
      alertText = '预算已用${usedPercent.toStringAsFixed(0)}%，剩余¥${remaining.toStringAsFixed(0)}';
      alertColor = cs.primary;
      alertIcon = Icons.info_outline;
    } else {
      return const SizedBox.shrink(); // 使用率低时不显示提醒
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(alertIcon, color: alertColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alertText,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface,
              ),
            ),
          ),
          if (dailyAllowance > 0 && daysLeft > 0)
            Text(
              '日均¥${dailyAllowance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建预算分析卡片
  Widget _buildBudgetAnalysisCard(
    BuildContext ctx,
    ColorScheme cs,
    _BudgetViewData data,
    String bookId,
    bool isYearView,
  ) {
    if (data.totalBudget <= 0) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getBudgetAnalysisData(bookId, isYearView, ctx),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final analysisData = snapshot.data ?? {};
        final lastPeriodUsed = analysisData['lastPeriodUsed'] as double? ?? 0;
        final avgDailyExpense = analysisData['avgDailyExpense'] as double? ?? 0;
        final predictedTotal = analysisData['predictedTotal'] as double? ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '预算分析',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (lastPeriodUsed > 0) ...[
                _buildAnalysisItem(
                  cs,
                  '上${isYearView ? '年' : '月'}支出',
                  '¥${lastPeriodUsed.toStringAsFixed(0)}',
                  data.used > lastPeriodUsed
                      ? '比上${isYearView ? '年' : '月'}增加${((data.used - lastPeriodUsed) / lastPeriodUsed * 100).toStringAsFixed(1)}%'
                      : '比上${isYearView ? '年' : '月'}减少${((lastPeriodUsed - data.used) / lastPeriodUsed * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 6),
              ],
              if (avgDailyExpense > 0) ...[
                _buildAnalysisItem(
                  cs,
                  '日均支出',
                  '¥${avgDailyExpense.toStringAsFixed(0)}',
                  '按此速度，${isYearView ? '年度' : '月度'}将支出¥${predictedTotal.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 6),
              ],
              if (predictedTotal > data.totalBudget && data.totalBudget > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '预测支出将超过预算，建议控制消费',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisItem(ColorScheme cs, String label, String value, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getBudgetAnalysisData(String bookId, bool isYearView, BuildContext ctx) async {
    final recordProvider = Provider.of<RecordProvider>(ctx, listen: false);
    final now = DateTime.now();

    if (isYearView) {
      // 年度分析
      final thisYearStart = DateTime(now.year, 1, 1);
      final thisYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);
      final lastYearStart = DateTime(now.year - 1, 1, 1);
      final lastYearEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);

      final thisYearUsed = await recordProvider.periodExpense(
        bookId: bookId,
        start: thisYearStart,
        end: now,
      );
      final lastYearUsed = await recordProvider.periodExpense(
        bookId: bookId,
        start: lastYearStart,
        end: lastYearEnd,
      );

      final daysUsed = now.difference(thisYearStart).inDays + 1;
      final avgDailyExpense = daysUsed > 0 ? thisYearUsed / daysUsed : 0;
      final predictedTotal = avgDailyExpense * 365;

      return {
        'lastPeriodUsed': lastYearUsed,
        'avgDailyExpense': avgDailyExpense,
        'predictedTotal': predictedTotal,
      };
    } else {
      // 月度分析
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final thisMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

      final thisMonthUsed = await recordProvider.periodExpense(
        bookId: bookId,
        start: thisMonthStart,
        end: now,
      );
      final lastMonthUsed = await recordProvider.periodExpense(
        bookId: bookId,
        start: lastMonthStart,
        end: lastMonthEnd,
      );

      final daysUsed = now.day;
      final avgDailyExpense = daysUsed > 0 ? thisMonthUsed / daysUsed : 0;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final predictedTotal = avgDailyExpense * daysInMonth;

      return {
        'lastPeriodUsed': lastMonthUsed,
        'avgDailyExpense': avgDailyExpense,
        'predictedTotal': predictedTotal,
      };
    }
  }
