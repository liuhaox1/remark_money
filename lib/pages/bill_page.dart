import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/providers/account_provider.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/utils/date_utils.dart';

import '../l10n/app_strings.dart';
import '../l10n/app_text_templates.dart';
import '../models/period_type.dart';
import '../theme/app_tokens.dart';
import '../utils/csv_utils.dart';
import '../utils/records_export_bundle.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/period_selector.dart';

class BillPage extends StatefulWidget {
  const BillPage({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialShowYearMode,
    this.initialRange,
    this.initialPeriodType,
  });

  final int? initialYear;
  final DateTime? initialMonth;
  final bool? initialShowYearMode;
  final DateTimeRange? initialRange;
  final PeriodType? initialPeriodType;

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late PeriodType _periodType;
  late int _selectedYear;
  late DateTime _selectedMonth;
  late DateTimeRange _selectedWeek;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodType = widget.initialPeriodType ??
        (widget.initialShowYearMode == true
            ? PeriodType.year
            : PeriodType.month);
    _selectedMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    _selectedYear = widget.initialYear ?? _selectedMonth.year;
    _selectedWeek = widget.initialRange ??
        DateUtilsX.weekRange(_selectedMonth);
    if (_periodType == PeriodType.week && widget.initialRange != null) {
      _selectedYear = widget.initialRange!.start.year;
      _selectedMonth = DateTime(
        widget.initialRange!.start.year,
        widget.initialRange!.start.month,
        1,
      );
    }
    if (_periodType == PeriodType.year && widget.initialYear != null) {
      _selectedYear = widget.initialYear!;
    }
  }

  void _pickYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, 1, 1),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickYear,
    );
    if (picked != null) {
      setState(() => _selectedYear = picked.year);
    }
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickMonth,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeek.start,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickWeek,
    );
    if (picked != null) {
      setState(() {
        _selectedWeek = DateUtilsX.weekRange(picked);
        _selectedYear = _selectedWeek.start.year;
        _selectedMonth =
            DateTime(_selectedWeek.start.year, _selectedWeek.start.month, 1);
      });
    }
  }

  Future<void> _pickPeriod() async {
    switch (_periodType) {
      case PeriodType.week:
        return _pickWeek();
      case PeriodType.month:
        return _pickMonth();
      case PeriodType.year:
        return _pickYear();
    }
  }

  String _periodLabel() {
    switch (_periodType) {
      case PeriodType.week:
        return AppStrings.weekRangeLabel(_selectedWeek);
      case PeriodType.month:
        return AppStrings.selectMonthLabel(_selectedMonth);
      case PeriodType.year:
        return AppStrings.yearLabel(_selectedYear);
    }
  }

  void _shiftPeriod(int delta) {
    setState(() {
      if (_periodType == PeriodType.year) {
        _selectedYear += delta;
        _selectedMonth = DateTime(_selectedYear, _selectedMonth.month, 1);
      } else if (_periodType == PeriodType.month) {
        _selectedMonth =
            DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
        _selectedYear = _selectedMonth.year;
      } else {
        final newStart =
            _selectedWeek.start.add(Duration(days: 7 * delta));
        _selectedWeek = DateUtilsX.weekRange(newStart);
        _selectedYear = _selectedWeek.start.year;
        _selectedMonth =
            DateTime(_selectedWeek.start.year, _selectedWeek.start.month, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.billTitle),
        actions: [
          const BookSelectorButton(compact: true),
          IconButton(
            tooltip: '导出数据',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _showExportMenu(context, bookId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // -----------------------------------
          // 🔘 周 / 月 / 年 Segmented Button
          // -----------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<PeriodType>(
              segments: const [
                ButtonSegment(
                  value: PeriodType.week,
                  label: Text(AppStrings.weeklyBill),
                ),
                ButtonSegment(
                  value: PeriodType.month,
                  label: Text(AppStrings.monthlyBill),
                ),
                ButtonSegment(
                  value: PeriodType.year,
                  label: Text(AppStrings.yearlyBill),
                ),
              ],
              selected: {_periodType},
              onSelectionChanged: (s) => setState(() {
                _periodType = s.first;
                if (_periodType == PeriodType.week) {
                  _selectedWeek = DateUtilsX.weekRange(_selectedMonth);
                } else if (_periodType == PeriodType.year) {
                  _selectedYear = _selectedMonth.year;
                }
              }),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PeriodSelector(
              label: _periodLabel(),
              periodType: _periodType,
              onPrev: () => _shiftPeriod(-1),
              onNext: () => _shiftPeriod(1),
              onTap: _pickPeriod,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _periodType == PeriodType.year
                ? _buildYearBill(context, cs, bookId)
                : _periodType == PeriodType.month
                    ? _buildMonthBill(context, cs, bookId)
                    : _buildWeekBill(context, cs, bookId),
          ),
        ],
      ),
    );
  }

  DateTimeRange _currentRange() {
    switch (_periodType) {
      case PeriodType.week:
        final start = DateTime(
          _selectedWeek.start.year,
          _selectedWeek.start.month,
          _selectedWeek.start.day,
        );
        final end = DateTime(
          _selectedWeek.end.year,
          _selectedWeek.end.month,
          _selectedWeek.end.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case PeriodType.month:
        final start = DateUtilsX.firstDayOfMonth(_selectedMonth);
        final end = DateUtilsX.lastDayOfMonth(_selectedMonth);
        final endWithTime = DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: endWithTime);
      case PeriodType.year:
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  Future<void> _showExportMenu(BuildContext context, String bookId) async {
    final range = _currentRange();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('导出 CSV（用于 Excel 查看）'),
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('导出 JSON（用于备份 / 迁移）'),
                onTap: () => Navigator.pop(ctx, 'json'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'csv') {
      await _exportCsv(context, bookId, range);
    } else if (choice == 'json') {
      await _exportJson(context, bookId, range);
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    String bookId,
    DateTimeRange range,
  ) async {
    final recordProvider = context.read<RecordProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final bookProvider = context.read<BookProvider>();
    final accountProvider = context.read<AccountProvider>();

    final records = recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前时间范围内暂无记录')),
        );
      }
      return;
    }

    final categoriesByKey = {
      for (final c in categoryProvider.categories) c.key: c.name,
    };
    final booksById = {
      for (final b in bookProvider.books) b.id: b.name,
    };

    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    final rows = <List<String>>[];
    rows.add([
      '日期',
      '金额',
      '收支方向',
      '分类',
      '账本',
      '账户',
      '备注',
      '是否计入统计',
    ]);

    for (final r in records) {
      final dateStr = formatter.format(r.date);
      final amountStr = r.amount.toStringAsFixed(2);
      final directionStr = r.isIncome ? '收入' : '支出';
      final categoryName =
          categoriesByKey[r.categoryKey] ?? r.categoryKey;
      final bookName = booksById[r.bookId] ?? bookProvider.activeBook?.name ??
          '默认账本';
      final accountName =
          accountProvider.byId(r.accountId)?.name ?? '未知账户';
      final remark = r.remark;
      final includeStr = r.includeInStats ? '是' : '否';

      rows.add([
        dateStr,
        amountStr,
        directionStr,
        categoryName,
        bookName,
        accountName,
        remark,
        includeStr,
      ]);
    }

    final csv = toCsv(rows);

    final dir = await getTemporaryDirectory();
    final fileName =
        'remark_records_${range.start.toIso8601String()}_${range.end.toIso8601String()}.csv';
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(csv, encoding: utf8);

    if (!context.mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '指尖记账导出 CSV',
      text: '指尖记账导出记录 CSV，可用 Excel 打开查看。',
    );
  }

  Future<void> _exportJson(
    BuildContext context,
    String bookId,
    DateTimeRange range,
  ) async {
    final recordProvider = context.read<RecordProvider>();

    final records = recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前时间范围内暂无记录')),
        );
      }
      return;
    }

    final bundle = RecordsExportBundle(
      version: 1,
      exportedAt: DateTime.now().toUtc(),
      type: 'records',
      bookId: bookId,
      start: range.start,
      end: range.end,
      records: records,
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'remark_records_${range.start.toIso8601String()}_${range.end.toIso8601String()}.json';
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(bundle.toJson(), encoding: utf8);

    if (!context.mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '指尖记账导出 JSON 备份',
      text: '指尖记账记录 JSON 备份，可用于导入或迁移。',
    );
  }

  // ======================================================
  // 📘 年度账单（展示 12 个月收入/支出/结余）
  // ======================================================
  Widget _buildYearBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final months = DateUtilsX.monthsInYear(_selectedYear);

    double totalIncome = 0;
    double totalExpense = 0;

    final monthItems = <Widget>[];
    for (final m in months) {
      final income = recordProvider.monthIncome(m, bookId);
      final expense = recordProvider.monthExpense(m, bookId);
      final balance = income - expense;

      totalIncome += income;
      totalExpense += expense;

      // 只展示有记账的月份，避免一整年全是 0.00 的行
      if (income == 0 && expense == 0) continue;

      monthItems.add(
        _billCard(
          title: AppStrings.monthLabel(m.month),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
        ),
      );
    }

    final items = <Widget>[];
    final totalBalance = totalIncome - totalExpense;

    // 年度小结
    items.add(
      _billCard(
        title: AppStrings.yearReport,
        subtitle:
            '本年收入 ${totalIncome.toStringAsFixed(2)} 元 · 支出 ${totalExpense.toStringAsFixed(2)} 元',
        income: totalIncome,
        expense: totalExpense,
        balance: totalBalance,
        cs: cs,
      ),
    );

    items.addAll(monthItems);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  Widget _buildWeekBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final days =
        List.generate(7, (i) => _selectedWeek.start.add(Duration(days: i)));
    double totalIncome = 0;
    double totalExpense = 0;
    int emptyDays = 0;

    final dayItems = <Widget>[];

    for (final d in days) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);

      totalIncome += income;
      totalExpense += expense;

      if (income == 0 && expense == 0) {
        emptyDays += 1;
        continue;
      }

      final balance = income - expense;
      dayItems.add(
        _billCard(
          title: AppStrings.monthDayLabel(d.month, d.day),
          subtitle: DateUtilsX.weekdayShort(d),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
        ),
      );
    }

    final subtitleParts = <String>[AppStrings.weekRangeLabel(_selectedWeek)];
    if (emptyDays > 0) {
      subtitleParts.add(AppTextTemplates.weekEmptyDaysHint(emptyDays));
    }

    final items = <Widget>[
      _billCard(
        title: DateUtilsX.weekLabel(_weekNumberForWeek(_selectedWeek.start)),
        subtitle: subtitleParts.join(' · '),
        income: totalIncome,
        expense: totalExpense,
        balance: totalIncome - totalExpense,
        cs: cs,
      ),
    ];

    items.addAll(dayItems);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  // ======================================================
  // 📕 月度账单（按天显示）
  // ======================================================
  Widget _buildMonthBill(BuildContext context, ColorScheme cs, String bookId) {
    final days = DateUtilsX.daysInMonth(_selectedMonth);
    final recordProvider = context.watch<RecordProvider>();
    double totalIncome = 0;
    double totalExpense = 0;
    double maxDailyExpense = 0;
    int recordedDays = 0;

    // 先统计整月概况，并记录哪些日期有记账
    final nonEmptyDays = <DateTime>[];
    for (final d in days) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);

      totalIncome += income;
      totalExpense += expense;

      if (income != 0 || expense != 0) {
        recordedDays += 1;
        nonEmptyDays.add(d);
      }
      if (expense > maxDailyExpense) {
        maxDailyExpense = expense;
      }
    }

    final totalDays = days.length;
    final avgExpense = totalDays > 0 ? totalExpense / totalDays : 0;
    final emptyDays = totalDays - recordedDays;

    final items = <Widget>[];

    // 顶部本月小结
    final subtitleParts = <String>[];
    subtitleParts.add(
        '本月支出 ${totalExpense.toStringAsFixed(2)} 元 · 日均 ${avgExpense.toStringAsFixed(2)} 元');
    subtitleParts.add('记账 $recordedDays 天');
    if (emptyDays > 0) {
      subtitleParts.add(AppTextTemplates.monthEmptyDaysHint(emptyDays));
    }
    if (maxDailyExpense > 0) {
      subtitleParts
          .add('单日最高支出 ${maxDailyExpense.toStringAsFixed(2)} 元');
    }

    items.add(
      _billCard(
        title: AppStrings.monthListTitle,
        subtitle: subtitleParts.join(' · '),
        income: totalIncome,
        expense: totalExpense,
        balance: totalIncome - totalExpense,
        cs: cs,
      ),
    );

    // 只展示有记账的日期，避免一长串全是 0.00
    for (final d in nonEmptyDays) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);
      final balance = income - expense;

      items.add(
        _billCard(
          title: AppStrings.monthDayLabel(d.month, d.day),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  // ======================================================
  // 📦 通用账单卡片
  // ======================================================
  Widget _billCard({
    required String title,
    String? subtitle,
    required double income,
    required double expense,
    required double balance,
    required ColorScheme cs,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.outlineVariant.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
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
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '本期收入 ${income.toStringAsFixed(2)} 元 · 支出 ${expense.toStringAsFixed(2)} 元 · 结余 ${balance.toStringAsFixed(2)} 元',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }

  int _weekNumberForWeek(DateTime start) {
    final first = DateUtilsX.startOfWeek(DateTime(start.year, 1, 1));
    final diff = start.difference(first).inDays;
    return (diff ~/ 7) + 1;
  }

  Widget _line(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        )
      ],
    );
  }
}
