import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import 'report_detail_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int _selectedYear = DateTime.now().year;
  bool _viewYearReport = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;
    final bookName = bookProvider.activeBook?.name ?? AppStrings.defaultBook;

    final months = DateUtilsX.monthsInYear(_selectedYear);
    final monthSummaries = months
        .map(
          (m) => _MonthSummary(
            month: m.month,
            income: recordProvider.monthIncome(m, bookId),
            expense: recordProvider.monthExpense(m, bookId),
          ),
        )
        .toList();

    final yearIncome =
        monthSummaries.fold<double>(0, (sum, item) => sum + item.income);
    final yearExpense =
        monthSummaries.fold<double>(0, (sum, item) => sum + item.expense);
    final yearBalance = yearIncome - yearExpense;

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
                  bookProvider: bookProvider,
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        DropdownButton<int>(
                          value: _selectedYear,
                          items: DateUtilsX.yearRange(past: 4, future: 1)
                              .map(
                                (year) => DropdownMenuItem(
                                  value: year,
                                  child: Text(AppStrings.yearLabel(year)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedYear = value);
                            }
                          },
                        ),
                        const Spacer(),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text(AppStrings.monthReport),
                              icon: Icon(Icons.calendar_view_month),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(AppStrings.yearReport),
                              icon: Icon(Icons.date_range),
                            ),
                          ],
                          selected: {_viewYearReport},
                          onSelectionChanged: (value) {
                            setState(() => _viewYearReport = value.first);
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
                    child: _MonthList(
                      year: _selectedYear,
                      summaries: monthSummaries,
                      cs: cs,
                      viewYearReport: _viewYearReport,
                      onTapMonth: (month) => _openReportDetail(
                        context,
                        bookId: bookId,
                        year: _selectedYear,
                        month: month,
                        isYearMode: false,
                      ),
                      onTapYear: () => _openReportDetail(
                        context,
                        bookId: bookId,
                        year: _selectedYear,
                        isYearMode: true,
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

  void _openReportDetail(
    BuildContext context, {
    required String bookId,
    required int year,
    int? month,
    required bool isYearMode,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailPage(
          bookId: bookId,
          year: year,
          month: month,
          isYearMode: isYearMode,
        ),
      ),
    );
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
    required this.bookProvider,
  });

  final bool isDark;
  final ColorScheme cs;
  final String bookName;
  final int year;
  final double income;
  final double expense;
  final double balance;
  final BookProvider bookProvider;

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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: _BookSelector(bookProvider: bookProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.yearLabel(year),
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

class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.year,
    required this.summaries,
    required this.cs,
    required this.viewYearReport,
    required this.onTapMonth,
    required this.onTapYear,
  });

  final int year;
  final List<_MonthSummary> summaries;
  final ColorScheme cs;
  final bool viewYearReport;
  final ValueChanged<int> onTapMonth;
  final VoidCallback onTapYear;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (viewYearReport) {
      final income = summaries.fold<double>(0, (sum, m) => sum + m.income);
      final expense = summaries.fold<double>(0, (sum, m) => sum + m.expense);
      final balance = income - expense;
      items.add(
        _MonthTile(
          title: AppStrings.periodBillTitle(year),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
          onTap: onTapYear,
        ),
      );
    }

    for (final summary in summaries) {
      items.add(
        _MonthTile(
          title: AppStrings.monthLabel(summary.month),
          income: summary.income,
          expense: summary.expense,
          balance: summary.balance,
          cs: cs,
          onTap: () => onTapMonth(summary.month),
        ),
      );
    }

    return ListView(
      children: items,
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.title,
    required this.income,
    required this.expense,
    required this.balance,
    required this.cs,
    required this.onTap,
  });

  final String title;
  final double income;
  final double expense;
  final double balance;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
  });

  final int month;
  final double income;
  final double expense;

  double get balance => income - expense;
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({
    required this.bookProvider,
  });

  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final activeName = bookProvider.activeBook?.name ?? AppStrings.defaultBook;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: bookProvider.activeBookId,
        items: bookProvider.books
            .map(
              (b) => DropdownMenuItem(
                value: b.id,
                child: Text(b.name),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            bookProvider.selectBook(value);
          }
        },
        hint: Text(AppStrings.currentBookLabel(activeName)),
      ),
    );
  }
}
