import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<DateTime?> showYmdDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime minDate,
  required DateTime maxDate,
  String title = '选择日期',
}) async {
  final clampedInitial = initialDate.isBefore(minDate)
      ? minDate
      : (initialDate.isAfter(maxDate) ? maxDate : initialDate);

  final startYear = minDate.year;
  final endYear = maxDate.year;

  int tempYear = clampedInitial.year.clamp(startYear, endYear);
  int tempMonth = clampedInitial.month;
  int tempDay = clampedInitial.day;

  final years = List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
  final months = List<int>.generate(12, (i) => i + 1);
  final days = List<int>.generate(31, (i) => i + 1);

  int yearIndex = years.indexOf(tempYear);
  int monthIndex = tempMonth - 1;
  int dayIndex = tempDay - 1;

  final yearController = FixedExtentScrollController(initialItem: yearIndex);
  final monthController = FixedExtentScrollController(initialItem: monthIndex);
  final dayController = FixedExtentScrollController(initialItem: dayIndex);

  DateTime clampToBounds(DateTime value) {
    if (value.isBefore(minDate)) return DateTime(minDate.year, minDate.month, minDate.day);
    if (value.isAfter(maxDate)) return DateTime(maxDate.year, maxDate.month, maxDate.day);
    return value;
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SizedBox(
        height: 260,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final lastDayOfMonth = DateTime(tempYear, tempMonth + 1, 0).day;
                      if (tempDay > lastDayOfMonth) tempDay = lastDayOfMonth;

                      final picked = clampToBounds(DateTime(tempYear, tempMonth, tempDay));
                      Navigator.pop(ctx, picked);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: yearController,
                      itemExtent: 32,
                      onSelectedItemChanged: (index) => tempYear = years[index],
                      children: years
                          .asMap()
                          .entries
                          .map(
                            (entry) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                yearController.animateToItem(
                                  entry.key,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                                tempYear = entry.value;
                              },
                              child: Center(child: Text('${entry.value}年')),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: monthController,
                      itemExtent: 32,
                      onSelectedItemChanged: (index) => tempMonth = months[index],
                      children: months
                          .asMap()
                          .entries
                          .map(
                            (entry) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                monthController.animateToItem(
                                  entry.key,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                                tempMonth = entry.value;
                              },
                              child: Center(child: Text(entry.value.toString().padLeft(2, '0'))),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: dayController,
                      itemExtent: 32,
                      onSelectedItemChanged: (index) => tempDay = days[index],
                      children: days
                          .asMap()
                          .entries
                          .map(
                            (entry) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                dayController.animateToItem(
                                  entry.key,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                                tempDay = entry.value;
                              },
                              child: Center(child: Text(entry.value.toString().padLeft(2, '0'))),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

