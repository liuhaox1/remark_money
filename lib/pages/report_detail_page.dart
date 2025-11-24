import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../widgets/chart_bar.dart';
import '../widgets/chart_pie.dart';
import 'bill_page.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.bookId,
    required this.year,
    this.month,
    required this.isYearMode,
  });

  final String bookId;
  final int year;
  final int? month;
  final bool isYearMode;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _showBarChart = true;

  bool get _isMonthMode => !widget.isYearMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    Book? targetBook;
    for (final book in bookProvider.books) {
      if (book.id == widget.bookId) {
        targetBook = book;
        break;
      }
    }
    targetBook ??= bookProvider.activeBook;
    final bookName = targetBook?.name ?? AppStrings.defaultBook;

    final income = _periodIncome(recordProvider);
    final expense = _periodExpense(recordProvider);
    final balance = income - expense;
    final prevBalance = _previousBalance(recordProvider);
    final balanceDiff = balance - prevBalance;

    final expenseEntries = _buildExpenseEntries(
      recordProvider,
      categoryProvider,
      cs,
    );
    final ranking = List<ChartEntry>.from(expenseEntries)
      ..sort((a, b) => b.value.compareTo(a.value));
    final dailyEntries =
        _isMonthMode ? _buildDailyEntries(recordProvider, cs) : <ChartEntry>[];
    final monthCompareEntries = _buildRecentMonthEntries(recordProvider, cs);

    final activity = _periodActivity(recordProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          AppStrings.periodBillTitle(
            widget.year,
            month: widget.month,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                children: [
                  _PeriodHeaderCard(
                    cs: cs,
                    isDark: isDark,
                    bookName: bookName,
                    year: widget.year,
                    month: widget.month,
                    income: income,
                    expense: expense,
                    balance: balance,
                    balanceDiff: balanceDiff,
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: AppStrings.expenseDistribution,
                    trailing: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.bar_chart),
                          label: Text(AppStrings.chartBar),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.pie_chart),
                          label: Text(AppStrings.chartPie),
                        ),
                      ],
                      selected: {_showBarChart},
                      onSelectionChanged: (value) {
                        setState(() => _showBarChart = value.first);
                      },
                    ),
                    child: expenseEntries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                _isMonthMode
                                    ? AppStrings.noMonthData
                                    : AppStrings.noYearData,
                                style: TextStyle(color: cs.outline),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 260,
                                child: _showBarChart
                                    ? ChartBar(entries: expenseEntries)
                                    : ChartPie(entries: expenseEntries),
                              ),
                              const SizedBox(height: 12),
                              for (final entry in ranking)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: entry.color,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry.label,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        entry.value.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: AppStrings.expenseRanking,
                    child: ranking.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                _isMonthMode
                                    ? AppStrings.noMonthData
                                    : AppStrings.noYearData,
                                style: TextStyle(color: cs.outline),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (final entry in ranking.take(5))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.label),
                                  trailing: Text(
                                    entry.value.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (dailyEntries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: AppStrings.dailyTrend,
                      child: SizedBox(
                        height: 240,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: max(340, dailyEntries.length * 24),
                            child: ChartBar(entries: dailyEntries),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (monthCompareEntries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: AppStrings.recentMonthCompare,
                      child: SizedBox(
                        height: 260,
                        child: ChartBar(entries: monthCompareEntries),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: AppStrings.reportAchievements,
                    child: Column(
                      children: [
                        _AchievementRow(
                          label: AppStrings.recordCount,
                          value: activity.recordCount.toString(),
                        ),
                        const SizedBox(height: 6),
                        _AchievementRow(
                          label: AppStrings.activeDays,
                          value: activity.activeDays.toString(),
                        ),
                        const SizedBox(height: 6),
                        _AchievementRow(
                          label: AppStrings.streakDays,
                          value: activity.streak.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BillPage(
                              initialYear: widget.year,
                              initialMonth: widget.month != null
                                  ? DateTime(widget.year, widget.month!, 1)
                                  : null,
                              initialShowYearMode: widget.isYearMode,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text(AppStrings.viewPeriodDetail),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _periodIncome(RecordProvider recordProvider) {
    if (widget.isYearMode) {
      double total = 0;
      for (var m = 1; m <= 12; m++) {
        total += recordProvider.monthIncome(
          DateTime(widget.year, m, 1),
          widget.bookId,
        );
      }
      return total;
    }
    final date = DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    return recordProvider.monthIncome(date, widget.bookId);
  }

  double _periodExpense(RecordProvider recordProvider) {
    if (widget.isYearMode) {
      double total = 0;
      for (var m = 1; m <= 12; m++) {
        total += recordProvider.monthExpense(
          DateTime(widget.year, m, 1),
          widget.bookId,
        );
      }
      return total;
    }
    final date = DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    return recordProvider.monthExpense(date, widget.bookId);
  }

  double _previousBalance(RecordProvider recordProvider) {
    if (widget.isYearMode) {
      final prevYearIncome = _sumYear(
        recordProvider,
        widget.year - 1,
        recordProvider.monthIncome,
      );
      final prevYearExpense = _sumYear(
        recordProvider,
        widget.year - 1,
        recordProvider.monthExpense,
      );
      return prevYearIncome - prevYearExpense;
    }
    final currentMonth =
        DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final income = recordProvider.monthIncome(prevMonth, widget.bookId);
    final expense = recordProvider.monthExpense(prevMonth, widget.bookId);
    return income - expense;
  }

  double _sumYear(
    RecordProvider recordProvider,
    int year,
    double Function(DateTime, String) getter,
  ) {
    double total = 0;
    for (var m = 1; m <= 12; m++) {
      total += getter(DateTime(year, m, 1), widget.bookId);
    }
    return total;
  }

  List<ChartEntry> _buildExpenseEntries(
    RecordProvider recordProvider,
    CategoryProvider categoryProvider,
    ColorScheme cs,
  ) {
    final range = _periodRange();
    final records = recordProvider.recordsForPeriod(
      widget.bookId,
      start: range.start,
      end: range.end,
    );

    final Map<String, double> expenseMap = {};
    for (final record in records) {
      if (record.isIncome) continue;
      expenseMap[record.categoryKey] =
          (expenseMap[record.categoryKey] ?? 0) + record.expenseValue;
    }

    final categories = categoryProvider.categories;
    final entries = <ChartEntry>[];
    for (final entry in expenseMap.entries) {
      final category = categories.firstWhere(
        (c) => c.key == entry.key,
        orElse: () => Category(
          key: entry.key,
          name: entry.key,
          icon: Icons.category_outlined,
          isExpense: true,
        ),
      );
      entries.add(
        ChartEntry(
          label: category.name,
          value: entry.value,
          color: cs.primary,
        ),
      );
    }

    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<ChartEntry> _buildDailyEntries(
    RecordProvider recordProvider,
    ColorScheme cs,
  ) {
    final targetMonth =
        DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    final days = DateUtilsX.daysInMonth(targetMonth);

    return days
        .map(
          (d) => ChartEntry(
            label: d.day.toString(),
            value: recordProvider.dayExpense(widget.bookId, d),
            color: cs.primary,
          ),
        )
        .toList();
  }

  List<ChartEntry> _buildRecentMonthEntries(
    RecordProvider recordProvider,
    ColorScheme cs,
  ) {
    final baseMonth = DateTime(widget.year, widget.month ?? 12, 1);
    final entries = <ChartEntry>[];

    for (var i = 5; i >= 0; i--) {
      final month = DateTime(baseMonth.year, baseMonth.month - i, 1);
      final expense = recordProvider.monthExpense(month, widget.bookId);
      entries.add(
        ChartEntry(
          label:
              '${month.year % 100}/${month.month.toString().padLeft(2, '0')}',
          value: expense,
          color: cs.primary,
        ),
      );
    }
    return entries;
  }

  _PeriodActivity _periodActivity(RecordProvider recordProvider) {
    final range = _periodRange();
    final records = recordProvider.recordsForPeriod(
      widget.bookId,
      start: range.start,
      end: range.end,
    );
    final activeDays = <String>{};
    for (final record in records) {
      activeDays.add(DateUtilsX.ymd(record.date));
    }
    // 连续天数：简化为活动天数
    return _PeriodActivity(
      recordCount: records.length,
      activeDays: activeDays.length,
      streak: activeDays.length,
    );
  }

  DateTimeRange _periodRange() {
    final start = DateTime(widget.year, widget.month ?? 1, 1);
    final end = widget.isYearMode
        ? DateTime(widget.year, 12, 31)
        : DateUtilsX.lastDayOfMonth(start);
    return DateTimeRange(start: start, end: end);
  }
}

class _PeriodHeaderCard extends StatelessWidget {
  const _PeriodHeaderCard({
    required this.cs,
    required this.isDark,
    required this.bookName,
    required this.year,
    this.month,
    required this.income,
    required this.expense,
    required this.balance,
    required this.balanceDiff,
  });

  final ColorScheme cs;
  final bool isDark;
  final String bookName;
  final int year;
  final int? month;
  final double income;
  final double expense;
  final double balance;
  final double balanceDiff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.primary.withOpacity(0.18),
                  Colors.white,
                ],
              ),
        color: isDark ? cs.surface : null,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            AppStrings.periodBillTitle(year, month: month),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.currentBookLabel(bookName),
            style: TextStyle(
              fontSize: 12,
              color: cs.outline,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: AppStrings.balance,
                  value: balance,
                  color: AppColors.amount(balance),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: AppStrings.income,
                  value: income,
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: AppStrings.expense,
                  value: expense,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                balanceDiff >= 0 ? Icons.trending_up : Icons.trending_down,
                color: balanceDiff >= 0 ? AppColors.success : AppColors.danger,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${AppStrings.previousPeriod} ${balanceDiff >= 0 ? '+' : ''}${balanceDiff.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      balanceDiff >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            DefaultTextStyle(
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PeriodActivity {
  _PeriodActivity({
    required this.recordCount,
    required this.activeDays,
    required this.streak,
  });

  final int recordCount;
  final int activeDays;
  final int streak;
}
