// Helper widgets for the HomePage date bottom sheet.
// Split into its own file to keep home_page.dart readable.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/date_utils.dart';
import '../providers/record_provider.dart';
import '../providers/book_provider.dart';

class DatePanel extends StatefulWidget {
  const DatePanel({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;

  @override
  State<DatePanel> createState() => _DatePanelState();
}

class _DatePanelState extends State<DatePanel>
    with SingleTickerProviderStateMixin {
  late DateTime _localSelectedDay = widget.selectedDay;
  late int _monthYear = widget.selectedDay.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weekday = DateUtilsX.weekdayShort(_localSelectedDay);

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${DateUtilsX.ymd(_localSelectedDay)}  周$weekday',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              indicatorColor: cs.primary,
              labelColor: cs.primary,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              tabs: const [
                Tab(text: '日'),
                Tab(text: '月'),
                Tab(text: '年'),
              ],
            ),
            SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  _buildDayTab(context),
                  _buildMonthTab(context),
                  _buildYearTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTab(BuildContext context) {
    final recordProvider = context.watch<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;
    return _DayNetGrid(
      baseDate: _localSelectedDay,
      bookId: bookId,
      recordProvider: recordProvider,
      onSelectDay: (day) {
        setState(() => _localSelectedDay = day);
        widget.onDayChanged(day);
      },
    );
  }

  Widget _buildMonthTab(BuildContext context) {
    final recordProvider = context.watch<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _monthYear--);
              },
            ),
            Text(
              '$_monthYear 年',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _monthYear++);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _MonthNetGrid(
            year: _monthYear,
            bookId: bookId,
            recordProvider: recordProvider,
            onSelectMonth: (month) {
              final newDay = DateTime(_monthYear, month, 1);
              setState(() => _localSelectedDay = newDay);
              widget.onDayChanged(newDay);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearTab(BuildContext context) {
    final initialYear = _localSelectedDay.year;
    final years = DateUtilsX.yearRange(past: 4, future: 4);
    return YearPicker(
      firstDate: DateTime(years.first, 1),
      lastDate: DateTime(years.last, 12),
      selectedDate: DateTime(initialYear, 1),
      onChanged: (date) {
        final newDay = DateTime(date.year, _localSelectedDay.month, 1);
        setState(() => _localSelectedDay = newDay);
        widget.onDayChanged(newDay);
      },
    );
  }
}

class _DayNetGrid extends StatelessWidget {
  const _DayNetGrid({
    required this.baseDate,
    required this.bookId,
    required this.recordProvider,
    required this.onSelectDay,
  });

  final DateTime baseDate;
  final String bookId;
  final RecordProvider recordProvider;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final days = DateUtilsX.daysInMonth(baseDate);
    final firstWeekday = days.first.weekday % 7;
    final items = <Widget>[];

    for (int i = 0; i < firstWeekday; i++) {
      items.add(const SizedBox.shrink());
    }
    for (final day in days) {
      final income = recordProvider.dayIncome(bookId, day);
      final expense = recordProvider.dayExpense(bookId, day);
      final net = income - expense;
      final hasData = recordProvider.recordsForDay(bookId, day).isNotEmpty;
      final disabled = day.isAfter(DateTime.now());
      items.add(_DayCell(
        day: day,
        net: net,
        hasData: hasData,
        disabled: disabled,
        selected: DateUtilsX.isSameDay(day, baseDate),
        onTap: () => onSelectDay(day),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${baseDate.year}年${baseDate.month}月收益日历',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 0.9,
            children: items,
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.net,
    required this.hasData,
    required this.disabled,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final double net;
  final bool hasData;
  final bool disabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (net > 0) {
      color = Colors.green.shade600;
    } else if (net < 0) {
      color = _lossColor(-net);
    } else {
      color = Colors.grey.shade500;
    }
    final effectiveColor = disabled ? Colors.grey.shade400 : color;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade200
              : selected
                  ? effectiveColor.withOpacity(0.18)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? effectiveColor : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (hasData)
              Text(
                net > 0
                    ? '+${net.toStringAsFixed(2)}'
                    : net < 0
                        ? net.toStringAsFixed(2)
                        : '0.00',
                style: TextStyle(
                  fontSize: 11,
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthNetGrid extends StatelessWidget {
  const _MonthNetGrid({
    required this.year,
    required this.bookId,
    required this.recordProvider,
    required this.onSelectMonth,
  });

  final int year;
  final String bookId;
  final RecordProvider recordProvider;
  final ValueChanged<int> onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) => i + 1);

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.4,
      children: months.map((month) {
        final monthRecords =
            recordProvider.recordsForMonth(bookId, year, month);
        double income = 0;
        double expense = 0;
        for (final record in monthRecords) {
          if (record.isIncome) {
            income += record.incomeValue;
          } else {
            expense += record.expenseValue;
          }
        }
        final net = income - expense;
        final hasData = monthRecords.isNotEmpty;
        final disabled = DateTime(year, month, 1).isAfter(DateTime.now());

        Color color;
        if (net > 0) {
          color = Colors.green.shade600;
        } else if (net < 0) {
          color = _lossColor(-net);
        } else {
          color = Theme.of(context).colorScheme.outline;
        }
        final showNet = hasData || net != 0;

        return InkWell(
          onTap: disabled ? null : () => onSelectMonth(month),
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: disabled ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: disabled
                    ? Colors.grey.shade300
                    : color.withOpacity(0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                if (showNet)
                  Text(
                    net > 0
                        ? '+${net.toStringAsFixed(2)}'
                        : net < 0
                            ? net.toStringAsFixed(2)
                            : '0.00',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

Color _lossColor(double amount) {
  if (amount <= 0) return Colors.amber.shade600;
  if (amount < 50) return Colors.amber.shade600;
  if (amount < 200) return Colors.orange.shade700;
  if (amount < 500) return Colors.red.shade400;
  return Colors.red.shade800;
}
