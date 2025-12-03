import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/period_type.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/period_selector.dart';
import 'add_record_page.dart';
import 'bill_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int _selectedYear = DateTime.now().year;
  PeriodType _periodType = PeriodType.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;
    final bookName = bookProvider.activeBook?.name ?? AppStrings.defaultBook;
    final now = DateTime.now();
    final isCurrentYear = now.year == _selectedYear;

    final months = DateUtilsX.monthsInYear(_selectedYear);
    final monthSummaries = months
        .map(
          (m) => _MonthSummary(
            month: m.month,
            income: recordProvider.monthIncome(m, bookId),
            expense: recordProvider.monthExpense(m, bookId),
            recordCount: recordProvider
                .recordsForMonth(bookId, m.year, m.month)
                .length,
            isCurrentMonth: isCurrentYear && m.month == now.month,
          ),
        )
        .toList();
    final visibleMonths = monthSummaries
        .where((m) => m.hasRecords || m.isCurrentMonth)
        .toList();

    final weekSummaries =
        _buildWeekSummaries(recordProvider, bookId, _selectedYear);

    final yearIncome =
        monthSummaries.fold<double>(0, (sum, item) => sum + item.income);
    final yearExpense =
        monthSummaries.fold<double>(0, (sum, item) => sum + item.expense);
    final yearBalance = yearIncome - yearExpense;
    final hasYearRecords = recordProvider
        .recordsForBook(bookId)
        .any((r) => r.date.year == _selectedYear);
    final totalRecordCount = recordProvider
        .recordsForBook(bookId)
        .where((r) => r.date.year == _selectedYear)
        .length;

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
                _HeaderCard(
                  isDark: isDark,
                  cs: cs,
                  bookName: bookName,
                  year: _selectedYear,
                  income: yearIncome,
                  expense: yearExpense,
                  balance: yearBalance,
                  periodType: _periodType,
                ),
                const SizedBox(height: 4),
                if (hasYearRecords)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${AppStrings.reportSummaryPrefix}$totalRecordCount'
                        '${AppStrings.reportSummaryMiddleRecords}'
                        '${yearExpense.toStringAsFixed(0)}'
                        '${AppStrings.reportSummarySuffixYuan}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.outline,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PeriodSelector(
                          label: AppStrings.yearLabel(_selectedYear),
                          periodType: PeriodType.year,
                          onTap: _pickYear,
                          onPrev: () => setState(() {
                            _selectedYear -= 1;
                          }),
                          onNext: () => setState(() {
                            _selectedYear += 1;
                          }),
                          compact: true,
                        ),
                        SegmentedButton<PeriodType>(
                          segments: const [
                            ButtonSegment(
                              value: PeriodType.week,
                              label: Text(AppStrings.weekReport),
                              icon: Icon(Icons.calendar_view_week),
                            ),
                            ButtonSegment(
                              value: PeriodType.month,
                              label: Text(AppStrings.monthReport),
                              icon: Icon(Icons.calendar_view_month),
                            ),
                            ButtonSegment(
                              value: PeriodType.year,
                              label: Text(AppStrings.yearReport),
                              icon: Icon(Icons.date_range),
                            ),
                          ],
                          selected: {_periodType},
                          onSelectionChanged: (value) {
                            setState(() => _periodType = value.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _PeriodList(
                      year: _selectedYear,
                      cs: cs,
                      periodType: _periodType,
                      months: visibleMonths,
                      weeks: weekSummaries,
                      hasYearRecords: hasYearRecords,
                      onTapMonth: (month) => _openBillPage(
                        context,
                        bookId: bookId,
                        year: _selectedYear,
                        month: month,
                      ),
                      onTapYear: () => _openBillPage(
                        context,
                        bookId: bookId,
                        year: _selectedYear,
                      ),
                      onTapWeek: (range) => _openBillPage(
                        context,
                        bookId: bookId,
                        year: _selectedYear,
                        weekRange: range,
                      ),
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

  void _openBillPage(
    BuildContext context, {
    required String bookId,
    required int year,
    int? month,
    DateTimeRange? weekRange,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillPage(
          initialYear: year,
          initialMonth:
              month != null ? DateTime(year, month, 1) : null,
          initialRange: weekRange,
          initialPeriodType: weekRange != null
              ? PeriodType.week
              : month != null
                  ? PeriodType.month
                  : PeriodType.year,
        ),
      ),
    );
  }

  Future<void> _pickYear() async {
    final now = DateTime.now().year;
    final years = List<int>.generate(100, (i) => now - 80 + i); // 80年前到20年后
    final itemHeight = 52.0;
    final initialIndex = years.indexOf(now).clamp(0, years.length - 1);
    final controller = ScrollController(
      initialScrollOffset: itemHeight * initialIndex,
    );
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemExtent: itemHeight,
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final y = years[index];
                    return ListTile(
                      title: Text(AppStrings.yearLabel(y)),
                      trailing: y == _selectedYear
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => Navigator.pop(ctx, y),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _selectedYear = selected);
    }
  }

  List<_WeekSummary> _buildWeekSummaries(
    RecordProvider recordProvider,
    String bookId,
    int year,
  ) {
    final records = recordProvider
        .recordsForBook(bookId)
        .where((r) => r.date.year == year)
        .toList();

    final Map<DateTime, _WeekSummary> map = {};
    for (final record in records) {
      final start = DateUtilsX.startOfWeek(record.date);
      final range = DateUtilsX.weekRange(record.date);
      final summary = map.putIfAbsent(
        start,
        () => _WeekSummary(
          start: start,
          end: range.end,
          income: 0,
          expense: 0,
          recordCount: 0,
        ),
      );
      if (record.isIncome) {
        summary.income += record.incomeValue;
      } else {
        summary.expense += record.expenseValue;
      }
      summary.recordCount += 1;
    }

    final now = DateTime.now();
    final currentStart = DateUtilsX.startOfWeek(now);
    if (now.year == year && !map.containsKey(currentStart)) {
      final range = DateUtilsX.weekRange(now);
      map[currentStart] = _WeekSummary(
        start: currentStart,
        end: range.end,
        income: 0,
        expense: 0,
        recordCount: 0,
      );
    }

    final entries = map.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < entries.length; i++) {
      entries[i].weekIndex = i + 1;
    }

    entries.sort((a, b) => b.start.compareTo(a.start));
    return entries;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isDark,
    required this.cs,
    required this.bookName,
    required this.year,
    required this.income,
    required this.expense,
    required this.balance,
    required this.periodType,
  });

  final bool isDark;
  final ColorScheme cs;
  final String bookName;
  final int year;
  final double income;
  final double expense;
  final double balance;
  final PeriodType periodType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              children: [
                const Text(
                  AppStrings.reportOverview,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const BookSelectorButton(compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel(),
              style: TextStyle(
                fontSize: 13,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SummaryItem(
                  label: AppStrings.income,
                  value: income,
                  color: AppColors.success,
                ),
                _SummaryItem(
                  label: AppStrings.expense,
                  value: expense,
                  color: AppColors.danger,
                ),
                _SummaryItem(
                  label: AppStrings.balance,
                  value: balance,
                  color: AppColors.amount(balance),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.currentBookLabel(bookName),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel() {
    final yearLabel = AppStrings.yearLabel(year);
    switch (periodType) {
      case PeriodType.week:
        return '$yearLabel · 周账单';
      case PeriodType.month:
        return '$yearLabel · 月账单';
      case PeriodType.year:
        return '$yearLabel · 年度账单';
    }
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodList extends StatelessWidget {
  const _PeriodList({
    required this.year,
    required this.cs,
    required this.periodType,
    required this.months,
    required this.weeks,
    required this.hasYearRecords,
    required this.onTapMonth,
    required this.onTapYear,
    required this.onTapWeek,
  });

  final int year;
  final ColorScheme cs;
  final PeriodType periodType;
  final List<_MonthSummary> months;
  final List<_WeekSummary> weeks;
  final bool hasYearRecords;
  final ValueChanged<int> onTapMonth;
  final VoidCallback onTapYear;
  final ValueChanged<DateTimeRange> onTapWeek;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              '月份 / 周次',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.income,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.expense,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.balance,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    final children = <Widget>[header];

    if (!hasYearRecords && periodType != PeriodType.year) {
      children.add(_EmptyYearCard(cs: cs));
    }

    switch (periodType) {
      case PeriodType.year:
        if (!hasYearRecords) {
          children.add(_EmptyYearCard(cs: cs));
        } else {
          final income = months.fold<double>(0, (sum, m) => sum + m.income);
          final expense = months.fold<double>(0, (sum, m) => sum + m.expense);
          children.add(
            _PeriodTile(
              title: AppStrings.periodBillTitle(year),
              subtitle: '${AppStrings.yearLabel(year)} • ${AppStrings.yearReport}',
              income: income,
              expense: expense,
              balance: income - expense,
              cs: cs,
              hasData: true,
              highlight: true,
              tag: AppStrings.yearReport,
              onTap: onTapYear,
            ),
          );
        }
        break;
      case PeriodType.month:
        if (months.isEmpty) {
          if (hasYearRecords) {
            children.add(_EmptyYearCard(cs: cs));
          }
        } else {
          for (final m in months) {
            children.add(
              _PeriodTile(
                title: AppStrings.monthLabel(m.month),
                subtitle: AppStrings.yearMonthLabel(year, m.month),
                income: m.income,
                expense: m.expense,
                balance: m.balance,
                cs: cs,
                hasData: m.hasRecords,
                tag: m.isCurrentMonth ? '本月' : null,
                emptyHint: m.isCurrentMonth
                    ? AppStrings.currentMonthEmpty
                    : '无记录',
                highlight: m.isCurrentMonth || m.hasRecords,
                onTap: () => onTapMonth(m.month),
              ),
            );
          }
        }
        break;
      case PeriodType.week:
        if (weeks.isEmpty) {
          if (hasYearRecords) {
            children.add(_EmptyYearCard(cs: cs));
          }
        } else {
          for (final w in weeks) {
            final range = DateTimeRange(start: w.start, end: w.end);
            children.add(
              _PeriodTile(
                title: DateUtilsX.weekLabel(w.weekIndex),
                subtitle: AppStrings.weekRangeLabel(range),
                income: w.income,
                expense: w.expense,
                balance: w.balance,
                cs: cs,
                hasData: w.hasRecords,
                emptyHint: '无记录',
                tag: w.isCurrentWeek ? '本周' : null,
                highlight: w.isCurrentWeek || w.hasRecords,
                onTap: () => onTapWeek(range),
              ),
            );
          }
        }
        break;
    }

    return ListView(children: children);
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.title,
    this.subtitle,
    required this.income,
    required this.expense,
    required this.balance,
    required this.cs,
    required this.onTap,
    this.highlight = false,
    this.hasData = true,
    this.emptyHint,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final double income;
  final double expense;
  final double balance;
  final ColorScheme cs;
  final VoidCallback onTap;
  final bool highlight;
  final bool hasData;
  final String? emptyHint;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final accentColor = highlight ? cs.primary : cs.outlineVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.outlineVariant.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 60,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  hasData
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _AmountLabel(
                              label: AppStrings.income,
                              value: income,
                              color: AppColors.success,
                            ),
                            _AmountLabel(
                              label: AppStrings.expense,
                              value: expense,
                              color: AppColors.danger,
                            ),
                            _AmountLabel(
                              label: AppStrings.balance,
                              value: balance,
                              color: AppColors.amount(balance),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            emptyHint ?? '无记录',
                            style: TextStyle(
                              color: cs.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MonthSummary {
  _MonthSummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.recordCount,
    required this.isCurrentMonth,
  });

  final int month;
  final double income;
  final double expense;
  final int recordCount;
  final bool isCurrentMonth;

  bool get hasRecords => recordCount > 0;
  double get balance => income - expense;
}

class _WeekSummary {
  _WeekSummary({
    required this.start,
    required this.end,
    required this.income,
    required this.expense,
    required this.recordCount,
    this.weekIndex = 1,
  });

  final DateTime start;
  final DateTime end;
  double income;
  double expense;
  int recordCount;
  int weekIndex;

  bool get hasRecords => recordCount > 0;
  bool get isCurrentWeek {
    final now = DateTime.now();
    final currentRange = DateUtilsX.weekRange(now);
    return DateUtilsX.isSameDay(currentRange.start, start);
  }

  double get balance => income - expense;
}

class _EmptyYearCard extends StatelessWidget {
  const _EmptyYearCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.emptyYearRecords,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddRecordPage(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.goRecord),
          ),
        ],
      ),
    );
  }
}
