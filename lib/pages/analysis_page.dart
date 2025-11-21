import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/chart_bar.dart';
import '../widgets/chart_pie.dart';
import 'bill_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedYear = DateTime.now().year;
  bool _viewYear = false;
  bool _showBarChart = true;
  bool _showChartView = true; // true: 图表, false: 账单

  @override
  Widget build(BuildContext context) {
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;

    final chartEntries = _viewYear
        ? _buildYearEntries(recordProvider, bookId)
        : _buildMonthEntries(
            recordProvider,
            categoryProvider,
            bookId,
          );

    final totalExpense =
        chartEntries.fold<double>(0, (sum, e) => sum + e.value);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                    child: Row(
                      children: [
                        const Text(
                          AppStrings.stats,
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
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRangeControls(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (!_viewYear)
                                      FilledButton.tonal(
                                        onPressed: _pickMonth,
                                        child: Text(
                                          AppStrings.yearMonthLabel(
                                            _selectedMonth.year,
                                            _selectedMonth.month,
                                          ),
                                        ),
                                      )
                                    else
                                      DropdownButton<int>(
                                        value: _selectedYear,
                                        items: DateUtilsX.yearRange(
                                          past: 4,
                                          future: 1,
                                        )
                                            .map(
                                              (year) => DropdownMenuItem(
                                                value: year,
                                                child:
                                                    Text(AppStrings.yearLabel(year)),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(
                                              () => _selectedYear = value,
                                            );
                                          }
                                        },
                                      ),
                                    const Spacer(),
                                    SegmentedButton<bool>(
                                      style: const ButtonStyle(
                                        visualDensity: VisualDensity.standard,
                                        padding: MaterialStatePropertyAll(
                                          EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        textStyle: MaterialStatePropertyAll(
                                          TextStyle(fontSize: 14),
                                        ),
                                      ),
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
                                      onSelectionChanged: (s) => setState(
                                        () => _showBarChart = s.first,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 图表 / 账单 视图切换
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('图表'),
                                icon: Icon(Icons.insights_outlined),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('账单'),
                                icon: Icon(Icons.receipt_long),
                              ),
                            ],
                            selected: {_showChartView},
                            onSelectionChanged: (value) {
                              setState(() => _showChartView = value.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_showChartView) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _viewYear
                                  ? AppStrings.yearExpenseTotal(
                                      _selectedYear,
                                      totalExpense,
                                    )
                                  : AppStrings.monthExpenseTotal(
                                      _selectedMonth.year,
                                      _selectedMonth.month,
                                      totalExpense,
                                    ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: chartEntries.isEmpty
                                ? Center(
                                    child: Text(
                                      _viewYear
                                          ? AppStrings.noYearData
                                          : AppStrings.noMonthData,
                                      style: TextStyle(color: cs.outline),
                                    ),
                                  )
                                : _showBarChart
                                    ? ChartBar(entries: chartEntries)
                                    : ChartPie(entries: chartEntries),
                          ),
                        ] else ...[
                          // 账单视图：复用 BillPage 的构建逻辑
                          Expanded(
                            child: BillPage(
                              key: ValueKey(
                                'bill-${_viewYear ? 'year' : 'month'}-$_selectedYear-${_selectedMonth.month}',
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildRangeControls() {
    return SegmentedButton<bool>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.standard,
        padding: MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        textStyle: MaterialStatePropertyAll(
          TextStyle(fontSize: 14),
        ),
      ),
      segments: const [
        ButtonSegment(value: false, label: Text(AppStrings.viewByMonth)),
        ButtonSegment(value: true, label: Text(AppStrings.viewByYear)),
      ],
      selected: {_viewYear},
      onSelectionChanged: (value) {
        setState(() => _viewYear = value.first);
      },
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      helpText: AppStrings.pickMonth,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  List<ChartEntry> _buildMonthEntries(
    RecordProvider recordProvider,
    CategoryProvider categoryProvider,
    String bookId,
  ) {
    final records = recordProvider.recordsForMonth(
      bookId,
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final Map<String, double> expenseMap = {};
    for (final record in records) {
      if (!record.isExpense) continue;
      expenseMap[record.categoryKey] =
          (expenseMap[record.categoryKey] ?? 0) + record.expenseValue;
    }

    final categories = categoryProvider.categories;
    final cs = Theme.of(context).colorScheme;
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

  List<ChartEntry> _buildYearEntries(
    RecordProvider recordProvider,
    String bookId,
  ) {
    final entries = <ChartEntry>[];
    for (int month = 1; month <= 12; month++) {
      final date = DateTime(_selectedYear, month, 1);
      final expense = recordProvider.monthExpense(date, bookId);
      if (expense <= 0) continue;
      entries.add(
        ChartEntry(
          label: AppStrings.monthLabel(month),
          value: expense,
          color: Colors.blueAccent,
        ),
      );
    }
    return entries;
  }
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({
    required this.bookProvider,
  });

  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final activeName =
        bookProvider.activeBook?.name ?? AppStrings.defaultBook;

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
