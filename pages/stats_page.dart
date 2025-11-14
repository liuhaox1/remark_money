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

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          if (bookProvider.books.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: bookId,
                items: bookProvider.books
                    .map(
                      (book) => DropdownMenuItem(
                        value: book.id,
                        child: Text(book.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) bookProvider.selectBook(value);
                },
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                _buildRangeControls(context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!_viewYear)
                      FilledButton.tonal(
                        onPressed: _pickMonth,
                        child:
                            Text('${_selectedMonth.year}年${_selectedMonth.month}月'),
                      )
                    else
                      DropdownButton<int>(
                        value: _selectedYear,
                        items: DateUtilsX.yearRange(past: 4, future: 1)
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text('$year 年'),
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
                            value: true,
                            icon: Icon(Icons.bar_chart),
                            label: Text('柱状')),
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.pie_chart),
                            label: Text('饼图')),
                      ],
                      selected: {_showBarChart},
                      onSelectionChanged: (s) =>
                          setState(() => _showBarChart = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: chartEntries.isEmpty
                      ? Center(
                          child: Text(
                            _viewYear ? '该年无支出数据' : '本月无支出数据',
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
      ),
    );
  }

  Widget _buildRangeControls(BuildContext context) {
    return SegmentedButton<bool>(
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

    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c
    };

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
