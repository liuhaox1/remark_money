// Helper widgets for the HomePage date bottom sheet.
// Split into its own file to keep home_page.dart readable.

import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

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
    final initial = _localSelectedDay;
    final first = DateTime(initial.year - 2, 1, 1);
    final last = DateTime(initial.year + 2, 12, 31);
    return CalendarDatePicker(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      onDateChanged: (day) {
        setState(() => _localSelectedDay = day);
        widget.onDayChanged(day);
      },
    );
  }

  Widget _buildMonthTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: List.generate(12, (index) {
              final month = index + 1;
              final isSelected = _localSelectedDay.year == _monthYear &&
                  _localSelectedDay.month == month;
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      isSelected ? cs.primary.withOpacity(0.12) : null,
                  side: BorderSide(
                    color: isSelected
                        ? cs.primary
                        : cs.outline.withOpacity(0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  final newDay = DateTime(_monthYear, month, 1);
                  setState(() => _localSelectedDay = newDay);
                  widget.onDayChanged(newDay);
                },
                child: Text('$month 月'),
              );
            }),
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

