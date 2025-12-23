
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/providers/account_provider.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/utils/date_utils.dart';

import '../l10n/app_strings.dart';
import '../l10n/app_text_templates.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/period_type.dart';
import '../models/record.dart';
import '../models/tag.dart';
import '../utils/csv_utils.dart';
import '../utils/error_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/period_selector.dart';
import '../widgets/timeline_item.dart';
import '../providers/tag_provider.dart';
import '../services/records_export_service.dart';
import 'add_record_page.dart';
import 'export_data_page.dart';
import 'report_detail_page.dart';

class BillPage extends StatefulWidget {
  const BillPage({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialShowYearMode,
    this.initialRange,
    this.initialPeriodType,
    this.initialStartDate,
    this.initialEndDate,
    this.dayMode = false,
    this.dayModeDate,
  });

  final int? initialYear;
  final DateTime? initialMonth;
  final bool? initialShowYearMode;
  final DateTimeRange? initialRange;
  final PeriodType? initialPeriodType;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final bool dayMode;
  final DateTime? dayModeDate;

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late PeriodType _periodType;
  late int _selectedYear;
  late DateTime _selectedMonth;
  late DateTimeRange _selectedWeek;

  String? _yearStatsKey;
  Future<List<Map<String, double>>>? _yearStatsFuture;
  List<Map<String, double>>? _yearStatsCache;

  String? _monthRecordsKey;
  Future<List<Record>>? _monthRecordsFuture;
  List<Record>? _monthRecordsCache;

  String? _weekRecordsKey;
  Future<List<Record>>? _weekRecordsFuture;
  List<Record>? _weekRecordsCache;

  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchKeyword = '';
  List<String> _searchHistory = <String>[];
  bool _showSuggestions = false;

  // 筛选相关
  Set<String> _filterCategoryKeys = {}; // 改为多选
  bool? _filterIncomeExpense; // null: 全部, true: 只看收入, false: 只看支出
  double? _minAmount;
  double? _maxAmount;
  Set<String> _filterAccountIds = <String>{};
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _loadSearchHistory();
    final now = DateTime.now();
    _periodType = widget.initialPeriodType ??
        (widget.initialShowYearMode == true
            ? PeriodType.year
            : PeriodType.month);
    
    // 限制初始月份不能超过当前月份
    DateTime initialMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    if (initialMonth.year > now.year || 
        (initialMonth.year == now.year && initialMonth.month > now.month)) {
      initialMonth = DateTime(now.year, now.month, 1);
    }
    _selectedMonth = initialMonth;
    
    // 限制初始年份不能超过当前年份
    int initialYear = widget.initialYear ?? _selectedMonth.year;
    if (initialYear > now.year) {
      initialYear = now.year;
    }
    _selectedYear = initialYear;
    
    // 限制初始周范围不能超过当前日期
    DateTimeRange? initialWeek = widget.initialRange;
    if (initialWeek != null && initialWeek.start.isAfter(now)) {
      initialWeek = DateUtilsX.weekRange(now);
    }
    _selectedWeek = initialWeek ?? DateUtilsX.weekRange(_selectedMonth);
    
    if (_periodType == PeriodType.week && widget.initialRange != null) {
      if (widget.initialRange!.start.isAfter(now)) {
        _selectedWeek = DateUtilsX.weekRange(now);
      }
      _selectedYear = _selectedWeek.start.year;
      _selectedMonth = DateTime(
        _selectedWeek.start.year,
        _selectedWeek.start.month,
        1,
      );
    }
    if (_periodType == PeriodType.year && widget.initialYear != null) {
      if (widget.initialYear! > now.year) {
        _selectedYear = now.year;
      } else {
      _selectedYear = widget.initialYear!;
      }
    }

    if (widget.initialStartDate != null || widget.initialEndDate != null) {
      _startDate = widget.initialStartDate;
      _endDate = widget.initialEndDate;
    }

    if (widget.dayMode) {
      _periodType = PeriodType.month;
      if (_startDate == null && widget.dayModeDate != null) {
        _startDate = widget.dayModeDate;
        _endDate = widget.dayModeDate;
      }
    }
  }

  void _pickYear() async {
    final now = DateTime.now();
    final startYear = now.year - 10;
    final endYear = now.year; // 限制为当前年份
    
    int tempYear = _selectedYear.clamp(startYear, endYear);
    final years = List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
    int yearIndex = years.indexOf(tempYear);
    
    final yearController = FixedExtentScrollController(initialItem: yearIndex);
    
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.cancel),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.pickYear,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, tempYear);
                      },
                      child: const Text(AppStrings.confirm),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  scrollController: yearController,
                  itemExtent: 32,
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
                            child: Text('${entry.value}年'),
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
    
    if (result != null) {
      setState(() => _selectedYear = result);
    }
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final startYear = now.year - 10;
    final endYear = now.year;
    
    int tempYear = _selectedMonth.year.clamp(startYear, endYear);
    int tempMonth = _selectedMonth.month;
    
    final years = List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
    final months = List<int>.generate(12, (i) => i + 1);
    
    int yearIndex = years.indexOf(tempYear);
    int monthIndex = tempMonth - 1;
    
    final yearController = FixedExtentScrollController(initialItem: yearIndex);
    final monthController = FixedExtentScrollController(initialItem: monthIndex);
    
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.cancel),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.pickMonth,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // 限制不能超过当前月份
                        if (tempYear > now.year || 
                            (tempYear == now.year && tempMonth > now.month)) {
                          tempYear = now.year;
                          tempMonth = now.month;
                        }
                        final picked = DateTime(tempYear, tempMonth, 1);
                        Navigator.pop(context, picked);
                      },
                      child: const Text(AppStrings.confirm),
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
                                  child: Text('${entry.value}年'),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: monthController,
                        itemExtent: 32,
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
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  tempMonth = entry.value;
                                },
                                child: Center(
                                  child: Text(entry.value.toString().padLeft(2, '0')),
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
    
    if (result != null) {
      setState(() => _selectedMonth = result);
    }
  }

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final startYear = now.year - 10;
    final endYear = now.year;
    
    int tempYear = _selectedWeek.start.year.clamp(startYear, endYear);
    int tempMonth = _selectedWeek.start.month;
    int tempDay = _selectedWeek.start.day;
    
    final years = List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
    final months = List<int>.generate(12, (i) => i + 1);
    
    int yearIndex = years.indexOf(tempYear);
    int monthIndex = tempMonth - 1;
    int dayIndex = tempDay - 1;
    
    final yearController = FixedExtentScrollController(initialItem: yearIndex);
    final monthController = FixedExtentScrollController(initialItem: monthIndex);
    final dayController = FixedExtentScrollController(initialItem: dayIndex);
    
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: 260,
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(AppStrings.cancel),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              AppStrings.pickWeek,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 修正天数，避免 2 月 30 日这类非法日期
                            final lastDayOfMonth =
                                DateTime(tempYear, tempMonth + 1, 0).day;
                            if (tempDay > lastDayOfMonth) {
                              tempDay = lastDayOfMonth;
                            }
                            final picked = DateTime(tempYear, tempMonth, tempDay);
                            // 限制不能超过当前日期
                            if (picked.isAfter(now)) {
                              Navigator.pop(context, now);
                            } else {
                              Navigator.pop(context, picked);
                            }
                          },
                          child: const Text(AppStrings.confirm),
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
                            onSelectedItemChanged: (index) {
                              tempYear = years[index];
                              // 更新天数范围
                              final lastDayOfMonth =
                                  DateTime(tempYear, tempMonth + 1, 0).day;
                              if (tempDay > lastDayOfMonth) {
                                tempDay = lastDayOfMonth;
                                dayController.animateToItem(
                                  tempDay - 1,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                              setState(() {});
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
                                      setState(() {});
                                    },
                                    child: Center(
                                      child: Text('${entry.value}年'),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: monthController,
                            itemExtent: 32,
                            onSelectedItemChanged: (index) {
                              tempMonth = months[index];
                              // 更新天数范围
                              final lastDayOfMonth =
                                  DateTime(tempYear, tempMonth + 1, 0).day;
                              if (tempDay > lastDayOfMonth) {
                                tempDay = lastDayOfMonth;
                                dayController.animateToItem(
                                  tempDay - 1,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                              setState(() {});
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
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      );
                                      tempMonth = entry.value;
                                      setState(() {});
                                    },
                                    child: Center(
                                      child: Text(entry.value.toString().padLeft(2, '0')),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final lastDayOfMonth =
                                  DateTime(tempYear, tempMonth + 1, 0).day;
                              final validDays = List<int>.generate(
                                  lastDayOfMonth, (i) => i + 1);
                              if (tempDay > lastDayOfMonth) {
                                tempDay = lastDayOfMonth;
                              }
                              final currentDayIndex = validDays.indexOf(tempDay);
                              if (currentDayIndex >= 0 &&
                                  currentDayIndex != dayController.selectedItem) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  dayController.animateToItem(
                                    currentDayIndex,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                });
                              }
                              return CupertinoPicker(
                                scrollController: dayController,
                                itemExtent: 32,
                                onSelectedItemChanged: (index) {
                                  if (index < validDays.length) {
                                    tempDay = validDays[index];
                                  }
                                },
                                children: validDays
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
                                        child: Center(
                                          child: Text(
                                              entry.value.toString().padLeft(2, '0')),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
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
      },
    );
    
    if (result != null) {
      setState(() {
        _selectedWeek = DateUtilsX.weekRange(result);
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

  int _weekIndexForYear(DateTime weekStart, int year) {
    final first = DateUtilsX.startOfWeek(DateTime(year, 1, 1));
    final diff = weekStart.difference(first).inDays;
    return (diff ~/ 7) + 1;
  }

  DateTime _weekStartForIndex(int weekIndex, int year) {
    final first = DateUtilsX.startOfWeek(DateTime(year, 1, 1));
    return first.add(Duration(days: (weekIndex - 1) * 7));
  }

  int _maxWeekIndexForYear(int year) {
    final lastStart = DateUtilsX.startOfWeek(DateTime(year, 12, 31));
    return _weekIndexForYear(lastStart, year);
  }

  Widget _buildGranularityBar(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final selectedBg = cs.onSurface.withOpacity(0.88);
    final unselectedFg = cs.onSurface.withOpacity(0.85);
    final selectedFg = cs.surface;

    Widget buildItem(PeriodType type, String label) {
      final selected = _periodType == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (_periodType == type) return;
            setState(() {
              _periodType = type;
              if (_periodType == PeriodType.week) {
                _selectedWeek = DateUtilsX.weekRange(_selectedMonth);
              } else if (_periodType == PeriodType.year) {
                _selectedYear = _selectedMonth.year;
              }
            });
          },
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? selectedFg : unselectedFg,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          buildItem(PeriodType.week, '周'),
          const SizedBox(width: 4),
          buildItem(PeriodType.month, '月'),
          const SizedBox(width: 4),
          buildItem(PeriodType.year, '年'),
        ],
      ),
    );
  }

  Widget _buildPeriodQuickStrip(ColorScheme cs) {
    switch (_periodType) {
      case PeriodType.week:
        return _buildWeekQuickStrip(cs);
      case PeriodType.month:
        return _buildMonthQuickStrip(cs);
      case PeriodType.year:
        return _buildYearQuickStrip(cs);
    }
  }

  Widget _buildWeekQuickStrip(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final year = _selectedYear;
    final selectedIndex = _weekIndexForYear(_selectedWeek.start, year);
    final maxIndex = year == now.year
        ? _weekIndexForYear(DateUtilsX.startOfWeek(now), year)
        : _maxWeekIndexForYear(year);

    final startIndex = (selectedIndex - 4).clamp(1, maxIndex);
    final indices = <int>[
      for (var i = startIndex; i <= selectedIndex; i++) i,
    ].where((i) => i >= 1 && i <= maxIndex).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (final i in indices) ...[
            InkWell(
              onTap: () {
                final weekStart = _weekStartForIndex(i, year);
                setState(() {
                  _selectedWeek = DateUtilsX.weekRange(weekStart);
                  _selectedMonth = DateTime(
                    _selectedWeek.start.year,
                    _selectedWeek.start.month,
                    1,
                  );
                  _selectedYear = year;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i}周',
                      style: tt.bodyMedium?.copyWith(
                        color: i == selectedIndex
                            ? cs.onSurface
                            : cs.onSurface.withOpacity(0.45),
                        fontWeight:
                            i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 2,
                      width: 26,
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? cs.onSurface.withOpacity(0.85)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthQuickStrip(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final selected = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final isCurrentYear = selected.year == now.year;

    List<({DateTime value, String label})> items;
    if (isCurrentYear &&
        (selected.month == now.month ||
            selected.month == now.month - 1 ||
            selected.month == now.month - 2)) {
      final m2 = DateTime(now.year, now.month - 2, 1);
      final m1 = DateTime(now.year, now.month - 1, 1);
      final m0 = DateTime(now.year, now.month, 1);
      items = [
        (value: m2, label: '${m2.month}月'),
        (value: m1, label: '上月'),
        (value: m0, label: '本月'),
      ];
    } else {
      final prev = DateTime(selected.year, selected.month - 1, 1);
      final next = DateTime(selected.year, selected.month + 1, 1);
      items = [
        (value: prev, label: '${prev.month}月'),
        (value: selected, label: '${selected.month}月'),
        (value: next, label: '${next.month}月'),
      ];
    }

    bool canSelect(DateTime m) {
      final month = DateTime(m.year, m.month, 1);
      final current = DateTime(now.year, now.month, 1);
      return !month.isAfter(current);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (final it in items) ...[
            InkWell(
              onTap: canSelect(it.value)
                  ? () {
                      setState(() {
                        _selectedMonth = it.value;
                        _selectedYear = it.value.year;
                        _selectedWeek = DateUtilsX.weekRange(_selectedMonth);
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      it.label,
                      style: tt.bodyMedium?.copyWith(
                        color: DateUtilsX.isSameMonth(it.value, selected)
                            ? cs.onSurface
                            : canSelect(it.value)
                                ? cs.onSurface.withOpacity(0.45)
                                : cs.onSurface.withOpacity(0.25),
                        fontWeight: DateUtilsX.isSameMonth(it.value, selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 2,
                      width: 26,
                      decoration: BoxDecoration(
                        color: DateUtilsX.isSameMonth(it.value, selected)
                            ? cs.onSurface.withOpacity(0.85)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYearQuickStrip(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final selectedYear = _selectedYear;
    final years = <int>[
      selectedYear - 1,
      selectedYear,
    ];
    if (selectedYear < now.year) {
      years.add(selectedYear + 1);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (final y in years) ...[
            InkWell(
              onTap: y <= now.year
                  ? () {
                      setState(() {
                        _selectedYear = y;
                        _selectedMonth = DateTime(y, _selectedMonth.month, 1);
                        _selectedWeek = DateUtilsX.weekRange(_selectedMonth);
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      y == now.year ? '今年' : '${y}年',
                      style: tt.bodyMedium?.copyWith(
                        color: y == selectedYear
                            ? cs.onSurface
                            : cs.onSurface.withOpacity(0.45),
                        fontWeight:
                            y == selectedYear ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 2,
                      width: 26,
                      decoration: BoxDecoration(
                        color: y == selectedYear
                            ? cs.onSurface.withOpacity(0.85)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          InkWell(
            onTap: _pickYear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
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

  bool _canGoNext() {
    final now = DateTime.now();
    if (_periodType == PeriodType.year) {
      // 如果当前年份已经是今年，不能前进
      return _selectedYear < now.year;
    } else if (_periodType == PeriodType.month) {
      // 如果当前月份已经是本月或未来，不能前进
      if (_selectedMonth.year > now.year) return false;
      if (_selectedMonth.year == now.year && _selectedMonth.month >= now.month) {
        return false;
      }
      return true;
    } else {
      // 周模式：如果下一周的开始日期超过当前日期，不能前进
      final nextWeekStart = _selectedWeek.start.add(const Duration(days: 7));
      return nextWeekStart.isBefore(now) || nextWeekStart.isAtSameMomentAs(now);
    }
  }

  void _shiftPeriod(int delta) {
    final now = DateTime.now();
    setState(() {
      if (_periodType == PeriodType.year) {
        final newYear = _selectedYear + delta;
        // 限制不能超过当前年份
        if (newYear <= now.year) {
          _selectedYear = newYear;
        _selectedMonth = DateTime(_selectedYear, _selectedMonth.month, 1);
        }
      } else if (_periodType == PeriodType.month) {
        final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
        // 限制不能超过当前月份
        if (newMonth.isBefore(now) || (newMonth.year == now.year && newMonth.month == now.month)) {
          _selectedMonth = newMonth;
        _selectedYear = _selectedMonth.year;
        }
      } else {
        final newStart = _selectedWeek.start.add(Duration(days: 7 * delta));
        // 限制不能超过当前日期
        if (newStart.isBefore(now) || newStart.isAtSameMomentAs(now)) {
        _selectedWeek = DateUtilsX.weekRange(newStart);
        _selectedYear = _selectedWeek.start.year;
        _selectedMonth =
            DateTime(_selectedWeek.start.year, _selectedWeek.start.month, 1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final recordChangeCounter =
        context.select<RecordProvider, int>((p) => p.changeCounter);
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();

    // 检查加载状态
    final ready =
        recordProvider.loaded && categoryProvider.loaded && bookProvider.loaded;

    final bookId = bookProvider.activeBookId;
    final bookName =
        bookProvider.activeBook?.name ?? AppStrings.defaultBook;

    // 预取三种视图的数据，避免切换周/月/年时 FutureBuilder 重新进入空态导致“闪屏”
    _ensureMonthRecordsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );
    _ensureWeekRecordsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );
    _ensureYearStatsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );

    if (widget.dayMode) {
      final date = widget.dayModeDate ?? _startDate ?? DateTime.now();
      final dateTitle = DateUtilsX.ymd(date);
      return Scaffold(
        appBar: AppBar(
          title: Text('$dateTitle 明细'),
        ),
        body: Column(
          children: [
            if (!ready) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.currentBookLabel(bookName),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildDayBill(
                context,
                cs,
                bookId,
                date: DateTime(date.year, date.month, date.day),
                recordProvider: recordProvider,
                categoryProvider: categoryProvider,
                recordChangeCounter: recordChangeCounter,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // 顶部不显示文字标题，避免与中间的周/月/年切换重复
        title: const SizedBox.shrink(),
        actions: [
          const BookSelectorButton(compact: true),
          IconButton(
            tooltip: AppStrings.filter,
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _openFilterSheet,
          ),
          Builder(
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () => _openReportDetail(context, bookId),
                  icon: Icon(
                    Icons.bar_chart_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  label: Text(
                    AppStrings.report,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color: cs.primary.withOpacity(0.3),
                      width: 1,
                    ),
                    backgroundColor: cs.primary.withOpacity(0.05),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '导出数据',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () async {
              final range = _currentRange();

              final choice = await showModalBottomSheet<RecordsExportFormat>(
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                showDragHandle: true,
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  final tt = Theme.of(ctx).textTheme;
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.grid_on_outlined,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          title: Text(
                            '导出 Excel',
                            style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          ),
                          subtitle: Text(
                            '适合表格查看与二次处理',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            ctx,
                            RecordsExportFormat.excel,
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.picture_as_pdf_outlined,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          title: Text(
                            '导出 PDF',
                            style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          ),
                          subtitle: Text(
                            '适合发送/打印留存',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            ctx,
                            RecordsExportFormat.pdf,
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.table_chart_outlined,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          title: Text(
                            '导出 CSV',
                            style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          ),
                          subtitle: Text(
                            '适合 Excel/表格查看与分析',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                          onTap: () => Navigator.pop(
                            ctx,
                            RecordsExportFormat.csv,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (!context.mounted || choice == null) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExportDataPage(
                    bookId: bookId,
                    initialRange: range,
                    format: choice,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!ready) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),

          // 搜索栏
          _BillSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            keyword: _searchKeyword,
            hasActiveFilter: _hasActiveFilterOrSearch,
            onChanged: _onSearchKeywordChanged,
            onSubmitted: _onSearchSubmitted,
            onTapFilter: _openFilterSheet,
            onClear: _clearSearchKeyword,
          ),

          if (_showSuggestions)
            _BillSearchSuggestionPanel(
              keyword: _searchKeyword,
              history: _searchHistory,
              categories: context.watch<CategoryProvider>().categories,
              onTapHistory: _applyHistoryKeyword,
              onClearHistory: _clearSearchHistory,
              onTapCategory: _applyCategorySuggestion,
            ),

          if (_hasActiveFilterOrSearch)
            _BillFilterSummaryBar(
              summaryText: _buildFilterSummaryText(),
              onClearAll: _handleClearAllFilters,
            ),

          // -----------------------------------
          // 🔘 周 / 月 / 年（按截图：上方分段 + 下方周期条）
          // -----------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildGranularityBar(cs),
          ),

          const SizedBox(height: 10),

          _buildPeriodQuickStrip(cs),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前账本：$bookName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: cs.outline,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: IndexedStack(
              index: _periodType == PeriodType.week
                  ? 0
                  : _periodType == PeriodType.month
                      ? 1
                      : 2,
              children: [
                KeyedSubtree(
                  key: const PageStorageKey<String>('bill_week'),
                  child: _buildWeekBill(
                    context,
                    cs,
                    bookId,
                    recordProvider: recordProvider,
                    categoryProvider: categoryProvider,
                    recordChangeCounter: recordChangeCounter,
                  ),
                ),
                KeyedSubtree(
                  key: const PageStorageKey<String>('bill_month'),
                  child: _buildMonthBill2(
                    context,
                    cs,
                    bookId,
                    recordProvider: recordProvider,
                    categoryProvider: categoryProvider,
                    recordChangeCounter: recordChangeCounter,
                  ),
                ),
                KeyedSubtree(
                  key: const PageStorageKey<String>('bill_year'),
                  child: _buildYearBill(
                    context,
                    cs,
                    bookId,
                    recordProvider: recordProvider,
                    recordChangeCounter: recordChangeCounter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _appBarTitle() {
    // 顶部标题保持简短，避免被两侧按钮挤压成省略号
    // 周账单 / 月账单 / 年账单的区分已经由中间的 SegmentedButton 承担
    return AppStrings.billTitle; // 统一显示「账单」
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
      });
      return;
    }
    setState(() {
      _showSuggestions =
          _searchKeyword.trim().isNotEmpty || _searchHistory.isNotEmpty;
    });
  }

  void _onSearchKeywordChanged(String value) {
    setState(() {
      _searchKeyword = value;
      if (_searchFocusNode.hasFocus) {
        _showSuggestions =
            _searchKeyword.trim().isNotEmpty || _searchHistory.isNotEmpty;
      }
    });
  }

  void _onSearchSubmitted(String value) {
    _saveSearchKeyword(value);
    setState(() {
      _searchKeyword = value;
      _showSuggestions = false;
    });
  }

  void _clearSearchKeyword() {
    setState(() {
      _searchKeyword = '';
      _searchController.clear();
      _showSuggestions =
          _searchFocusNode.hasFocus && _searchHistory.isNotEmpty;
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('bill_search_history') ?? <String>[];
    if (!mounted) return;
    setState(() {
      _searchHistory = list;
    });
  }

  Future<void> _saveSearchKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = List<String>.from(_searchHistory);
    history.remove(trimmed);
    history.insert(0, trimmed);
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }
    await prefs.setStringList('bill_search_history', history);
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bill_search_history');
    if (!mounted) return;
    setState(() {
      _searchHistory = <String>[];
    });
  }

  void _applyHistoryKeyword(String keyword) {
    _searchController.text = keyword;
    _onSearchKeywordChanged(keyword);
    _saveSearchKeyword(keyword);
    setState(() {
      _showSuggestions = false;
    });
  }

  void _applyCategorySuggestion(Category category) {
    setState(() {
      _filterCategoryKeys = <String>{category.key};
      _filterIncomeExpense = category.isExpense ? false : true;
      _searchKeyword = '';
      _searchController.clear();
      _showSuggestions = false;
    });
  }

  bool get _hasActiveFilterOrSearch {
    final hasKeyword = _searchKeyword.trim().isNotEmpty;
    final hasCategory = _filterCategoryKeys.isNotEmpty;
    final hasAmount = _minAmount != null || _maxAmount != null;
    final hasType = _filterIncomeExpense != null;
    final hasAccounts = _filterAccountIds.isNotEmpty;
    final hasDateRange = _startDate != null || _endDate != null;
    return hasKeyword || hasCategory || hasAmount || hasType || hasAccounts || hasDateRange;
  }

  String _buildFilterSummaryText() {
    final parts = <String>[];
    final kw = _searchKeyword.trim();
    if (kw.isNotEmpty) {
      parts.add('"$kw"');
    }
    if (_filterIncomeExpense != null) {
      parts.add(_filterIncomeExpense! ? '收入' : '支出');
    }
    if (_filterCategoryKeys.isNotEmpty) {
      parts.add('分类 ${_filterCategoryKeys.length}');
    }
    if (_minAmount != null && _maxAmount != null) {
      parts.add('金额 ${_minAmount!.toStringAsFixed(0)}-${_maxAmount!.toStringAsFixed(0)}');
    } else if (_minAmount != null) {
      parts.add('金额 ≥${_minAmount!.toStringAsFixed(0)}');
    } else if (_maxAmount != null) {
      parts.add('金额 ≤${_maxAmount!.toStringAsFixed(0)}');
    }
    if (_filterAccountIds.isNotEmpty) {
      parts.add('账户 ${_filterAccountIds.length}');
    }
    if (_startDate != null || _endDate != null) {
      final startStr = _startDate != null ? DateUtilsX.ymd(_startDate!) : '';
      final endStr = _endDate != null ? DateUtilsX.ymd(_endDate!) : '';
      parts.add('$startStr${(startStr.isNotEmpty || endStr.isNotEmpty) ? ' ~ ' : ''}$endStr');
    }
    if (parts.isEmpty) {
      return '';
    }
    return '已筛选：${parts.join(' · ')}';
  }

  void _handleClearAllFilters() {
    setState(() {
      _searchKeyword = '';
      _searchController.clear();
      _filterCategoryKeys = <String>{};
      _minAmount = null;
      _maxAmount = null;
      _filterIncomeExpense = null;
      _filterAccountIds = <String>{};
      _startDate = null;
      _endDate = null;
      _showSuggestions = false;
    });
  }

  DateTimeRange _currentRange() {
    switch (_periodType) {
      case PeriodType.week:
        final start = DateTime(
          _selectedWeek.start.year,
          _selectedWeek.start.month,
          _selectedWeek.start.day,
        );
        final end = DateTime(
          _selectedWeek.end.year,
          _selectedWeek.end.month,
          _selectedWeek.end.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case PeriodType.month:
        final start = DateUtilsX.firstDayOfMonth(_selectedMonth);
        final end = DateUtilsX.lastDayOfMonth(_selectedMonth);
        final endWithTime = DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: endWithTime);
      case PeriodType.year:
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  void _openReportDetail(BuildContext context, String bookId) {
    final range = _currentRange();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailPage(
          bookId: bookId,
          year: _selectedYear,
          month: _periodType == PeriodType.month ? _selectedMonth.month : null,
          weekRange: _periodType == PeriodType.week ? range : null,
          periodType: _periodType,
        ),
      ),
    );
  }

  // 新版导出菜单：在弹窗中说明导出范围
  Future<void> _showExportMenuV2(
    BuildContext context,
    String bookId,
  ) async {
    final range = _currentRange();
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final bookName = bookProvider.activeBook?.name ?? AppStrings.defaultBook;
    
    // 预先统计记录数量
    final records = recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
    final recordCount = records.length;
    
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '导出范围',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildExportInfoRow(ctx, '账本', bookName),
                _buildExportInfoRow(
                  ctx,
                  '时间范围',
                  '${DateUtilsX.ymd(range.start)} 至 ${DateUtilsX.ymd(range.end)}',
                ),
                _buildExportInfoRow(
                  ctx,
                  '记录数量',
                  recordCount > 0 ? '$recordCount 条' : '暂无记录',
                ),
                _buildExportInfoRow(
                  ctx,
                  '包含内容',
                  '仅计入统计的记录',
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.table_chart_outlined, color: cs.onSurface.withOpacity(0.7)),
                  title: Text(
                    '导出 CSV',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                  ),
                  subtitle: Text(
                    '用 Excel 打开查看和分析数据（$recordCount 条）',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                        ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'csv'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'csv') {
      await _exportCsv(context, bookId, range);
    }
  }

  Widget _buildExportInfoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    String bookId,
    DateTimeRange range,
  ) async {
    try {
      // 显示加载提示
      if (context.mounted) {
        ErrorHandler.showInfo(context, '正在导出...');
      }

    final recordProvider = context.read<RecordProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final bookProvider = context.read<BookProvider>();
    final accountProvider = context.read<AccountProvider>();

    final records = recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
    if (records.isEmpty) {
      if (context.mounted) {
          ErrorHandler.showWarning(context, '当前时间范围内暂无记录');
      }
      return;
    }

    final categoriesByKey = {
      for (final c in categoryProvider.categories) c.key: c.name,
    };
    final booksById = {
      for (final b in bookProvider.books) b.id: b.name,
    };

    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    final rows = <List<String>>[];
    rows.add([
      '日期',
      '金额',
      '收支方向',
      '分类',
      '账本',
      '账户',
      '备注',
      '是否计入统计',
    ]);

    for (final r in records) {
      final dateStr = formatter.format(r.date);
      final amountStr = r.amount.toStringAsFixed(2);
      final directionStr = r.isIncome ? '收入' : '支出';
      final categoryName =
          categoriesByKey[r.categoryKey] ?? r.categoryKey;
      final bookName = booksById[r.bookId] ?? bookProvider.activeBook?.name ??
          '默认账本';
      final accountName =
          accountProvider.byId(r.accountId)?.name ?? '未知账户';
      final remark = r.remark;
      final includeStr = r.includeInStats ? '是' : '否';

      rows.add([
        dateStr,
        amountStr,
        directionStr,
        categoryName,
        bookName,
        accountName,
        remark,
        includeStr,
      ]);
    }

    final csv = toCsv(rows);

    final dir = await getTemporaryDirectory();
      final bookName = bookProvider.activeBook?.name ?? '默认账本';
      // Windows 文件名不允许包含特殊字符，使用简洁的日期格式
      final startStr = '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
      final endStr = '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
      // 文件名包含账本名称，更友好
      final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${safeBookName}_${startStr}_$endStr.csv';
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(csv, encoding: utf8);

    if (!context.mounted) return;

      // Windows 平台使用文件保存对话框，其他平台使用共享
      if (Platform.isWindows) {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存 CSV 文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        
        if (savedPath != null) {
          await file.copy(savedPath);
          if (context.mounted) {
            final fileSize = await File(savedPath).length();
            final sizeStr = fileSize > 1024 * 1024
                ? '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'
                : '${(fileSize / 1024).toStringAsFixed(2)} KB';
            ErrorHandler.showSuccess(
              context,
              '导出成功！共 ${records.length} 条记录，文件大小：$sizeStr',
            );
          }
        }
      } else {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '指尖记账导出 CSV',
      text: '指尖记账导出记录 CSV，可用 Excel 打开查看。',
    );
        if (context.mounted) {
          ErrorHandler.showSuccess(context, '导出成功！共 ${records.length} 条记录');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  // ======================================================
  // 📘 年度账单（展示 12 个月收入/支出/结余）
  // ======================================================
  Widget _buildYearBill(
    BuildContext context,
    ColorScheme cs,
    String bookId, {
    required RecordProvider recordProvider,
    required int recordChangeCounter,
  }) {
    _ensureYearStatsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );
    final months = DateUtilsX.monthsInYear(_selectedYear);

    // 使用 FutureBuilder 异步加载统计数据（支持100万条记录）
    return FutureBuilder<List<Map<String, double>>>(
      future: _yearStatsFuture,
      initialData: _yearStatsCache,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final monthStats = snapshot.data ?? const <Map<String, double>>[];
        if (snapshot.connectionState == ConnectionState.done) {
          _yearStatsCache = monthStats;
        }
        final showLoadingOverlay =
            snapshot.connectionState == ConnectionState.waiting;
        double totalIncome = 0;
        double totalExpense = 0;

        final monthItems = <Widget>[];
        for (var i = 0; i < months.length; i++) {
          final m = months[i];
          final stats = i < monthStats.length ? monthStats[i] : {'income': 0.0, 'expense': 0.0};
          final income = stats['income'] ?? 0.0;
          final expense = stats['expense'] ?? 0.0;
          final balance = income - expense;

          totalIncome += income;
          totalExpense += expense;

          // 只展示有记账的月份，避免一整年全是 0.00 的行
          if (income == 0 && expense == 0) continue;

          monthItems.add(
            InkWell(
              onTap: () {
                setState(() {
                  _periodType = PeriodType.month;
                  _selectedYear = m.year;
                  _selectedMonth = DateTime(m.year, m.month, 1);
                });
              },
              child: _billCard(
                title: AppStrings.monthLabel(m.month),
                income: income,
                expense: expense,
                balance: balance,
                cs: cs,
              ),
            ),
          );
        }

        final items = <Widget>[];
        final totalBalance = totalIncome - totalExpense;

        // 年度小结
        items.add(
          _billCard(
            title: AppStrings.yearReport,
            subtitle:
                '本年收入 ${totalIncome.toStringAsFixed(2)} 元 · 支出 ${totalExpense.toStringAsFixed(2)} 元',
            income: totalIncome,
            expense: totalExpense,
            balance: totalBalance,
            cs: cs,
            highlight: true,
          ),
        );

        items.addAll(monthItems);

        final list = ListView(
          padding: const EdgeInsets.all(12),
          children: items,
        );
        if (!showLoadingOverlay) return list;
        return Stack(
          children: [
            list,
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        );
      },
    );
  }

  /// 异步加载年度统计数据
  Future<List<Map<String, double>>> _loadYearStats(
    RecordProvider recordProvider,
    String bookId,
    List<DateTime> months,
  ) async {
    final stats = <Map<String, double>>[];
    for (final m in months) {
      final monthStats = await recordProvider.getMonthStatsAsync(m, bookId);
      stats.add({
        'income': monthStats.income,
        'expense': monthStats.expense,
      });
    }
    return stats;
  }

  void _ensureYearStatsFuture({
    required RecordProvider recordProvider,
    required String bookId,
    required int recordChangeCounter,
  }) {
    final key = '$bookId:${_selectedYear}:$recordChangeCounter';
    if (_yearStatsKey == key && _yearStatsFuture != null) return;
    _yearStatsKey = key;
    final months = DateUtilsX.monthsInYear(_selectedYear);
    _yearStatsFuture = _loadYearStats(recordProvider, bookId, months);
  }

  void _ensureMonthRecordsFuture({
    required RecordProvider recordProvider,
    required String bookId,
    required int recordChangeCounter,
  }) {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    final key =
        '$bookId:${monthStart.millisecondsSinceEpoch}:${monthEnd.millisecondsSinceEpoch}:$recordChangeCounter';
    if (_monthRecordsKey == key && _monthRecordsFuture != null) return;
    _monthRecordsKey = key;
    _monthRecordsFuture = recordProvider.recordsForPeriodAsync(
      bookId,
      start: monthStart,
      end: monthEnd,
    );
  }

  void _ensureWeekRecordsFuture({
    required RecordProvider recordProvider,
    required String bookId,
    required int recordChangeCounter,
  }) {
    final start = _selectedWeek.start;
    final end = _selectedWeek.end
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));
    final key =
        '$bookId:${start.millisecondsSinceEpoch}:${end.millisecondsSinceEpoch}:$recordChangeCounter';
    if (_weekRecordsKey == key && _weekRecordsFuture != null) return;
    _weekRecordsKey = key;
    _weekRecordsFuture = recordProvider.recordsForPeriodAsync(
      bookId,
      start: start,
      end: end,
    );
  }

  Widget _buildWeekBill(
    BuildContext context,
    ColorScheme cs,
    String bookId, {
    required RecordProvider recordProvider,
    required CategoryProvider categoryProvider,
    required int recordChangeCounter,
  }) {
    _ensureWeekRecordsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final days =
        List.generate(7, (i) => _selectedWeek.start.add(Duration(days: i)));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // 使用 FutureBuilder 异步加载周记录（支持100万条记录）
    return FutureBuilder<List<Record>>(
      future: _weekRecordsFuture,
      initialData: _weekRecordsCache,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final allWeekRecords = snapshot.data ?? const <Record>[];
        if (snapshot.connectionState == ConnectionState.done) {
          _weekRecordsCache = allWeekRecords;
        }
        final showLoadingOverlay =
            snapshot.connectionState == ConnectionState.waiting;
        final tagProvider = context.read<TagProvider>();
        final recordIds = allWeekRecords.map((r) => r.id).toList();

        return FutureBuilder<Map<String, List<Tag>>>(
          future: tagProvider.loadTagsForRecords(recordIds),
          builder: (context, tagSnap) {
            final tagsByRecordId =
                tagSnap.data ?? const <String, List<Tag>>{};

            double totalIncome = 0;
            double totalExpense = 0;
            int emptyDays = 0;

            final items = <Widget>[];

            for (final d in days) {
              final dayDate = DateTime(d.year, d.month, d.day);
              // 从已加载的记录中筛选当天的记录
              final allRecords = allWeekRecords
                  .where((r) => DateUtilsX.isSameDay(r.date, d) && r.bookId == bookId)
                  .toList();
              final records = _applyFilters(
                allRecords,
                categoryMap,
                tagsByRecordId: tagsByRecordId,
              );

      double income = 0;
      double expense = 0;
      for (final r in records) {
        if (r.isIncome) {
          income += r.incomeValue;
        } else {
          expense += r.expenseValue;
        }
      }
      totalIncome += income;
      totalExpense += expense;

      // 没有记录的过去日期只计入“空白天数”，不生成明细区块
      if (records.isEmpty && !dayDate.isAfter(todayDate)) {
        emptyDays += 1;
        continue;
      }
      if (records.isEmpty) {
        continue;
      }

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

          for (final r in records) {
            final category = categoryMap[r.categoryKey];
            items.add(
              TimelineItem(
                record: r,
                leftSide: false,
                category: category,
                subtitle: r.remark.isEmpty ? null : r.remark,
                tags: tagsByRecordId[r.id] ?? const <Tag>[],
                onTap: () => _openEditRecord(r),
                onDelete: () => _confirmAndDeleteRecord(r),
              ),
            );
          }
        }

        final subtitleParts = <String>[AppStrings.weekRangeLabel(_selectedWeek)];
        if (emptyDays > 0) {
          subtitleParts.add(AppTextTemplates.weekEmptyDaysHint(emptyDays));
        }

        // 顶部整周小结卡片
        items.insert(
          0,
          _billCard(
            title: DateUtilsX.weekLabel(_weekNumberForWeek(_selectedWeek.start)),
            subtitle: subtitleParts.join(' · '),
            income: totalIncome,
            expense: totalExpense,
            balance: totalIncome - totalExpense,
            cs: cs,
            highlight: true,
          ),
        );

            final list = ListView(
              padding: const EdgeInsets.all(12),
              children: items,
            );
            if (!showLoadingOverlay) return list;
            return Stack(
              children: [
                list,
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ======================================================
  // 📕 月度账单（按天 + 明细，支持筛选）
  // ======================================================
  Widget _buildMonthBill2(
    BuildContext context,
    ColorScheme cs,
    String bookId, {
    required RecordProvider recordProvider,
    required CategoryProvider categoryProvider,
    required int recordChangeCounter,
  }) {
    final days = DateUtilsX.daysInMonth(_selectedMonth);
    _ensureMonthRecordsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };

    // 使用 FutureBuilder 异步加载月记录（支持100万条记录）
    return FutureBuilder<List<Record>>(
      future: _monthRecordsFuture,
      initialData: _monthRecordsCache,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final allMonthRecords = snapshot.data ?? const <Record>[];
        if (snapshot.connectionState == ConnectionState.done) {
          _monthRecordsCache = allMonthRecords;
        }
        final showLoadingOverlay =
            snapshot.connectionState == ConnectionState.waiting;
        final tagProvider = context.read<TagProvider>();
        final recordIds = allMonthRecords.map((r) => r.id).toList();

        return FutureBuilder<Map<String, List<Tag>>>(
          future: tagProvider.loadTagsForRecords(recordIds),
          builder: (context, tagSnap) {
            final tagsByRecordId =
                tagSnap.data ?? const <String, List<Tag>>{};

            double totalIncome = 0;
            double totalExpense = 0;
            double maxDailyExpense = 0;
            int recordedDays = 0;

            final nonEmptyDays = <DateTime>[];

            for (final d in days) {
              // 从已加载的记录中筛选当天的记录
              final allRecords = allMonthRecords
                  .where((r) => DateUtilsX.isSameDay(r.date, d) && r.bookId == bookId)
                  .toList();
              final records = _applyFilters(
                allRecords,
                categoryMap,
                tagsByRecordId: tagsByRecordId,
              );

      double income = 0;
      double expense = 0;
      for (final r in records) {
        if (r.isIncome) {
          income += r.incomeValue;
        } else {
          expense += r.expenseValue;
        }
      }

          totalIncome += income;
          totalExpense += expense;

          if (records.isNotEmpty) {
            recordedDays += 1;
            nonEmptyDays.add(d);
          }
          if (expense > maxDailyExpense) {
            maxDailyExpense = expense;
          }
        }

        final totalDays = days.length;
        final avgExpense = totalDays > 0 ? totalExpense / totalDays : 0;
        final emptyDays = totalDays - recordedDays;

        final items = <Widget>[];

        final subtitleParts = <String>[];
        subtitleParts.add(
          '本月支出 ${totalExpense.toStringAsFixed(2)} 元 · 日均 ${avgExpense.toStringAsFixed(2)} 元',
        );
        subtitleParts.add('记账 $recordedDays 天');
        if (emptyDays > 0) {
          subtitleParts.add(AppTextTemplates.monthEmptyDaysHint(emptyDays));
        }
        if (maxDailyExpense > 0) {
          subtitleParts.add('单日最高支出 ${maxDailyExpense.toStringAsFixed(2)} 元');
        }

        items.add(
          _billCard(
            title: AppStrings.monthListTitle,
            subtitle: subtitleParts.join(' · '),
            income: totalIncome,
            expense: totalExpense,
            balance: totalIncome - totalExpense,
            cs: cs,
            highlight: true,
          ),
        );

        for (final d in nonEmptyDays) {
          // 从已加载的记录中筛选当天的记录
          final allRecords = allMonthRecords
              .where((r) => DateUtilsX.isSameDay(r.date, d) && r.bookId == bookId)
              .toList();
          final records = _applyFilters(
            allRecords,
            categoryMap,
            tagsByRecordId: tagsByRecordId,
          );

          double income = 0;
          double expense = 0;
          for (final r in records) {
            if (r.isIncome) {
              income += r.incomeValue;
            } else {
              expense += r.expenseValue;
            }
          }
          final balance = income - expense;

          items.add(
            _billCard(
              title: AppStrings.monthDayLabel(d.month, d.day),
              income: income,
              expense: expense,
              balance: balance,
              cs: cs,
            ),
          );

          for (final r in records) {
            final category = categoryMap[r.categoryKey];
            items.add(
              TimelineItem(
                record: r,
                leftSide: false,
                category: category,
                subtitle: r.remark.isEmpty ? null : r.remark,
                tags: tagsByRecordId[r.id] ?? const <Tag>[],
                onTap: () => _openEditRecord(r),
                onDelete: () => _confirmAndDeleteRecord(r),
              ),
            );
          }
        }

            final list = ListView(
              padding: const EdgeInsets.all(12),
              children: items,
            );
            if (!showLoadingOverlay) return list;
            return Stack(
              children: [
                list,
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayBill(
    BuildContext context,
    ColorScheme cs,
    String bookId, {
    required DateTime date,
    required RecordProvider recordProvider,
    required CategoryProvider categoryProvider,
    required int recordChangeCounter,
  }) {
    _ensureMonthRecordsFuture(
      recordProvider: recordProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
    );

    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };

    return FutureBuilder<List<Record>>(
      future: _monthRecordsFuture,
      initialData: _monthRecordsCache,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final allMonthRecords = snapshot.data ?? const <Record>[];
        if (snapshot.connectionState == ConnectionState.done) {
          _monthRecordsCache = allMonthRecords;
        }

        final showLoadingOverlay = snapshot.connectionState == ConnectionState.waiting;
        final tagProvider = context.read<TagProvider>();

        final allRecords = allMonthRecords
            .where((r) => r.bookId == bookId && DateUtilsX.isSameDay(r.date, date))
            .toList();

        allRecords.sort((a, b) => b.date.compareTo(a.date));

        final recordIds = allRecords.map((r) => r.id).toList();
        return FutureBuilder<Map<String, List<Tag>>>(
          future: tagProvider.loadTagsForRecords(recordIds),
          builder: (context, tagSnap) {
            final tagsByRecordId = tagSnap.data ?? const <String, List<Tag>>{};

            final records = _applyFilters(
              allRecords,
              categoryMap,
              tagsByRecordId: tagsByRecordId,
            );

            if (records.isEmpty && !showLoadingOverlay) {
              return Center(
                child: Text(
                  '当天暂无记录',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
                ),
              );
            }

            double income = 0;
            double expense = 0;
            for (final r in records) {
              if (r.isIncome) {
                income += r.incomeValue;
              } else {
                expense += r.expenseValue;
              }
            }

            final items = <Widget>[
              _billCard(
                title: AppStrings.monthDayLabel(date.month, date.day),
                subtitle: DateUtilsX.weekdayShort(date),
                income: income,
                expense: expense,
                balance: income - expense,
                cs: cs,
                highlight: true,
              ),
            ];

            for (final r in records) {
              final category = categoryMap[r.categoryKey];
              items.add(
                TimelineItem(
                  record: r,
                  leftSide: false,
                  category: category,
                  subtitle: r.remark.isEmpty ? null : r.remark,
                  tags: tagsByRecordId[r.id] ?? const <Tag>[],
                  onTap: () => _openEditRecord(r),
                  onDelete: () => _confirmAndDeleteRecord(r),
                ),
              );
            }

            final list = ListView(
              padding: const EdgeInsets.all(12),
              children: items,
            );

            if (!showLoadingOverlay) return list;
            return Stack(
              children: [
                list,
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            );
          },
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
      bool highlight = false,
    }) {
      final titleColor = highlight ? cs.onPrimary : cs.primary;
      final subtitleColor =
          highlight ? cs.onPrimary.withOpacity(0.88) : cs.outline;
      final bodyColor = highlight
          ? cs.onPrimary.withOpacity(0.92)
          : cs.onSurface.withOpacity(0.75);

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          gradient: highlight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(0.85),
                    cs.primaryContainer.withOpacity(0.9),
                  ],
                )
              : null,
          color: highlight ? null : cs.surface,
          borderRadius: BorderRadius.circular(highlight ? 24 : 16),
          border: highlight
              ? null
              : Border.all(
                  color: cs.outlineVariant.withOpacity(0.4),
                ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(highlight ? 0.18 : 0.12),
              blurRadius: highlight ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '本期收入 ${income.toStringAsFixed(2)} 元 · 支出 ${expense.toStringAsFixed(2)} 元 · 结余 ${balance.toStringAsFixed(2)} 元',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: bodyColor,
            ),
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

  // 辅助方法和类
  double? _getQuickAmountMin(String option) {
    switch (option) {
      case '<100':
        return 0.0;
      case '100-500':
        return 100.0;
      case '500-1000':
        return 500.0;
      case '>1000':
        return 1000.0;
      default:
        return null;
    }
  }

  double? _getQuickAmountMax(String option) {
    switch (option) {
      case '<100':
        return 100.0;
      case '100-500':
        return 500.0;
      case '500-1000':
        return 1000.0;
      case '>1000':
        return null;
      default:
        return null;
    }
  }

  DateTimeRange? _getQuickDateRange(String option) {
    final now = DateTime.now();
    switch (option) {
      case 'today':
        return DateTimeRange(start: now, end: now);
      case 'thisWeek':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: start, end: now);
      case 'thisMonth':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case 'lastMonth':
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: start, end: end);
      case 'thisYear':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      default:
        return null;
    }
  }

  int _calculateFilteredCount({
    required List<Record> allRecords,
    required Map<String, Category> categoryMap,
    required Set<String> categoryKeys,
    required Set<String> accountIds,
    required double? minAmount,
    required double? maxAmount,
    required bool? incomeExpense,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    var filtered = allRecords;

    if (categoryKeys.isNotEmpty) {
      filtered = filtered
          .where((r) => categoryKeys.contains(r.categoryKey))
          .toList();
    }

    if (accountIds.isNotEmpty) {
      filtered = filtered
          .where((r) => accountIds.contains(r.accountId))
          .toList();
    }

    if (minAmount != null) {
      filtered = filtered.where((r) => r.absAmount >= minAmount).toList();
    }

    if (maxAmount != null) {
      filtered = filtered.where((r) => r.absAmount <= maxAmount).toList();
    }

    if (incomeExpense != null) {
      if (incomeExpense == true) {
        filtered = filtered.where((r) => r.isIncome).toList();
      } else {
        filtered = filtered.where((r) => r.isExpense).toList();
      }
    }

    if (startDate != null) {
      filtered = filtered.where((r) => !r.date.isBefore(startDate)).toList();
    }

    if (endDate != null) {
      filtered = filtered.where((r) => !r.date.isAfter(endDate)).toList();
    }

    return filtered.length;
  }

  List<_QuickOption> _quickDateOptions() {
    return const [
      _QuickOption(key: 'today', label: '今天'),
      _QuickOption(key: 'thisWeek', label: '本周'),
      _QuickOption(key: 'thisMonth', label: '本月'),
      _QuickOption(key: 'lastMonth', label: '上月'),
      _QuickOption(key: 'thisYear', label: '今年'),
    ];
  }

  List<_QuickAmountOption> _quickAmountOptions() {
    return const [
      _QuickAmountOption(key: '<100', label: '<100', min: 0, max: 100),
      _QuickAmountOption(
          key: '100-500', label: '100-500', min: 100, max: 500),
      _QuickAmountOption(
          key: '500-1000', label: '500-1000', min: 500, max: 1000),
      _QuickAmountOption(key: '>1000', label: '>1000', min: 1000, max: null),
    ];
  }

  String? _deriveQuickDateKey(DateTime? start, DateTime? end) {
    bool match(String key) {
      final range = _getQuickDateRange(key);
      if (range == null || start == null || end == null) return false;
      return !start.isBefore(range.start) && !end.isAfter(range.end);
    }

    for (final opt in _quickDateOptions()) {
      if (match(opt.key)) return opt.key;
    }
    return null;
  }

  String? _deriveQuickAmountKey(double? min, double? max) {
    if (min == 0 || (min == null && max == 100)) return '<100';
    if (min == 100 && max == 500) return '100-500';
    if (min == 500 && max == 1000) return '500-1000';
    if (min == 1000 && max == null) return '>1000';
    return null;
  }

  List<Category> _computeCommonRootCategories({
    required List<Record> records,
    required List<Category> categories,
    required Map<String, Category> categoryMap,
    bool? incomeExpense,
  }) {
    final usage = <String, int>{};
    for (final record in records) {
      if (incomeExpense == true && record.isExpense) continue;
      if (incomeExpense == false && record.isIncome) continue;
      final cat = categoryMap[record.categoryKey];
      if (cat == null) continue;
      final root = _findRootCategory(cat, categoryMap);
      if (incomeExpense != null) {
        if (incomeExpense && root.isExpense) continue;
        if (!incomeExpense && !root.isExpense) continue;
      }
      usage.update(root.key, (v) => v + 1, ifAbsent: () => 1);
    }

    final result = categories
        .where((c) => c.parentKey == null)
        .where((c) {
          if (incomeExpense == null) return true;
          return incomeExpense ? !c.isExpense : c.isExpense;
        })
        .toList()
      ..sort((a, b) => (usage[b.key] ?? 0).compareTo(usage[a.key] ?? 0));

    final total = usage.values.fold<int>(0, (p, e) => p + e);
    if (total < 5) {
      final fallbackNames = incomeExpense == true
          ? ['工资收入', '投资理财', '红包礼金', '退款报销', '兼职副业']
          : ['餐饮', '购物', '出行', '日用', '居住', '娱乐'];
      for (final name in fallbackNames) {
        final match = result.firstWhere(
          (c) => c.name == name,
          orElse: () => categories.firstWhere(
            (c) => c.parentKey == null && c.name == name,
            orElse: () => Category(
              key: '',
              name: '',
              icon: Icons.category,
              isExpense: incomeExpense != true,
            ),
          ),
        );
        if (match.key.isNotEmpty && !result.contains(match)) {
          result.add(match);
        }
      }
    }

    return result.take(8).toList();
  }

  Category _findRootCategory(
    Category category,
    Map<String, Category> categoryMap,
  ) {
    Category current = category;
    while (current.parentKey != null) {
      final parent = categoryMap[current.parentKey];
      if (parent == null) break;
      current = parent;
    }
    return current;
  }

  bool _isRootCategorySelected(
    String rootKey,
    Set<String> selectedLeafKeys,
    Map<String, Category> categoryMap,
  ) {
    final leafKeys = _leafKeysUnder(rootKey, categoryMap);
    return leafKeys.isNotEmpty && selectedLeafKeys.containsAll(leafKeys);
  }

  void _toggleRootCategory({
    required String rootKey,
    required Set<String> selectedLeafKeys,
    required Map<String, Category> categoryMap,
  }) {
    final leafKeys = _leafKeysUnder(rootKey, categoryMap);
    final selected = selectedLeafKeys.containsAll(leafKeys);
    if (selected) {
      selectedLeafKeys.removeAll(leafKeys);
    } else {
      selectedLeafKeys.addAll(leafKeys);
    }
  }

  Set<String> _leafKeysUnder(
    String rootKey,
    Map<String, Category> categoryMap,
  ) {
    final result = <String>{};
    void dfs(Category cat) {
      final children =
          categoryMap.values.where((c) => c.parentKey == cat.key).toList();
      if (children.isEmpty) {
        result.add(cat.key);
      } else {
        for (final child in children) {
          dfs(child);
        }
      }
    }

    final root = categoryMap[rootKey];
    if (root != null) dfs(root);
    return result;
  }

  double? _currentMin(String? quickKey, String textValue) {
    if (quickKey != null) return _getQuickAmountMin(quickKey);
    return textValue.trim().isEmpty ? null : double.tryParse(textValue.trim());
  }

  double? _currentMax(String? quickKey, String textValue) {
    if (quickKey != null) return _getQuickAmountMax(quickKey);
    return textValue.trim().isEmpty ? null : double.tryParse(textValue.trim());
  }

  String _buildInlineFilterSummary({
    bool? incomeExpense,
    DateTime? startDate,
    DateTime? endDate,
    required int categoryCount,
    double? amountMin,
    double? amountMax,
    required int accountCount,
  }) {
    final parts = <String>[];
    if (startDate != null || endDate != null) {
      final startStr = startDate != null ? DateUtilsX.ymd(startDate) : '';
      final endStr = endDate != null ? DateUtilsX.ymd(endDate) : '';
      parts.add('$startStr${(startStr.isNotEmpty || endStr.isNotEmpty) ? ' ~ ' : ''}$endStr');
    }
    if (incomeExpense != null) {
      parts.add(incomeExpense ? '收入' : '支出');
    }
    if (categoryCount > 0) {
      parts.add('分类 $categoryCount');
    }
    if (amountMin != null || amountMax != null) {
      if (amountMin != null && amountMax != null) {
        parts.add('金额 ${amountMin.toStringAsFixed(0)}-${amountMax.toStringAsFixed(0)}');
      } else if (amountMin != null) {
        parts.add('金额 ≥${amountMin.toStringAsFixed(0)}');
      } else if (amountMax != null) {
        parts.add('金额 ≤${amountMax.toStringAsFixed(0)}');
      }
    }
    if (accountCount > 0) {
      parts.add('账户 $accountCount');
    }
    return parts.isEmpty ? '' : '已选：${parts.join(' · ')}';
  }

  Future<void> _openFilterSheet() async {
    final categories = context.read<CategoryProvider>().categories;
    final accounts = context.read<AccountProvider>().accounts;
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final bookId = bookProvider.activeBookId;
    final categoryMap = {for (final c in categories) c.key: c};

    final baseRange = _startDate != null || _endDate != null
        ? DateTimeRange(
            start: _startDate ?? _currentRange().start,
            end: _endDate ?? _currentRange().end,
          )
        : _currentRange();
    final allRecords = recordProvider.recordsForPeriod(
      bookId,
      start: baseRange.start,
      end: baseRange.end,
    );

    Set<String> tempCategoryKeys = Set<String>.from(_filterCategoryKeys);
    Set<String> tempAccountIds = Set<String>.from(_filterAccountIds);
    bool? tempIncomeExpense = _filterIncomeExpense;
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    String? quickDateKey = _deriveQuickDateKey(tempStartDate, tempEndDate);
    String? quickAmountKey = _deriveQuickAmountKey(_minAmount, _maxAmount);

    final minCtrl = TextEditingController(text: _minAmount?.toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxAmount?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final quickDateOptions = _quickDateOptions();
                final quickAmountOptions = _quickAmountOptions();

                int filteredCount() {
                  final dateRange = quickDateKey != null
                      ? _getQuickDateRange(quickDateKey!)
                      : (tempStartDate != null || tempEndDate != null
                          ? DateTimeRange(
                              start: tempStartDate ?? baseRange.start,
                              end: tempEndDate ?? baseRange.end,
                            )
                          : null);
                  final min = _currentMin(quickAmountKey, minCtrl.text);
                  final max = _currentMax(quickAmountKey, maxCtrl.text);
                  return _calculateFilteredCount(
                    allRecords: allRecords,
                    categoryMap: categoryMap,
                    categoryKeys: tempCategoryKeys,
                    accountIds: tempAccountIds,
                    minAmount: min,
                    maxAmount: max,
                    incomeExpense: tempIncomeExpense,
                    startDate: dateRange?.start,
                    endDate: dateRange?.end,
                  );
                }

                void resetTemp() {
                  setModalState(() {
                    tempCategoryKeys.clear();
                    tempAccountIds.clear();
                    tempIncomeExpense = null;
                    tempStartDate = null;
                    tempEndDate = null;
                    quickDateKey = null;
                    quickAmountKey = null;
                    minCtrl.clear();
                    maxCtrl.clear();
                  });
                }

                Future<void> pickCustomDate() async {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: ctx,
                    initialDateRange: DateTimeRange(
                      start: tempStartDate ?? now,
                      end: tempEndDate ?? now,
                    ),
                    firstDate: DateTime(now.year - 3, 1, 1),
                    lastDate: now,
                  );
                  if (range != null) {
                    setModalState(() {
                      tempStartDate = range.start;
                      tempEndDate = range.end;
                      quickDateKey = _deriveQuickDateKey(range.start, range.end);
                    });
                  }
                }

                Future<void> openCategorySelector() async {
                  final result = await _openCategoryFullSheet(
                    context: ctx,
                    categories: categories,
                    categoryMap: categoryMap,
                    initialSelected: tempCategoryKeys,
                    incomeExpense: tempIncomeExpense,
                  );
                  if (result != null) {
                    setModalState(() {
                      tempCategoryKeys = result;
                    });
                  }
                }

                Future<void> openAccountSelector() async {
                  final result = await _openAccountMultiSelector(
                    context: ctx,
                    accounts: accounts,
                    initialSelected: tempAccountIds,
                  );
                  if (result != null) {
                    setModalState(() {
                      tempAccountIds = result;
                    });
                  }
                }

                final summaryText = _buildInlineFilterSummary(
                  incomeExpense: tempIncomeExpense,
                  startDate: quickDateKey != null
                      ? _getQuickDateRange(quickDateKey!)?.start
                      : tempStartDate,
                  endDate: quickDateKey != null
                      ? _getQuickDateRange(quickDateKey!)?.end
                      : tempEndDate,
                  categoryCount: tempCategoryKeys.length,
                  amountMin: _currentMin(quickAmountKey, minCtrl.text),
                  amountMax: _currentMax(quickAmountKey, maxCtrl.text),
                  accountCount: tempAccountIds.length,
                );

                final commonCategories = _computeCommonRootCategories(
                  records: allRecords,
                  categories: categories,
                  categoryMap: categoryMap,
                  incomeExpense: tempIncomeExpense,
                );
                final commonAccounts = accounts.take(4).toList();

                Widget buildSectionTitle(String label) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                Widget buildChoiceChip({
                  required String label,
                  required bool selected,
                  required VoidCallback onTap,
                }) {
                  return GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primary.withOpacity(0.12)
                            : cs.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? cs.primary
                              : cs.outline.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? cs.primary : cs.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

    return Column(
                  mainAxisSize: MainAxisSize.min,
      children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cs.outline.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '高级筛选',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    if (summaryText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(top: 6, bottom: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summaryText,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: cs.onSurface.withOpacity(0.8),
                                    ),
                                  ),
        const SizedBox(height: 4),
        Text(
                                    '预计找到 ${filteredCount()} 条记录',
	          style: Theme.of(context).textTheme.bodySmall?.copyWith(
	                                      fontSize: 12,
	                                      color: cs.primary,
	                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: resetTemp,
                              splashRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: media.viewInsets.bottom + 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildSectionTitle('日期范围'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: quickDateOptions.map((opt) {
                                final selected = quickDateKey == opt.key;
                                return buildChoiceChip(
                                  label: opt.label,
                                  selected: selected,
                                  onTap: () {
                                    setModalState(() {
                                      if (selected) {
                                        quickDateKey = null;
                                        tempStartDate = null;
                                        tempEndDate = null;
                                      } else {
                                        quickDateKey = opt.key;
                                        final range = _getQuickDateRange(opt.key);
                                        tempStartDate = range?.start;
                                        tempEndDate = range?.end;
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: pickCustomDate,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: cs.outline.withOpacity(0.6),
                                ),
                              ),
                              child: Text(
                                tempStartDate == null || tempEndDate == null
                                    ? '自定义日期'
                                    : '${DateUtilsX.ymd(tempStartDate!)} ~ ${DateUtilsX.ymd(tempEndDate!)}',
	                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
	                                  fontWeight: FontWeight.w600,
	                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            buildSectionTitle('收支类型'),
                            Wrap(
                              spacing: 8,
                              children: [
                                buildChoiceChip(
                                  label: '全部',
                                  selected: tempIncomeExpense == null,
                                  onTap: () =>
                                      setModalState(() => tempIncomeExpense = null),
                                ),
                                buildChoiceChip(
                                  label: '收入',
                                  selected: tempIncomeExpense == true,
                                  onTap: () =>
                                      setModalState(() => tempIncomeExpense = true),
                                ),
                                buildChoiceChip(
                                  label: '支出',
                                  selected: tempIncomeExpense == false,
                                  onTap: () =>
                                      setModalState(() => tempIncomeExpense = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            buildSectionTitle('分类'),
                            if (commonCategories.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final c in commonCategories)
                                    buildChoiceChip(
                                      label: c.name,
                                      selected: _isRootCategorySelected(
                                        c.key,
                                        tempCategoryKeys,
                                        categoryMap,
                                      ),
                                      onTap: () {
                                        setModalState(() {
                                          _toggleRootCategory(
                                            rootKey: c.key,
                                            selectedLeafKeys: tempCategoryKeys,
                                            categoryMap: categoryMap,
                                          );
                                        });
                                      },
                                    ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: openCategorySelector,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: cs.outline.withOpacity(0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempCategoryKeys.isEmpty
                                        ? '全部分类'
                                        : '已选 ${tempCategoryKeys.length} 个分类',
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            buildSectionTitle('按金额'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: quickAmountOptions.map((opt) {
                                final selected = quickAmountKey == opt.key;
                                return buildChoiceChip(
                                  label: opt.label,
                                  selected: selected,
                                  onTap: () {
                                    setModalState(() {
                                      if (selected) {
                                        quickAmountKey = null;
                                        minCtrl.clear();
                                        maxCtrl.clear();
                                      } else {
                                        quickAmountKey = opt.key;
                                        minCtrl.text = opt.min?.toString() ?? '';
                                        maxCtrl.text = opt.max?.toString() ?? '';
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: minCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    onChanged: (_) => setModalState(
                                      () => quickAmountKey = null,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '￥ ',
                                      hintText: '最小金额',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: cs.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: maxCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    onChanged: (_) => setModalState(
                                      () => quickAmountKey = null,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '￥ ',
                                      hintText: '最大金额',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: cs.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            buildSectionTitle('账户'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final a in commonAccounts)
                                  buildChoiceChip(
                                    label: a.name,
                                    selected: tempAccountIds.contains(a.id),
                                    onTap: () {
                                      setModalState(() {
                                        if (tempAccountIds.contains(a.id)) {
                                          tempAccountIds.remove(a.id);
                                        } else {
                                          tempAccountIds.add(a.id);
                                        }
                                      });
                                    },
                                  ),
                                buildChoiceChip(
                                  label: '全部账户${tempAccountIds.isEmpty ? '' : '（已选）'}',
                                  selected: tempAccountIds.isEmpty,
                                  onTap: () => setModalState(
                                    () => tempAccountIds.clear(),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: openAccountSelector,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceVariant.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: cs.primary,
                                        width: 1,
                                      ),
                                    ),
	                                    child: Text(
	                                      '更多',
	                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
	                                        color: cs.primary,
	                                        fontWeight: FontWeight.w700,
	                                        fontSize: 13,
	                                      ),
	                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: resetTemp,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: cs.outline.withOpacity(0.6),
                              ),
                              splashFactory: NoSplash.splashFactory,
                            ),
                            child: const Text('重置'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              splashFactory: NoSplash.splashFactory,
                            ),
                            onPressed: () {
                              final min =
                                  _currentMin(quickAmountKey, minCtrl.text);
                              final max =
                                  _currentMax(quickAmountKey, maxCtrl.text);
                              if (min != null && max != null && min > max) {
                                ErrorHandler.showError(context, '最小金额不能大于最大金额');
                                return;
                              }
                              if (tempStartDate != null &&
                                  tempEndDate != null &&
                                  tempStartDate!.isAfter(tempEndDate!)) {
                                ErrorHandler.showError(context, '开始日期不能大于结束日期');
                                return;
                              }
                              setState(() {
                                _filterCategoryKeys = tempCategoryKeys;
                                _filterAccountIds = tempAccountIds;
                                _filterIncomeExpense = tempIncomeExpense;
                                _minAmount = min;
                                _maxAmount = max;
                                _startDate = quickDateKey != null
                                    ? _getQuickDateRange(quickDateKey!)?.start
                                    : tempStartDate;
                                _endDate = quickDateKey != null
                                    ? _getQuickDateRange(quickDateKey!)?.end
                                    : tempEndDate;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text('查看 ${filteredCount()} 条结果'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Set<String>?> _openCategoryFullSheet({
    required BuildContext context,
    required List<Category> categories,
    required Map<String, Category> categoryMap,
    required Set<String> initialSelected,
    bool? incomeExpense,
  }) async {
    Set<String> selected = Set<String>.from(initialSelected);
    final tabs = categories.where((c) => c.parentKey == null).where((c) {
      if (incomeExpense == null) return true;
      return incomeExpense ? !c.isExpense : c.isExpense;
    }).toList();

    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final searchCtrl = TextEditingController();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.9,
            child: DefaultTabController(
              length: tabs.length,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  List<Category> childrenOf(Category parent) {
                    return categories
                        .where((c) => c.parentKey == parent.key)
                        .where((c) {
                          if (incomeExpense == null) return true;
                          return incomeExpense ? !c.isExpense : c.isExpense;
                        })
                        .toList();
                  }

                  Widget buildChildWrap(Category parent) {
                    final children = childrenOf(parent);
                    final keyword = searchCtrl.text.trim().toLowerCase();
                    final filtered = keyword.isEmpty
                        ? children
                        : children
                            .where(
                              (c) => c.name.toLowerCase().contains(keyword),
                            )
                            .toList();
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: filtered.map((c) {
                          final leafs = _leafKeysUnder(c.key, categoryMap);
                          final selectedAll = selected.containsAll(leafs);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (selectedAll) {
                                  selected.removeAll(leafs);
                                } else {
                                  selected.addAll(leafs);
                                }
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedAll
                                    ? cs.primary.withOpacity(0.15)
                                    : cs.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedAll
                                      ? cs.primary
                                      : cs.outline.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                c.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      selectedAll ? FontWeight.w700 : FontWeight.w500,
                                  color: selectedAll ? cs.primary : cs.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        decoration: BoxDecoration(
                          color: cs.outline.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '选择分类',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setSheetState(() => selected.clear());
                              },
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: '搜索分类',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      TabBar(
                        isScrollable: true,
                        labelColor: cs.primary,
                        unselectedLabelColor:
                            cs.onSurface.withOpacity(0.6),
                        tabs: [for (final t in tabs) Tab(text: t.name)],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            for (final t in tabs) buildChildWrap(t),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            Text(
                              '已选 ${selected.length} 个',
                            ),
                            const Spacer(),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                splashFactory: NoSplash.splashFactory,
                              ),
                              onPressed: () => Navigator.pop(ctx, selected),
                              child: const Text('确认'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Set<String>?> _openAccountMultiSelector({
    required BuildContext context,
    required List<Account> accounts,
    required Set<String> initialSelected,
  }) async {
    Set<String> selected = Set<String>.from(initialSelected);
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 10),
                      decoration: BoxDecoration(
                        color: cs.outline.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '选择账户',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                setSheetState(() => selected.clear()),
                            child: const Text('全部'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: accounts.length,
                        itemBuilder: (_, idx) {
                          final a = accounts[idx];
                          final checked = selected.contains(a.id);
                          return ListTile(
                            title: Text(a.name),
                            trailing: Checkbox(
                              value: checked,
                              onChanged: (_) {
                                setSheetState(() {
                                  if (checked) {
                                    selected.remove(a.id);
                                  } else {
                                    selected.add(a.id);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setSheetState(() {
                                if (checked) {
                                  selected.remove(a.id);
                                } else {
                                  selected.add(a.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Text(
                            '已选 ${selected.isEmpty ? '全部' : selected.length.toString()}',
                          ),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              splashFactory: NoSplash.splashFactory,
                            ),
                            onPressed: () => Navigator.pop(ctx, selected),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 应用筛选（账单页面暂时不需要复杂筛选，直接返回原列表）
  List<Record> _applyFilters(
    List<Record> records,
    Map<String, Category> categoryMap,
    {Map<String, List<Tag>>? tagsByRecordId}
  ) {
    // 账单明细只展示“收支记录”，不展示转账/借还款等不计入统计的记录
    var filtered = records
        .where((r) => r.includeInStats && !r.categoryKey.startsWith('transfer'))
        .toList();

    // 关键词搜索
    final keyword = _searchKeyword.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      filtered = filtered.where((r) {
        final remark = r.remark.toLowerCase();
        final categoryName =
            (categoryMap[r.categoryKey]?.name ?? '').toLowerCase();
        final amountStr = r.absAmount.toStringAsFixed(2);
        final tagHit = (tagsByRecordId?[r.id] ?? const <Tag>[])
            .any((t) => t.name.toLowerCase().contains(keyword));
        return remark.contains(keyword) ||
            categoryName.contains(keyword) ||
            amountStr.contains(keyword) ||
            tagHit;
      }).toList();
    }

    // 支持多分类筛选
    if (_filterCategoryKeys.isNotEmpty) {
      filtered = filtered
          .where((r) => _filterCategoryKeys.contains(r.categoryKey))
          .toList();
    }

    if (_filterAccountIds.isNotEmpty) {
      filtered = filtered
          .where((r) => _filterAccountIds.contains(r.accountId))
          .toList();
    }

    if (_minAmount != null) {
      filtered = filtered.where((r) => r.absAmount >= _minAmount!).toList();
    }

    if (_maxAmount != null) {
      filtered = filtered.where((r) => r.absAmount <= _maxAmount!).toList();
    }

    // 添加收入/支出筛选
    if (_filterIncomeExpense != null) {
      if (_filterIncomeExpense == true) {
        // 只看收入
        filtered = filtered.where((r) => r.isIncome).toList();
      } else {
        // 只看支出
        filtered = filtered.where((r) => r.isExpense).toList();
      }
    }

    // 添加日期范围筛选
    if (_startDate != null) {
      filtered = filtered.where((r) => !r.date.isBefore(_startDate!)).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((r) => !r.date.isAfter(_endDate!)).toList();
    }

    return filtered;
  }

  // 打开编辑记录页面
  void _openEditRecord(Record record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecordPage(
          initialRecord: record,
          isExpense: record.isExpense,
        ),
      ),
    );
  }

  // 确认并删除记录
  Future<void> _confirmAndDeleteRecord(Record record) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.delete),
            content: const Text('确定删除这条记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AppStrings.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();

      await recordProvider.deleteRecord(
        record.id,
        accountProvider: accountProvider,
      );

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '记录已删除');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
  }
}

// 搜索栏组件
class _BillSearchBar extends StatelessWidget {
  const _BillSearchBar({
    required this.controller,
    required this.focusNode,
    required this.keyword,
    required this.hasActiveFilter,
    required this.onChanged,
    required this.onSubmitted,
    required this.onTapFilter,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String keyword;
  final bool hasActiveFilter;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onTapFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasKeyword = keyword.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: AppStrings.searchHint,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            if (hasKeyword)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              IconButton(
                icon: Icon(
                  hasActiveFilter
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  size: 20,
                ),
                onPressed: onTapFilter,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

// 搜索建议面板组件
class _BillSearchSuggestionPanel extends StatelessWidget {
  const _BillSearchSuggestionPanel({
    required this.keyword,
    required this.history,
    required this.categories,
    required this.onTapHistory,
    required this.onClearHistory,
    required this.onTapCategory,
  });

  final String keyword;
  final List<String> history;
  final List<Category> categories;
  final ValueChanged<String> onTapHistory;
  final VoidCallback onClearHistory;
  final ValueChanged<Category> onTapCategory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kw = keyword.trim().toLowerCase();
    final hasHistory = history.isNotEmpty;
    final matchedCategories = kw.isEmpty
        ? <Category>[]
        : categories
            .where((c) => c.name.toLowerCase().contains(kw))
            .take(8)
            .toList();

    if (!hasHistory && matchedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outline.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHistory) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.recentSearches,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: onClearHistory,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppStrings.clearHistory,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...history.take(5).map(
                (item) => _buildHistoryItem(context, item, cs),
              ),
              if (matchedCategories.isNotEmpty)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withOpacity(0.1),
                ),
            ],
            if (matchedCategories.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  hasHistory ? 12 : 12,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.matchedCategories,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              ...matchedCategories.map(
                (c) => _buildCategoryItem(context, c, kw, cs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, String item, ColorScheme cs) {
    return InkWell(
      onTap: () => onTapHistory(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 18,
              color: cs.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: cs.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    Category category,
    String keyword,
    ColorScheme cs,
  ) {
    final name = category.name;
    final lowerName = name.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final index = lowerName.indexOf(lowerKeyword);

    Widget titleWidget;
    if (index == -1 || keyword.isEmpty) {
      titleWidget = Text(
        name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
      );
    } else {
      final before = name.substring(0, index);
      final match = name.substring(index, index + keyword.length);
      final after = name.substring(index + keyword.length);

      titleWidget = RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
          children: [
            TextSpan(text: before),
            TextSpan(
              text: match,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: after),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => onTapCategory(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.icon,
                size: 18,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 2),
                  Text(
                    category.isExpense ? AppStrings.expense : AppStrings.income,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: cs.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// 筛选摘要栏组件
class _BillFilterSummaryBar extends StatelessWidget {
  const _BillFilterSummaryBar({
    required this.summaryText,
    required this.onClearAll,
  });

  final String summaryText;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (summaryText.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summaryText,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onClearAll,
              child: Text(
                '清空筛选',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickOption {
  const _QuickOption({required this.key, required this.label});
  final String key;
  final String label;
}

class _QuickAmountOption {
  const _QuickAmountOption({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
  });
  final String key;
  final String label;
  final double? min;
  final double? max;
}
