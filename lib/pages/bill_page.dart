import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/utils/date_utils.dart';

import '../l10n/app_strings.dart';
import '../models/period_type.dart';
import '../theme/app_tokens.dart';
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
        actions: const [
          BookSelectorButton(compact: true),
          SizedBox(width: 8),
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

  // ======================================================
  // 📘 年度账单（展示 12 个月收入/支出/结余）
  // ======================================================
  Widget _buildYearBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final months = DateUtilsX.monthsInYear(_selectedYear);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: months.length,
      itemBuilder: (_, index) {
        final m = months[index];

        final income = recordProvider.monthIncome(m, bookId);
        final expense = recordProvider.monthExpense(m, bookId);
        final balance = income - expense;

        return _billCard(
          title: AppStrings.monthLabel(m.month),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
        );
      },
    );
  }

  Widget _buildWeekBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final days =
        List.generate(7, (i) => _selectedWeek.start.add(Duration(days: i)));
    double totalIncome = 0;
    double totalExpense = 0;
    for (final d in days) {
      totalIncome += recordProvider.dayIncome(bookId, d);
      totalExpense += recordProvider.dayExpense(bookId, d);
    }
    final items = <Widget>[
      _billCard(
        title: DateUtilsX.weekLabel(_weekNumberForWeek(_selectedWeek.start)),
        subtitle: AppStrings.weekRangeLabel(_selectedWeek),
        income: totalIncome,
        expense: totalExpense,
        balance: totalIncome - totalExpense,
        cs: cs,
      ),
    ];

    for (final d in days) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);
      final balance = income - expense;
      items.add(
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

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: days.length,
      itemBuilder: (_, index) {
        final d = days[index];

        final income = recordProvider.dayIncome(bookId, d);
        final expense = recordProvider.dayExpense(bookId, d);
        final balance = income - expense;

        return _billCard(
          title: AppStrings.monthDayLabel(d.month, d.day),
          income: income,
          expense: expense,
          balance: balance,
          cs: cs,
        );
      },
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
          // ----------------- 标题 -----------------
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
          const SizedBox(height: 10),

          // ----------------- 收入 / 支出 -----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _line(AppStrings.income, income, AppColors.success),
              _line(AppStrings.expense, expense, AppColors.danger),
              _line(
                AppStrings.balance,
                balance,
                AppColors.amount(balance),
              ),
            ],
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
