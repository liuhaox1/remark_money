import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';

class WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const WeeklyCalendar({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateUtilsX.daysInWeek(selectedDay);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          _buildWeekLabels(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final bool isSelected = DateUtilsX.isSameDay(d, selectedDay);
              final bool isToday = DateUtilsX.isToday(d);

              return _buildDayItem(
                context,
                date: d,
                selected: isSelected,
                today: isToday,
                onTap: () => onDaySelected(d),
                colorScheme: cs,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekLabels() {
    const labels = AppStrings.weekdayShort;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (e) => SizedBox(
              width: 44,
              child: Center(
                child: Text(
                  e,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayItem(
    BuildContext context, {
    required DateTime date,
    required bool selected,
    required bool today,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final bgColor =
        selected ? colorScheme.primary.withOpacity(0.15) : Colors.transparent;

    final textColor = selected
        ? colorScheme.primary
        : today
            ? AppColors.primary(context)
            : AppColors.textMain;

    return SizedBox(
      width: 44,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
