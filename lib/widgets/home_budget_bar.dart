import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import 'budget_progress.dart';

class HomeBudgetBar extends StatefulWidget {
  const HomeBudgetBar({super.key});

  @override
  State<HomeBudgetBar> createState() => _HomeBudgetBarState();
}

class _HomeBudgetBarState extends State<HomeBudgetBar> {
  static const String _viewPrefKey = 'home_budget_view';

  _HomeBudgetView _view = _HomeBudgetView.month;

  String? _usedKey;
  Future<_BudgetUsedData>? _usedFuture;
  _BudgetUsedData? _usedCache;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_viewPrefKey);
    if (!mounted) return;
    setState(() {
      _view = value == 'year' ? _HomeBudgetView.year : _HomeBudgetView.month;
    });
  }

  Future<void> _onViewChanged(_HomeBudgetView next) async {
    if (_view == next) return;
    setState(() {
      _view = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _viewPrefKey,
      next == _HomeBudgetView.year ? 'year' : 'month',
    );
  }

  void _openBudgetPage(BuildContext context, _HomeBudgetView target) {
    Navigator.pushNamed(
      context,
      '/budget',
      arguments: target == _HomeBudgetView.year ? 'year' : 'month',
    );
  }

  void _ensureUsedFuture({
    required RecordProvider recordProvider,
    required String bookId,
    required DateTime today,
    required DateTimeRange monthPeriod,
    required int recordChangeCounter,
  }) {
    final yearStart = DateTime(today.year, 1, 1);
    final yearEnd = DateTime(today.year, 12, 31);
    final key = '$bookId:'
        '${monthPeriod.start.millisecondsSinceEpoch}:${monthPeriod.end.millisecondsSinceEpoch}:'
        '${yearStart.millisecondsSinceEpoch}:${yearEnd.millisecondsSinceEpoch}:'
        '$recordChangeCounter';
    if (_usedKey == key && _usedFuture != null) return;
    _usedKey = key;
    _usedFuture = Future.wait<double>([
      recordProvider.periodExpense(
        bookId: bookId,
        start: monthPeriod.start,
        end: monthPeriod.end,
      ),
      recordProvider.periodExpense(
        bookId: bookId,
        start: yearStart,
        end: yearEnd,
      ),
    ]).then((values) {
      return _BudgetUsedData(monthUsed: values[0], yearUsed: values[1]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final budgetProvider = context.watch<BudgetProvider>();
    final recordProvider = context.read<RecordProvider>();
    final recordChangeCounter =
        context.select<RecordProvider, int>((p) => p.changeCounter);
    final bookProvider = context.watch<BookProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final bookId = bookProvider.activeBookId;
    final budgetEntry = budgetProvider.budgetForBook(bookId);

    // 月度预算数据
    final monthPeriod = budgetProvider.currentPeriodRange(bookId, today);
    final monthTotal = budgetEntry.total;
    _ensureUsedFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      today: today,
      monthPeriod: monthPeriod,
      recordChangeCounter: recordChangeCounter,
    );

    return FutureBuilder<_BudgetUsedData>(
      future: _usedFuture,
      initialData: _usedCache,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          _usedCache = snapshot.data;
        }

        final used = snapshot.data ?? _usedCache;
        final monthUsed = used?.monthUsed ?? 0.0;
        final yearUsed = used?.yearUsed ?? 0.0;
        final showLoadingOverlay =
            snapshot.connectionState == ConnectionState.waiting &&
                _usedCache != null;

        final monthRemaining = monthTotal - monthUsed;
        final monthToday = today.isBefore(monthPeriod.start)
            ? monthPeriod.start
            : (today.isAfter(monthPeriod.end) ? monthPeriod.end : today);
        final rawMonthDaysLeft =
            monthPeriod.end.difference(monthToday).inDays + 1;
        final monthDaysLeft = rawMonthDaysLeft < 0 ? 0 : rawMonthDaysLeft;
        final monthDailyAllowance =
            monthDaysLeft > 0 ? monthRemaining / monthDaysLeft : 0.0;

        final yearTotal = budgetEntry.annualTotal;
        final yearRemaining = yearTotal - yearUsed;
        final yearStart = DateTime(today.year, 1, 1);
        final yearEnd = DateTime(today.year, 12, 31);
        final yearToday = today.isBefore(yearStart)
            ? yearStart
            : (today.isAfter(yearEnd) ? yearEnd : today);
        final totalYearDays = yearEnd.difference(yearStart).inDays + 1;
        final elapsedYearDays = yearToday.difference(yearStart).inDays + 1;
        final usedPercent = yearTotal > 0 ? (yearUsed / yearTotal * 100) : 0.0;
        final timePercent =
            totalYearDays > 0 ? (elapsedYearDays / totalYearDays * 100) : 0.0;
        final usageAheadOfTime = usedPercent > timePercent + 10.0;

        final card = Padding(
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
                Text(
                  AppStrings.homeBudgetTitle,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                SegmentedButton<_HomeBudgetView>(
                  segments: const [
                    ButtonSegment(
                      value: _HomeBudgetView.month,
                      label: Text(AppStrings.homeBudgetViewMonth),
                    ),
                    ButtonSegment(
                      value: _HomeBudgetView.year,
                      label: Text(AppStrings.homeBudgetViewYear),
                    ),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    _onViewChanged(value.first);
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openBudgetPage(context, _view),
                child: Text(
                  AppStrings.homeBudgetDetail,
                  style: tt.labelLarge?.copyWith(color: cs.primary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_view == _HomeBudgetView.month)
              _buildMonthView(
                context: context,
                cs: cs,
                total: monthTotal,
                used: monthUsed,
                remaining: monthRemaining,
                daysLeft: monthDaysLeft,
                dailyAllowance: monthDailyAllowance,
              )
            else
              _buildYearView(
                context: context,
                cs: cs,
                total: yearTotal,
                used: yearUsed,
                remaining: yearRemaining,
                usedPercent: usedPercent,
                timePercent: timePercent,
                usageAheadOfTime: usageAheadOfTime,
              ),
          ],
        ),
      ),
    );
        if (!showLoadingOverlay) return card;
        return Stack(
          children: [
            card,
            const Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthView({
    required BuildContext context,
    required ColorScheme cs,
    required double total,
    required double used,
    required double remaining,
    required int daysLeft,
    required double dailyAllowance,
  }) {
    final tt = Theme.of(context).textTheme;
    if (total <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: cs.onSurface.withOpacity(0.75),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.homeBudgetMonthlyEmptyTitle,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.homeBudgetMonthlyEmptyDesc,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openBudgetPage(context, _HomeBudgetView.month),
            child: const Text(AppStrings.homeBudgetMonthlyEmptyAction),
          ),
        ],
      );
    }

    final remainingColor =
        remaining >= 0 ? AppColors.success : AppColors.danger;
    final usedPercent = total > 0 ? (used / total * 100) : 0.0;
    final isWarning = usedPercent >= 80;
    final isDanger = usedPercent >= 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.homeBudgetMonthTitle,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isWarning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDanger 
                      ? AppColors.danger.withOpacity(0.1)
                      : cs.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDanger ? Icons.warning : Icons.info_outline,
                      size: 14,
                      color: isDanger ? AppColors.danger : cs.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDanger ? '已超支' : '预算预警',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDanger ? AppColors.danger : cs.secondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '剩余 ¥${remaining.toStringAsFixed(0)}',
          style: tt.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: remainingColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.homeBudgetUsedAndTotal(used, total),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              '已用 ${usedPercent.toStringAsFixed(1)}%',
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isWarning
                    ? (isDanger ? AppColors.danger : cs.secondary)
                    : cs.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BudgetProgress(total: total, used: used),
        if (daysLeft > 0 && remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppStrings.homeBudgetTodaySuggestion(
                      daysLeft,
                      dailyAllowance,
                    ),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                if (isWarning)
                  Text(
                    isDanger 
                        ? '建议控制支出'
                        : '建议合理规划',
                    style: tt.bodySmall?.copyWith(
                      color: isDanger ? AppColors.danger : cs.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        if (isDanger && daysLeft > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本月预算已超支，剩余${daysLeft}天建议控制支出',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.danger,
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

  Widget _buildYearView({
    required BuildContext context,
    required ColorScheme cs,
    required double total,
    required double used,
    required double remaining,
    required double usedPercent,
    required double timePercent,
    required bool usageAheadOfTime,
  }) {
    final tt = Theme.of(context).textTheme;
    if (total <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: cs.onSurface.withOpacity(0.75),
              ),
              const SizedBox(width: 8),
          Text(
            AppStrings.homeBudgetYearlyEmptyTitle,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.homeBudgetYearlyEmptyDesc,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openBudgetPage(context, _HomeBudgetView.year),
            child: const Text(AppStrings.homeBudgetYearlyEmptyAction),
          ),
        ],
      );
    }

    final remainingLabel = remaining >= 0
        ? '年度剩余 ¥${remaining.toStringAsFixed(0)}'
        : '年度超支 ¥${remaining.abs().toStringAsFixed(0)}';
    final remainingColor =
        remaining >= 0 ? AppColors.success : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.homeBudgetYearTitle,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          remainingLabel,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: remainingColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.homeBudgetUsedAndTotal(used, total),
          style: tt.bodySmall?.copyWith(
            color: cs.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        BudgetProgress(
          total: total,
          used: used,
          totalLabel: AppStrings.yearBudget,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.homeBudgetUsageVsTime(usedPercent, timePercent),
          style: tt.bodySmall?.copyWith(
            color: usageAheadOfTime
                ? AppColors.danger
                : cs.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _BudgetUsedData {
  const _BudgetUsedData({
    required this.monthUsed,
    required this.yearUsed,
  });

  final double monthUsed;
  final double yearUsed;
}

// ignore: unused_element
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
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: tt.bodyMedium?.copyWith(
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

enum _HomeBudgetView {
  month,
  year,
}
