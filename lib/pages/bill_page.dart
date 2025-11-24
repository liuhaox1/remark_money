import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/utils/date_utils.dart';

import '../l10n/app_strings.dart';
import '../theme/app_tokens.dart';

class BillPage extends StatefulWidget {
  const BillPage({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialShowYearMode,
  });

  final int? initialYear;
  final DateTime? initialMonth;
  final bool? initialShowYearMode;

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late bool showYearMode;

  late int _selectedYear;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    showYearMode = widget.initialShowYearMode ?? true;
    _selectedMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    _selectedYear = widget.initialYear ?? _selectedMonth.year;
    if (showYearMode && widget.initialYear != null) {
      _selectedYear = widget.initialYear!;
    }
  }

  void _pickYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, 1, 1),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
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
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
      helpText: AppStrings.pickMonth,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
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
      body: Column(
        children: [
          const SizedBox(height: 12),

          // -----------------------------------
          // 🔘 年度 / 月度 Segmented Button
          // -----------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text(AppStrings.yearlyBill)),
                ButtonSegment(
                    value: false, label: Text(AppStrings.monthlyBill)),
              ],
              selected: {showYearMode},
              onSelectionChanged: (s) => setState(() => showYearMode = s.first),
            ),
          ),

          const SizedBox(height: 12),

          // -----------------------------------
          // 🔘 年份 / 月份选择按钮
          // -----------------------------------
          if (showYearMode)
            FilledButton.tonal(
              onPressed: _pickYear,
              child: Text(AppStrings.yearLabel(_selectedYear)),
            )
          else
            FilledButton.tonal(
              onPressed: _pickMonth,
              child: Text(AppStrings.selectMonthLabel(_selectedMonth)),
            ),

          const SizedBox(height: 12),

          Expanded(
            child: showYearMode
                ? _buildYearBill(context, cs, bookId)
                : _buildMonthBill(context, cs, bookId),
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
