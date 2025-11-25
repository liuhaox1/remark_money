import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../l10n/app_text_templates.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/period_type.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../widgets/chart_bar.dart';
import '../widgets/chart_pie.dart';
import '../widgets/book_selector_button.dart';
import 'bill_page.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.bookId,
    required this.year,
    this.month,
    this.weekRange,
    required this.periodType,
  });

  final String bookId;
  final int year;
  final int? month;
  final DateTimeRange? weekRange;
  final PeriodType periodType;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _showIncomeCategory = false;

  bool get _isYearMode => widget.periodType == PeriodType.year;
  bool get _isMonthMode => widget.periodType == PeriodType.month;
  bool get _isWeekMode => widget.periodType == PeriodType.week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;
    Book? targetBook;
    for (final book in bookProvider.books) {
      if (book.id == bookId) {
        targetBook = book;
        break;
      }
    }
    targetBook ??= bookProvider.activeBook;
    final bookName = targetBook?.name ?? AppStrings.defaultBook;

    final records = _periodRecords(recordProvider, bookId);
    final hasData = records.isNotEmpty;
    final income = _periodIncome(recordProvider, bookId, records);
    final expense = _periodExpense(recordProvider, bookId, records);
    final balance = income - expense;
    final comparison = _previousBalance(recordProvider, bookId);
    final balanceDiff =
        comparison.hasData ? balance - comparison.balance : null;
    final range = _periodRange();

    final expenseEntries = _buildCategoryEntries(
      records,
      categoryProvider,
      cs,
      isIncome: false,
    );
    final incomeEntries = _buildCategoryEntries(
      records,
      categoryProvider,
      cs,
      isIncome: true,
    );
    final distributionEntries =
        _showIncomeCategory ? incomeEntries : expenseEntries;
    final ranking = List<ChartEntry>.from(expenseEntries)
      ..sort((a, b) => b.value.compareTo(a.value));
    final dailyEntries =
        (_isMonthMode || _isWeekMode)
            ? _buildDailyEntries(recordProvider, bookId, cs)
            : <ChartEntry>[];
    final compareEntries =
        _buildRecentPeriodEntries(recordProvider, bookId, cs);

    final activity = _periodActivity(recordProvider, bookId);
    final totalExpenseValue =
        distributionEntries.fold<double>(0, (sum, e) => sum + e.value);
    final compareTitle =
        _isWeekMode ? '\u8fd1 6 \u5468\u5bf9\u6bd4' : AppStrings.recentMonthCompare;
    const emptyText = AppStrings.emptyPeriodRecords;
    String? weeklySummaryText;
    if (_isWeekMode && hasData) {
      final currentExpense = expense;
      final currentRange = range;
      final prevStart = DateUtilsX.startOfWeek(currentRange.start)
          .subtract(const Duration(days: 7));
      final prevEnd = prevStart.add(const Duration(days: 6));
      final prevExpense = recordProvider.periodExpense(
        bookId: bookId,
        start: prevStart,
        end: prevEnd,
      );
      final diff = currentExpense - prevExpense;
      final topCategory =
          expenseEntries.isNotEmpty ? expenseEntries.first.label : AppStrings.unknown;
      weeklySummaryText = AppTextTemplates.weeklySummary(
        expense: currentExpense,
        diff: diff,
        topCategory: topCategory,
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_appBarTitle(range)),
        actions: const [
          BookSelectorButton(compact: true),
          SizedBox(width: 8),
        ],
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
                    title: _headerTitle(range),
                    bookName: bookName,
                    range: range,
                    periodType: widget.periodType,
                    income: income,
                    expense: expense,
                    balance: balance,
                    balanceDiff: balanceDiff,
                    hasComparison: comparison.hasData,
                    hasData: hasData,
                    weeklySummaryText: weeklySummaryText,
                    onViewDetail: () =>
                        _openBillDetail(context, range, bookName),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: _showIncomeCategory
                        ? AppStrings.incomeDistribution
                        : AppStrings.expenseDistribution,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text(AppStrings.expense),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text(AppStrings.income),
                                ),
                              ],
                              selected: {_showIncomeCategory},
                              onSelectionChanged: (value) {
                                setState(() {
                                  _showIncomeCategory = value.first;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (distributionEntries.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                emptyText,
                                style: TextStyle(color: cs.outline),
                              ),
                            ),
                          )
                        else ...[
                          if (distributionEntries.length >= 2) ...[
                            SizedBox(
                              height: 260,
                              child: ChartPie(entries: distributionEntries),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppTextTemplates.chartCategoryDistributionDesc,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.outline,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else if (distributionEntries.length == 1) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                AppTextTemplates.singleCategoryFullSummary(
                                  label: distributionEntries.first.label,
                                  amount: distributionEntries.first.value,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.outline,
                                ),
                              ),
                            ),
                          ],
                          for (final entry in distributionEntries)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: entry.color,
                                      borderRadius: BorderRadius.circular(6),
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
                                    '${entry.value.toStringAsFixed(2)} (${(totalExpenseValue == 0 ? 0 : entry.value / totalExpenseValue * 100).toStringAsFixed(1)}%)',
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
                                emptyText,
                                style: TextStyle(color: cs.outline),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in ranking.take(5))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.label),
                                  trailing: Text(
                                    '${entry.value.toStringAsFixed(2)} (${(totalExpenseValue == 0 ? 0 : entry.value / totalExpenseValue * 100).toStringAsFixed(1)}%)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                AppTextTemplates.chartExpenseRankingDesc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.outline,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (dailyEntries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: AppStrings.dailyTrend,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 240,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: max(340, dailyEntries.length * 24),
                                child: ChartBar(entries: dailyEntries),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.chartDailyTrendDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (compareEntries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: compareTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 260,
                            child: ChartBar(entries: compareEntries),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.chartRecentCompareDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                        ],
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
                      onPressed: () => _openBillDetail(context, range, bookName),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text(AppTextTemplates.viewBillList),
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

  String _appBarTitle(DateTimeRange range) {
    if (_isWeekMode) {
      return DateUtilsX.weekLabel(_weekIndex(range.start));
    }
    if (_isMonthMode) {
      return AppStrings.monthReport;
    }
    return AppStrings.yearReport;
  }

  String _headerTitle(DateTimeRange range) {
    if (_isWeekMode) {
      return AppStrings.weekRangeLabel(range);
    }
    return AppStrings.periodBillTitle(widget.year, month: widget.month);
  }

  int _weekIndex(DateTime start) {
    final first = DateUtilsX.startOfWeek(DateTime(widget.year, 1, 1));
    final diff = start.difference(first).inDays;
    return (diff ~/ 7) + 1;
  }

  void _openBillDetail(
    BuildContext context,
    DateTimeRange range,
    String bookName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillPage(
          initialYear: widget.year,
          initialMonth: _isMonthMode
              ? DateTime(range.start.year, range.start.month, 1)
              : null,
          initialShowYearMode: _isYearMode,
          initialRange: _isWeekMode ? range : null,
          initialPeriodType: widget.periodType,
        ),
      ),
    );
  }

  List<Record> _periodRecords(
    RecordProvider recordProvider,
    String bookId,
  ) {
    final range = _periodRange();
    return recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
  }

  double _periodIncome(
    RecordProvider recordProvider,
    String bookId,
    List<Record> records,
  ) {
    if (_isYearMode) {
      double total = 0;
      for (var m = 1; m <= 12; m++) {
        total += recordProvider.monthIncome(
          DateTime(widget.year, m, 1),
          bookId,
        );
      }
      return total;
    }
    return records
        .where((r) => r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.incomeValue);
  }

  double _periodExpense(
    RecordProvider recordProvider,
    String bookId,
    List<Record> records,
  ) {
    if (_isYearMode) {
      double total = 0;
      for (var m = 1; m <= 12; m++) {
        total += recordProvider.monthExpense(
          DateTime(widget.year, m, 1),
          bookId,
        );
      }
      return total;
    }
    return records
        .where((r) => r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.expenseValue);
  }

  _PeriodComparison _previousBalance(
    RecordProvider recordProvider,
    String bookId,
  ) {
    if (_isYearMode) {
      final prevRange = DateTimeRange(
        start: DateTime(widget.year - 1, 1, 1),
        end: DateTime(widget.year - 1, 12, 31),
      );
      final records = recordProvider.recordsForPeriod(
        bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      final income = records
          .where((r) => r.isIncome)
          .fold<double>(0, (sum, r) => sum + r.incomeValue);
      final expense = records
          .where((r) => r.isExpense)
          .fold<double>(0, (sum, r) => sum + r.expenseValue);
      return _PeriodComparison(
        balance: income - expense,
        hasData: records.isNotEmpty,
      );
    }
    if (_isWeekMode) {
      final start = DateUtilsX.startOfWeek(_periodRange().start)
          .subtract(const Duration(days: 7));
      final prevRange = DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
      final records = recordProvider.recordsForPeriod(
        bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      final income = records
          .where((r) => r.isIncome)
          .fold<double>(0, (sum, r) => sum + r.incomeValue);
      final expense = records
          .where((r) => r.isExpense)
          .fold<double>(0, (sum, r) => sum + r.expenseValue);
      return _PeriodComparison(
        balance: income - expense,
        hasData: records.isNotEmpty,
      );
    }

    final currentMonth =
        DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final income = recordProvider.monthIncome(prevMonth, bookId);
    final expense = recordProvider.monthExpense(prevMonth, bookId);
    final hasData = recordProvider
        .recordsForMonth(bookId, prevMonth.year, prevMonth.month)
        .isNotEmpty;
    return _PeriodComparison(
      balance: income - expense,
      hasData: hasData,
    );
  }

  List<ChartEntry> _buildCategoryEntries(
    List<Record> records,
    CategoryProvider categoryProvider,
    ColorScheme cs, {
    required bool isIncome,
  }) {
    final Map<String, double> expenseMap = {};
    for (final record in records) {
      if (record.isIncome != isIncome) continue;
      final value = record.isIncome ? record.incomeValue : record.expenseValue;
      expenseMap[record.categoryKey] =
          (expenseMap[record.categoryKey] ?? 0) + value;
    }

    final categories = categoryProvider.categories;
    final palette = [
      const Color(0xFF3B82F6), // 蓝
      const Color(0xFFF59E0B), // 橙
      const Color(0xFF10B981), // 绿
      const Color(0xFFE11D48), // 红
      const Color(0xFF8B5CF6), // 紫
      const Color(0xFF06B6D4), // 青
      const Color(0xFF84CC16), // 黄绿
    ];
    var colorIndex = 0;
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
      final color = palette[colorIndex % palette.length];
      colorIndex++;
      entries.add(
        ChartEntry(
          label: category.name,
          value: entry.value,
          color: color,
        ),
      );
    }

    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<ChartEntry> _buildDailyEntries(
    RecordProvider recordProvider,
    String bookId,
    ColorScheme cs,
  ) {
    final range = _periodRange();
    final dayCount = range.end.difference(range.start).inDays + 1;
    final days = List.generate(
      dayCount,
      (i) => range.start.add(Duration(days: i)),
    );

    return days
        .map(
          (d) => ChartEntry(
            label: _isWeekMode ? '${d.month}/${d.day}' : d.day.toString(),
            value: recordProvider.dayExpense(bookId, d),
            color: cs.primary,
          ),
        )
        .toList();
  }

  List<ChartEntry> _buildRecentPeriodEntries(
    RecordProvider recordProvider,
    String bookId,
    ColorScheme cs,
  ) {
    final entries = <ChartEntry>[];

    if (_isWeekMode) {
      final base = DateUtilsX.startOfWeek(_periodRange().start);
      for (var i = 5; i >= 0; i--) {
        final start = base.subtract(Duration(days: 7 * i));
        final end = start.add(const Duration(days: 6));
        final expense = recordProvider.periodExpense(
          bookId: bookId,
          start: start,
          end: end,
        );
        entries.add(
          ChartEntry(
            label: 'W${_weekIndex(start)}',
            value: expense,
            color: cs.primary,
          ),
        );
      }
    } else if (_isMonthMode) {
      final baseMonth = DateTime(widget.year, widget.month ?? 12, 1);
      for (var i = 5; i >= 0; i--) {
        final month = DateTime(baseMonth.year, baseMonth.month - i, 1);
        final expense = recordProvider.monthExpense(month, bookId);
        entries.add(
          ChartEntry(
            label:
                '${month.year % 100}/${month.month.toString().padLeft(2, '0')}',
            value: expense,
            color: cs.primary,
          ),
        );
      }
    }
    return entries;
  }

  _PeriodActivity _periodActivity(
    RecordProvider recordProvider,
    String bookId,
  ) {
    final range = _periodRange();
    final records = recordProvider.recordsForPeriod(
      bookId,
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
    if (_isWeekMode) {
      if (widget.weekRange != null) return widget.weekRange!;
      final today = DateTime.now();
      final base = DateTime(widget.year, today.month, today.day);
      final range = DateUtilsX.weekRange(base);
      return DateTimeRange(start: range.start, end: range.end);
    }
    final start = DateTime(widget.year, widget.month ?? 1, 1);
    final end = _isYearMode
        ? DateTime(widget.year, 12, 31)
        : DateUtilsX.lastDayOfMonth(start);
    return DateTimeRange(start: start, end: end);
  }
}

class _PeriodHeaderCard extends StatelessWidget {
  const _PeriodHeaderCard({
    required this.cs,
    required this.isDark,
    required this.title,
    required this.bookName,
    required this.range,
    required this.periodType,
    required this.income,
    required this.expense,
    required this.balance,
    required this.balanceDiff,
    required this.hasComparison,
    required this.hasData,
    this.weeklySummaryText,
    required this.onViewDetail,
  });

  final ColorScheme cs;
  final bool isDark;
  final String title;
  final String bookName;
  final DateTimeRange range;
  final PeriodType periodType;
  final double income;
  final double expense;
  final double balance;
  final double? balanceDiff;
  final bool hasComparison;
    final bool hasData;
    final String? weeklySummaryText;
    final VoidCallback onViewDetail;
  
    @override
    Widget build(BuildContext context) {
      final conclusion = _buildConclusion();
      final bool useWeeklySummary =
          periodType == PeriodType.week && weeklySummaryText != null;
      // 副标题只展示当前账本，避免与 AppBar 和标题重复展示周期信息
      final subtitle = AppStrings.currentBookLabel(bookName);
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onViewDetail,
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text(AppTextTemplates.viewBillList),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.balance,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amount(balance),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      useWeeklySummary ? weeklySummaryText! : conclusion,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        label: AppStrings.income,
                        value: income,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryMetric(
                        label: AppStrings.expense,
                        value: expense,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildConclusion() {
    final periodName = periodType == PeriodType.year
        ? '\u672c\u5e74'
        : periodType == PeriodType.week
            ? '\u672c\u5468'
            : '\u672c\u6708';
    if (!hasData) {
      return AppStrings.emptyPeriodRecords;
    }
    if (!hasComparison || balanceDiff == null) {
      return AppStrings.previousPeriodNoData;
    }
    final verb = balanceDiff! >= 0 ? '\u7ed3\u4f59\u589e\u52a0' : '\u7ed3\u4f59\u51cf\u5c11';
    return '$periodName\u7ed3\u4f59 ${balance.toStringAsFixed(2)}\uff0c\u8f83\u4e0a\u4e00\u671f$verb ${balanceDiff!.abs().toStringAsFixed(2)}';
  }

  int _weekIndexForRange(DateTimeRange range) {
    final first =
        DateUtilsX.startOfWeek(DateTime(range.start.year, 1, 1));
    final diff = range.start.difference(first).inDays;
    return (diff ~/ 7) + 1;
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

  int _weekIndexForRange(DateTimeRange range) {
    final first =
        DateUtilsX.startOfWeek(DateTime(range.start.year, 1, 1));
    final diff = range.start.difference(first).inDays;
    return (diff ~/ 7) + 1;
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

class _PeriodComparison {
  _PeriodComparison({
    required this.balance,
    required this.hasData,
  });

  final double balance;
  final bool hasData;
}
