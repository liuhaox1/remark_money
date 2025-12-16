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
          _buildWeekLabels(context),
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

  Widget _buildWeekLabels(BuildContext context) {
    const labels = AppStrings.weekdayShort;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (e) => SizedBox(
              width: 44,
              child: Center(
                child: Text(
                  e,
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.65),
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
    final tt = Theme.of(context).textTheme;

    final textColor = selected
        ? colorScheme.primary
        : today
            ? AppColors.primary(context)
            : colorScheme.onSurface;

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
              style: tt.titleSmall?.copyWith(
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
