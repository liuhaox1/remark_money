import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';

Color _amountTextColor(double value) {
  if (value > 0) return AppColors.success;
  if (value < 0) return AppColors.danger;
  return AppColors.zero;
}

Color _positiveBgColor() => AppColors.success.withOpacity(0.08);
Color _negativeBgColor() => AppColors.danger.withOpacity(0.08);

TextStyle _summaryTextStyle(Color color) {
  return TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

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
  late DateTime _selectedDay = widget.selectedDay;
  late int _currentYear = widget.selectedDay.year;
  late int _currentMonth = widget.selectedDay.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weekday = DateUtilsX.weekdayShort(_selectedDay);

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
                color: cs.outlineVariant.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${DateUtilsX.ymd(_selectedDay)}  $weekday',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              indicatorColor: cs.primary,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withOpacity(0.65),
              tabs: const [
                Tab(text: AppStrings.tabMonth),
                Tab(text: AppStrings.tabWeek),
                Tab(text: AppStrings.tabYear),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  _buildDayTab(context),
                  _buildWeekTab(context),
                  _buildMonthTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSelectedDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _currentYear = day.year;
      _currentMonth = day.month;
    });
    widget.onDayChanged(day);
  }

  Future<void> _showYearPicker() async {
    final nowYear = DateTime.now().year;
    final years = List<int>.generate(21, (i) => nowYear - 10 + i);
    int tempYear = _currentYear;
    final controller = FixedExtentScrollController(
      initialItem: years.indexOf(_currentYear).clamp(0, years.length - 1),
    );

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppStrings.buttonCancel,
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                    Text(
                      AppStrings.datePickerTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, tempYear),
                      child: Text(
                        AppStrings.buttonOk,
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    tempYear = years[index];
                  },
                  children: years
                      .asMap()
                      .entries
                      .map(
                        (entry) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            controller.animateToItem(
                              entry.key,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                            tempYear = entry.value;
                          },
                          child: Center(
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 18,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _currentYear) {
      setState(() {
        _currentYear = selected;
        _updateSelectedDay(
          DateTime(selected, _selectedDay.month, _selectedDay.day),
        );
      });
    }
  }

  Future<void> _showMonthPicker() async {
    final now = DateTime.now();
    final years = List<int>.generate(21, (i) => now.year - 10 + i);
    final months = List<int>.generate(12, (i) => i + 1);
    int tempYear = _currentYear;
    int tempMonth = _currentMonth;

    final yearController = FixedExtentScrollController(
      initialItem: years.indexOf(_currentYear).clamp(0, years.length - 1),
    );
    final monthController =
        FixedExtentScrollController(initialItem: _currentMonth - 1);

    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppStrings.buttonCancel,
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                    Text(
                      AppStrings.datePickerTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, [tempYear, tempMonth]),
                      child: Text(
                        AppStrings.buttonOk,
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: yearController,
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempYear = years[index];
                        },
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
                                child: Center(
                                  child: Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: monthController,
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempMonth = months[index];
                        },
                        children: months
                            .asMap()
                            .entries
                            .map(
                              (entry) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  monthController.animateToItem(
                                    entry.key,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  tempMonth = entry.value;
                                },
                                child: Center(
                                  child: Text(
                                    entry.value.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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

    if (selected != null &&
        (selected[0] != _currentYear || selected[1] != _currentMonth)) {
      setState(() {
        _currentYear = selected[0];
        _currentMonth = selected[1];
        _updateSelectedDay(DateTime(_currentYear, _currentMonth, 1));
      });
    }
  }

  Widget _buildDayTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;
    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final days = DateUtilsX.daysInMonth(monthStart);

    final items = <Widget>[];
    final firstWeekday = days.first.weekday % 7;
    for (int i = 0; i < firstWeekday; i++) {
      items.add(const SizedBox.shrink());
    }
    for (final day in days) {
      final income = recordProvider.dayIncome(bookId, day);
      final expense = recordProvider.dayExpense(bookId, day);
      final net = income - expense;
      final hasData = recordProvider.recordsForDay(bookId, day).isNotEmpty;
      final disabled = day.isAfter(DateTime.now());

      items.add(
        _DayCell(
          day: day,
          net: net,
          hasData: hasData,
          disabled: disabled,
          selected: DateUtilsX.isSameDay(day, _selectedDay),
          onTap: () => _updateSelectedDay(day),
        ),
      );
    }

    final weekdayLabels = [
      '\u65e5',
      '\u4e00',
      '\u4e8c',
      '\u4e09',
      '\u56db',
      '\u4e94',
      '\u516d',
    ];
    final monthLabel = _currentMonth.toString().padLeft(2, '0');
    final monthIncome = recordProvider.monthIncome(monthStart, bookId);
    final monthExpense = recordProvider.monthExpense(monthStart, bookId);
    final monthNet = monthIncome - monthExpense;
    final netColor = _amountTextColor(monthNet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$monthLabel\u6708\u7ed3\u4f59\uff1a${_NumberFormatter.format(monthNet)}',
              style: _summaryTextStyle(netColor),
            ),
            OutlinedButton(
              onPressed: _showMonthPicker,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: cs.primary),
                foregroundColor: cs.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentYear-${_currentMonth.toString().padLeft(2, '0')}',
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: weekdayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
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

  Widget _buildWeekTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;

    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final days = DateUtilsX.daysInMonth(monthStart);

    final Map<DateTime, List<DateTime>> weekMap = {};
    for (final day in days) {
      final weekStart =
          DateTime(day.year, day.month, day.day - (day.weekday - 1));
      weekMap.putIfAbsent(weekStart, () => <DateTime>[]).add(day);
    }

    final weeks = weekMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final monthLabel = _currentMonth.toString().padLeft(2, '0');
    final monthIncome = recordProvider.monthIncome(monthStart, bookId);
    final monthExpense = recordProvider.monthExpense(monthStart, bookId);
    final monthNet = monthIncome - monthExpense;
    final monthColor = _amountTextColor(monthNet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$monthLabel${AppStrings.monthSummary}：${_NumberFormatter.format(monthNet)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: monthColor,
              ),
            ),
            OutlinedButton(
              onPressed: _showMonthPicker,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: cs.primary),
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentYear-${_currentMonth.toString().padLeft(2, '0')}',
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (weeks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(AppStrings.noDataThisMonth),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: weeks.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (context, index) {
                final entry = weeks[index];
                final weekDays = entry.value..sort();

                final firstDay = weekDays.first;
                final lastDay = weekDays.last;

                double income = 0;
                double expense = 0;
                for (final d in weekDays) {
                  income += recordProvider.dayIncome(bookId, d);
                  expense += recordProvider.dayExpense(bookId, d);
                }
                final net = income - expense;

                final isCurrentWeek = weekDays.any(
                  (d) => DateUtilsX.isSameDay(d, _selectedDay),
                );

                final title = AppStrings.monthRangeTitle(
                  index,
                  firstDay.day,
                  lastDay.day,
                );

                final netColor = _amountTextColor(net);

                return ListTile(
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isCurrentWeek ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  trailing: Text(
                    _NumberFormatter.format(net),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: netColor,
                    ),
                  ),
                  onTap: () => _updateSelectedDay(firstDay),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMonthTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;

    double totalNet = 0;
    for (int m = 1; m <= 12; m++) {
      final monthDate = DateTime(_currentYear, m, 1);
      totalNet += recordProvider.monthIncome(monthDate, bookId) -
          recordProvider.monthExpense(monthDate, bookId);
    }

    final yearSummaryText = '$_currentYear${AppStrings.annualSummary}：'
        '${totalNet.toStringAsFixed(2)}';
    final yearSummaryColor = _amountTextColor(totalNet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              yearSummaryText,
              style: _summaryTextStyle(yearSummaryColor),
            ),
            OutlinedButton(
              onPressed: _showYearPicker,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: cs.primary),
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_currentYear'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _MonthNetGrid(
            year: _currentYear,
            bookId: bookId,
            recordProvider: recordProvider,
            onSelectMonth: (month) {
              _updateSelectedDay(DateTime(_currentYear, month, 1));
            },
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
    final cs = Theme.of(context).colorScheme;

    Color bg = cs.surfaceVariant.withOpacity(0.35);
    Color dayColor = cs.onSurface;
    Color amountColor = cs.onSurface.withOpacity(0.7);

    if (selected) {
      bg = cs.primary.withOpacity(0.12);
      dayColor = cs.primary;
      amountColor = cs.primary;
    } else if (net > 0) {
      bg = _positiveBgColor();
      dayColor = cs.onSurface;
      amountColor = AppColors.success;
    } else if (net < 0) {
      bg = _negativeBgColor();
      dayColor = cs.onSurface;
      amountColor = AppColors.danger;
    } else if (hasData) {
      bg = cs.surfaceVariant.withOpacity(0.35);
      dayColor = cs.onSurface;
      amountColor = cs.onSurface.withOpacity(0.7);
    }

    if (disabled) {
      bg = cs.surfaceVariant.withOpacity(0.6);
      dayColor = cs.onSurface.withOpacity(0.4);
      amountColor = cs.onSurface.withOpacity(0.35);
    }

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dayColor,
              ),
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
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                ),
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
    final cs = Theme.of(context).colorScheme;
    final months = List.generate(12, (i) => i + 1);

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.0,
      children: months.map((month) {
        final monthDate = DateTime(year, month, 1);
        final income = recordProvider.monthIncome(monthDate, bookId);
        final expense = recordProvider.monthExpense(monthDate, bookId);
        final net = income - expense;
        final hasData = recordProvider
            .recordsForMonth(bookId, monthDate.year, monthDate.month)
            .isNotEmpty;

        Color tileColor = cs.surfaceVariant.withOpacity(0.35);
        if (net > 0) {
          tileColor = _positiveBgColor();
        } else if (net < 0) {
          tileColor = _negativeBgColor();
        }

        final disabled = monthDate.isAfter(DateTime.now());

        return InkWell(
          onTap: disabled ? null : () => onSelectMonth(month),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(
              color: disabled ? cs.surfaceVariant.withOpacity(0.5) : tileColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: disabled
                    ? cs.outlineVariant.withOpacity(0.5)
                    : cs.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasData)
                  Text(
                    net.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _amountTextColor(net),
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

class _NumberFormatter {
  static String format(double value) {
    final absValue = value.abs();
    if (absValue >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    } else if (absValue >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    } else {
      return value.toStringAsFixed(2);
    }
  }
}
