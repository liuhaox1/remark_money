import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/chart_bar.dart';
import '../widgets/chart_pie.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedYear = DateTime.now().year;
  bool _viewYear = false;
  bool _showBarChart = true;

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
                          '统计',
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
                                _buildRangeControls(context),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (!_viewYear)
                                      FilledButton.tonal(
                                        onPressed: _pickMonth,
                                        child: Text(
                                          '${_selectedMonth.year}年${_selectedMonth.month}月',
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
                                                child: Text('$year 年'),
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
                                          label: Text('柱状图'),
                                        ),
                                        ButtonSegment(
                                          value: false,
                                          icon: Icon(Icons.pie_chart),
                                          label: Text('饼图'),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _viewYear
                                ? '$_selectedYear 年支出合计：${totalExpense.toStringAsFixed(2)}'
                                : '${_selectedMonth.year}年${_selectedMonth.month}月支出合计：${totalExpense.toStringAsFixed(2)}',
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
                                    _viewYear ? '该年无支出记录' : '本月无支出记录',
                                    style: TextStyle(color: cs.outline),
                                  ),
                                )
                              : _showBarChart
                                  ? ChartBar(entries: chartEntries)
                                  : ChartPie(entries: chartEntries),
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

  Widget _buildRangeControls(BuildContext context) {
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
        ButtonSegment(value: false, label: Text('按月')),
        ButtonSegment(value: true, label: Text('按年')),
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
      helpText: '选择月份',
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

    final categoryMap = {for (final c in categoryProvider.categories) c.key: c};

    final sortedEntries = expenseMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chartEntries = <ChartEntry>[];
    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final category = categoryMap[entry.key];
      chartEntries.add(
        ChartEntry(
          label: category?.name ?? '未分类',
          value: entry.value,
          color: _colorForIndex(entry.key.hashCode + i),
        ),
      );
    }
    return chartEntries;
  }

  List<ChartEntry> _buildYearEntries(
    RecordProvider recordProvider,
    String bookId,
  ) {
    final records = recordProvider.recordsForBook(bookId).where(
          (record) => record.date.year == _selectedYear && record.isExpense,
        );
    final Map<int, double> monthExpense = {};
    for (final record in records) {
      monthExpense[record.date.month] =
          (monthExpense[record.date.month] ?? 0) + record.expenseValue;
    }

    final entries = monthExpense.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return [
      for (var entry in entries)
        ChartEntry(
          label: '${entry.key}月',
          value: entry.value,
          color: _colorForIndex(entry.key),
        ),
    ];
  }

  Color _colorForIndex(int seed) {
    const palette = Colors.primaries;
    return palette[seed.abs() % palette.length];
  }
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({required this.bookProvider});

  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeName = bookProvider.activeBook?.name ?? '默认账本';
    return InkWell(
      onTap: () => _showBookPicker(context),
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? cs.surface : Colors.white,
          border: Border.all(color: cs.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    final books = bookProvider.books;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '选择账本',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...books.map(
                  (book) => RadioListTile<String>(
                    value: book.id,
                    groupValue: bookProvider.activeBookId,
                    onChanged: (value) {
                      if (value != null) {
                        bookProvider.selectBook(value);
                        Navigator.pop(ctx);
                      }
                    },
                    title: Text(book.name),
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
