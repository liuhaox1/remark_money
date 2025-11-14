import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.onSelected,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final today = DateTime.now();
    final current = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final weekStart = DateUtilsX.startOfWeek(current);

    final days = List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      final isSelected = DateUtilsX.isSameDay(day, current);
      final isToday = DateUtilsX.isToday(day);
      final isFuture = day.isAfter(DateTime(
        today.year,
        today.month,
        today.day,
      ));

      Color bg;
      Color fg;
      if (isSelected) {
        bg = cs.primary;
        fg = cs.onPrimary;
      } else if (isFuture) {
        bg = Colors.transparent;
        fg = cs.onSurface.withOpacity(0.25);
      } else {
        bg = Colors.transparent;
        fg = cs.onSurface.withOpacity(isDark ? 0.7 : 0.6);
      }

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isFuture ? null : () => onSelected(day),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateUtilsX.weekdayShort(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withOpacity(isToday && !isSelected ? 0.8 : 1),
                      fontWeight: isToday || isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: fg,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days,
      ),
    );
  }
}
