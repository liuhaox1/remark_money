import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

/// 周日历组件
/// 作用：
/// - 显示一周（周日 → 周六）
/// - 点击某一天时高亮
/// - 回调 onDaySelected
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

  /// 周标题（"日 一 二 三 四 五 六"）
  Widget _buildWeekLabels() {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
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
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// 每个日期格子
  Widget _buildDayItem(
    BuildContext context, {
    required DateTime date,
    required bool selected,
    required bool today,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final bgColor = selected
        ? colorScheme.primary.withOpacity(0.15)
        : Colors.transparent;

    final textColor = selected
        ? colorScheme.primary
        : today
            ? Colors.teal
            : Colors.black87;

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
              "${date.day}",
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
