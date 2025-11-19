import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/timeline_item.dart';
import '../widgets/week_strip.dart';
import '../widgets/quick_add_sheet.dart';
import 'home_page_date_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// 添加用于缓存每天统计信息的类
class _DayStats {
  final double totalIncome;
  final double totalExpense;
  final double totalBalance;

  const _DayStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalBalance,
  });
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDay = DateTime.now();
  final ScrollController _monthScrollController = ScrollController();
  final Map<DateTime, GlobalKey> _dayHeaderKeys = {};
  String _searchKeyword = '';
  String? _filterCategoryKey;
  double? _minAmount;
  double? _maxAmount;
  // 添加新的筛选状态变量
  bool? _filterIncomeExpense; // null: 全部, true: 只看收入, false: 只看支出
  DateTime? _startDate; // 日期范围开始
  DateTime? _endDate; // 日期范围结束
  
  // 添加缓存来存储每天的统计信息
  final Map<DateTime, _DayStats> _dayStatsCache = {};
  
  // 添加缓存来存储分组结果
  Map<DateTime, List<Record>>? _cachedGroups;
  List<DateTime>? _cachedDays;
  List<Record>? _cachedRecords;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now();
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;

    final selectedMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final monthIncome = recordProvider.monthIncome(selectedMonth, bookId);
    final monthExpense = recordProvider.monthExpense(selectedMonth, bookId);
    final monthBalance = monthIncome - monthExpense;

    final dayRecords = recordProvider.recordsForDay(bookId, _selectedDay);
    final monthRecords = recordProvider.recordsForMonth(
      bookId,
      _selectedDay.year,
      _selectedDay.month,
    );
    final hasMonthRecords = monthRecords.isNotEmpty;
    final Map<String, Category> categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };

    debugPrint(
      'HomePage build duration: '
      '${DateTime.now().difference(start).inMilliseconds}ms',
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isToday = DateUtilsX.isToday(_selectedDay);
    final dateLabel =
        isToday ? '今天 ${DateUtilsX.ymd(_selectedDay)}' : DateUtilsX.ymd(_selectedDay);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _BalanceCard(
                  income: monthIncome,
                  expense: monthExpense,
                  balance: monthBalance,
                  dateLabel: dateLabel,
                  onTapDate: _pickDate,
                  onTapSearch: _openFilterSheet,
                  bookProvider: bookProvider,
                ),
                const SizedBox(height: 8),
                WeekStrip(
                  selectedDay: _selectedDay,
                  onSelected: _onDaySelected,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    children: [
                      const _BudgetBanner(),
                      const SizedBox(height: 4),
                      Expanded(
                        child: hasMonthRecords
                            ? _buildMonthTimeline(
                                _applyFilters(monthRecords, categoryMap),
                                categoryMap,
                              )
                            : _buildEmptyState(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime day) {
    setState(() => _selectedDay = day);
    _clearCache(); // 清除缓存
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDayInMonthList(day);
    });
  }

  void _scrollToDayInMonthList(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final key = _dayHeaderKeys[normalized];
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  bool get _hasActiveFilter =>
      _filterCategoryKey != null || _minAmount != null || _maxAmount != null || 
      _filterIncomeExpense != null || _startDate != null || _endDate != null;

  List<Record> _applyFilters(
    List<Record> records,
    Map<String, Category> categoryMap,
  ) {
    var filtered = records;

    // 现有的分类和金额筛选
    final keyword = _searchKeyword.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      filtered = filtered.where((r) {
        final remark = r.remark.toLowerCase();
        final categoryName =
            (categoryMap[r.categoryKey]?.name ?? '').toLowerCase();
        final amountStr = r.absAmount.toStringAsFixed(2);
        return remark.contains(keyword) ||
            categoryName.contains(keyword) ||
            amountStr.contains(keyword);
      }).toList();
    }

    if (_filterCategoryKey != null) {
      filtered = filtered
          .where((r) => r.categoryKey == _filterCategoryKey)
          .toList();
    }

    if (_minAmount != null) {
      filtered =
          filtered.where((r) => r.absAmount >= _minAmount!).toList();
    }

    if (_maxAmount != null) {
      filtered =
          filtered.where((r) => r.absAmount <= _maxAmount!).toList();
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
    
    // 清除缓存，因为筛选条件已更改
    _clearCache();

    return filtered;
  }
  
  // 添加清除缓存的方法
  void _clearCache() {
    _cachedGroups = null;
    _cachedDays = null;
    _cachedRecords = null;
    _dayStatsCache.clear();
  }

  Future<void> _openFilterSheet() async {
    final categories = context.read<CategoryProvider>().categories;
    String? tempCategoryKey = _filterCategoryKey;
    final minCtrl = TextEditingController(
      text: _minAmount != null ? _minAmount!.toString() : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxAmount != null ? _maxAmount!.toString() : '',
    );
    // 添加新的控制器和状态变量
    bool? tempIncomeExpense = _filterIncomeExpense;
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final bottomPadding =
            MediaQuery.of(ctx).viewInsets.bottom + 16;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '筛选',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '按分类',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 改进分类筛选：将收入和支出分类分开显示
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 只有当用户没有选择特定的收支类型时，才显示所有分类
                      if (tempIncomeExpense == null) ...[
                        const Text(
                          '支出分类',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.where((c) => c.isExpense).map((c) {
                              final selected = tempCategoryKey == c.key;
                              return _FilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey = selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '收入分类',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.where((c) => !c.isExpense).map((c) {
                              final selected = tempCategoryKey == c.key;
                              return _FilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey = selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ] 
                      // 当用户选择了特定的收支类型时，只显示对应的分类
                      else if (tempIncomeExpense == false) ...[
                        const Text(
                          '收入分类',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.where((c) => !c.isExpense).map((c) {
                              final selected = tempCategoryKey == c.key;
                              return _FilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey = selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          '支出分类',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.where((c) => c.isExpense).map((c) {
                              final selected = tempCategoryKey == c.key;
                              return _FilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey = selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '按金额区间（绝对值）',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '¥ ',
                            hintText: '最小金额',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
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
                                  decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '¥ ',
                            hintText: '最大金额',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 添加收入/支出筛选
                  const Text(
                    '按收支类型',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 使用自定义组件替换 ChoiceChip 以避免布局抖动
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: '全部',
                        selected: tempIncomeExpense == null,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense = null);
                        },
                      ),
                      _FilterChip(
                        label: '收入',
                        selected: tempIncomeExpense == true,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense = tempIncomeExpense == true ? null : true);
                        },
                      ),
                      _FilterChip(
                        label: '支出',
                        selected: tempIncomeExpense == false,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense = tempIncomeExpense == false ? null : false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 添加日期范围筛选
                  const Text(
                    '按日期范围',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setModalState(() => tempStartDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              labelText: '开始日期',
                            ),
                            child: Text(
                              tempStartDate == null
                                  ? '请选择'
                                  : '${tempStartDate!.year}-${tempStartDate!.month.toString().padLeft(2, '0')}-${tempStartDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('~'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: tempEndDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setModalState(() => tempEndDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              labelText: '结束日期',
                            ),
                            child: Text(
                              tempEndDate == null
                                  ? '请选择'
                                  : '${tempEndDate!.year}-${tempEndDate!.month.toString().padLeft(2, '0')}-${tempEndDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          minCtrl.clear();
                          maxCtrl.clear();
                          setModalState(() {
                            tempCategoryKey = null;
                            tempIncomeExpense = null;
                            tempStartDate = null;
                            tempEndDate = null;
                          });
                        },
                        child: const Text('重置'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop<Map<String, dynamic>>(ctx, {
                            'categoryKey': tempCategoryKey,
                            'min': minCtrl.text.trim(),
                            'max': maxCtrl.text.trim(),
                            'incomeExpense': tempIncomeExpense,
                            'startDate': tempStartDate,
                            'endDate': tempEndDate,
                          });
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _filterCategoryKey = result['categoryKey'] as String?;
        _filterIncomeExpense = result['incomeExpense'] as bool?;

        final minText = result['min'] as String;
        final maxText = result['max'] as String;

        _minAmount =
            minText.isEmpty ? null : double.tryParse(minText);
        _maxAmount =
            maxText.isEmpty ? null : double.tryParse(maxText);
            
        // 更新日期范围状态
        _startDate = result['startDate'] as DateTime?;
        _endDate = result['endDate'] as DateTime?;
      });
    }
  }

  // 自定义 FilterChip 组件，避免 ChoiceChip 的布局抖动问题
  Widget _FilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected 
              ? cs.primary.withOpacity(0.2) 
              : cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected 
                ? cs.primary 
                : cs.outline.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(
    List<Record> records,
    Map<String, Category> categoryMap,
  ) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final day = records.first.date;
    final dateLabel = '${day.month}月${day.day}日';
    final weekdayLabel = DateUtilsX.weekdayShort(day); // 日 / 一 / 二 ...
    final totalExpense = records
        .where((r) => r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);
    final totalIncome = records
        .where((r) => !r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DayHeader(
            dateLabel: '$dateLabel  周$weekdayLabel',
            income: totalIncome,
            expense: totalExpense,
          );
        }
        final record = records[index - 1];
        return TimelineItem(
          record: record,
          category: categoryMap[record.categoryKey],
          leftSide: index.isEven,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemCount: records.length + 1,
    );
  }

  Widget _buildTimelineWithSummary(
    List<Record> records,
    Map<String, Category> categoryMap,
  ) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final day = records.first.date;
    final dateLabel = '${day.month}月${day.day}日';
    final weekdayLabel = DateUtilsX.weekdayShort(day);
    final totalExpense = records
        .where((r) => r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);
    final totalIncome = records
        .where((r) => !r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);
    final totalBalance = totalIncome - totalExpense;
    final count = records.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DayHeader(
            dateLabel: '$dateLabel  $weekdayLabel · 共$count笔',
            income: totalIncome,
            expense: totalExpense,
            balance: totalBalance,
          );
        }
        final record = records[index - 1];
        return TimelineItem(
          record: record,
          category: categoryMap[record.categoryKey],
          leftSide: index.isEven,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemCount: records.length + 1,
    );
  }

  /// 按「整月」展示记录，按日期分组，最新的日期在最上方
  Widget _buildMonthTimeline(
    List<Record> records,
    Map<String, Category> categoryMap,
  ) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    // 检查是否可以使用缓存的结果
    Map<DateTime, List<Record>> groups;
    List<DateTime> days;
    
    if (_cachedRecords == records && _cachedGroups != null && _cachedDays != null) {
      // 使用缓存的结果
      groups = _cachedGroups!;
      days = _cachedDays!;
    } else {
      // 重新计算分组
      groups = {};
      for (final r in records) {
        final day = DateTime(r.date.year, r.date.month, r.date.day);
        groups.putIfAbsent(day, () => <Record>[]).add(r);
      }

      // 按日期倒序（最近的天在上面）
      days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
      
      // 更新缓存
      _cachedRecords = records;
      _cachedGroups = groups;
      _cachedDays = days;
    }

    // 清除不再需要的日期统计缓存
    _dayStatsCache.removeWhere((key, value) => !days.contains(key));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      controller: _monthScrollController,
      // 添加一些性能优化属性
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      cacheExtent: 1000, // 缓存更多内容以减少重新构建
      itemBuilder: (context, index) {
        final day = days[index];
        final dayRecords = groups[day]!;

        // 获取或计算当天的统计信息
        _DayStats dayStats;
        if (_dayStatsCache.containsKey(day)) {
          dayStats = _dayStatsCache[day]!;
        } else {
          final totalExpense = dayRecords
              .where((r) => r.isExpense)
              .fold<double>(0, (sum, r) => sum + r.absAmount);
          final totalIncome = dayRecords
              .where((r) => !r.isExpense)
              .fold<double>(0, (sum, r) => sum + r.absAmount);
          final totalBalance = totalIncome - totalExpense;
          
          dayStats = _DayStats(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            totalBalance: totalBalance,
          );
          
          // 缓存统计信息
          _dayStatsCache[day] = dayStats;
        }

        final normalized = DateTime(day.year, day.month, day.day);
        final headerKey =
            _dayHeaderKeys.putIfAbsent(normalized, () => GlobalKey());

        final dateLabel =
            '${day.month}月${day.day}日  ${DateUtilsX.weekdayShort(day)} · 共${dayRecords.length}笔';

        // 使用 ListView.builder 来优化大量记录的显示
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(
              key: headerKey,
              dateLabel: dateLabel,
              income: dayStats.totalIncome,
              expense: dayStats.totalExpense,
              balance: dayStats.totalBalance,
            ),
            const SizedBox(height: 2),
            // 对于每天的记录列表，也使用 ListView.builder
            SizedBox(
              height: dayRecords.length * 36.0, // 预估每条记录的高度
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(), // 禁止内部滚动
                itemCount: dayRecords.length,
                itemBuilder: (context, index) {
                  final record = dayRecords[index];
                  return TimelineItem(
                    key: ValueKey(record.id), // 为每个项目添加唯一键
                    record: record,
                    category: categoryMap[record.categoryKey],
                    leftSide: false,
                  );
                },
              ),
            ),
          ],
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: days.length,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 72, color: cs.outline),
          const SizedBox(height: 12),
          const Text(
            '今天还没有记账',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('可以点击下方按钮快速记一笔'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openQuickAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('快捷记一笔'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }

  Future<void> _pickDate() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DatePanel(
        selectedDay: _selectedDay,
        onDayChanged: (day) {
          setState(() => _selectedDay = day);
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    Key? key,
    required this.dateLabel,
    required this.income,
    required this.expense,
    this.balance,
  }) : super(key: key);

  final String dateLabel;
  final double income;
  final double expense;
  final double? balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final net = (balance ?? (income - expense));
    final labelColor = cs.onSurface.withOpacity(0.7);

    // 为数字创建一个可重用的文本组件
    Widget buildAmountText(String label, double value) {
      final formattedValue = _NumberFormatter.format(value);
      final textStr = '$label $formattedValue';
      double fontSize = 11;
      if (textStr.length > 12) {
        fontSize = 9;
      } else if (textStr.length > 10) {
        fontSize = 10;
      }

      return Text(
        textStr,
        style: TextStyle(
          fontSize: fontSize,
          color: labelColor,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (income > 0)
                Expanded(
                  child: buildAmountText('当日收入', income),
                ),
              if (income > 0) const SizedBox(width: 8),
              Expanded(
                child: buildAmountText('当日支出', expense),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildAmountText('当日结余', net),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberFormatter {
  static String format(double value) {
    final absValue = value.abs();
    if (absValue >= 100000000) {
      // 1亿以上显示为 1.2亿
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (absValue >= 10000) {
      // 1万以上显示为 1.2万
      return '${(value / 10000).toStringAsFixed(1)}万';
    } else {
      // 普通数字显示，最多保留两位小数
      return value.toStringAsFixed(2);
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.dateLabel,
    required this.onTapDate,
    required this.onTapSearch,
    required this.bookProvider,
  });

  final double income;
  final double expense;
  final double balance;
  final String dateLabel;
  final VoidCallback onTapDate;
  final VoidCallback onTapSearch;
  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final valueColor = cs.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.18),
                    Colors.white,
                  ],
                ),
          color: isDark ? cs.surface : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onTapDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isDark ? 0.04 : 0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          dateLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more, size: 14),
                      ],
                    ),
                  ),
                ),
                _BookSelector(bookProvider: bookProvider),
                // 修复按钮抖动问题：使用 InkWell 替代 IconButton
                InkWell(
                  onTap: onTapSearch,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.search, size: 20, color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本月结余',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _NumberFormatter.format(balance),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _BalanceMiniItem(
                          label: '收入',
                          value: income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceMiniItem(
                          label: '支出',
                          value: expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ShortcutButton(
                      icon: Icons.receipt_long,
                      label: '账单',
                      onTap: () => Navigator.pushNamed(context, '/bill'),
                    ),
                    const SizedBox(width: 8),
                    _ShortcutButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '预算',
                      onTap: () => Navigator.pushNamed(context, '/budget'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMiniItem extends StatelessWidget {
  const _BalanceMiniItem({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final valueColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          _NumberFormatter.format(value),
          style: TextStyle(
            fontSize: 18, // 固定字体大小
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cs.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({required this.bookProvider});

  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeName = bookProvider.activeBook?.name ?? '默认账本';
    return InkWell(
      onTap: () => _showBookPicker(context),
      borderRadius: BorderRadius.circular(20),
      // 关闭水波纹和高亮，不要那颗突兀的白圈
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? cs.surface : Colors.white,
          border: Border.all(color: cs.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final recordProvider = ctx.read<RecordProvider>();
        final bp = ctx.watch<BookProvider>();
        final books = bp.books;
        final activeId = bp.activeBookId;
        final activeName = bp.activeBook?.name ?? '默认账本';
        final now = DateTime.now();
        final month = DateTime(now.year, now.month, 1);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '选择账本',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前：$activeName',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '新建账本',
                      onPressed: () => _showAddBookDialog(ctx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...books.map(
                  (book) {
                    final selected = book.id == activeId;
                    final recordCount =
                        recordProvider.recordsForBook(book.id).length;
                    final monthExpense =
                        recordProvider.monthExpense(month, book.id);
                    final subtitle = recordCount > 0
                        ? '本月支出 ${monthExpense.toStringAsFixed(2)} · 共 $recordCount 笔'
                        : '本月暂无记账';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: selected
                            ? cs.primary.withOpacity(0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: RadioListTile<String>(
                          value: book.id,
                          groupValue: activeId,
                          onChanged: (value) async {
                            if (value != null) {
                              await bp.selectBook(value);
                              Navigator.pop(ctx);
                            }
                          },
                          title: Text(book.name),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                          secondary: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: '重命名账本',
                                onPressed: () => _showRenameBookDialog(
                                  ctx,
                                  book.id,
                                  book.name,
                                ),
                              ),
                              if (books.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  tooltip: '删除账本',
                                  onPressed: () =>
                                      _confirmDeleteBook(ctx, book.id),
                                ),
                            ],
                          ),
                          activeColor: cs.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('新建账本'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '账本名称'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await bookProvider.addBook(controller.text.trim());
              if (Navigator.of(dialogCtx).canPop()) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameBookDialog(
    BuildContext context,
    String id,
    String initialName,
  ) async {
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('重命名账本'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '账本名称'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await bookProvider.renameBook(id, controller.text.trim());
              if (Navigator.of(dialogCtx).canPop()) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBook(
    BuildContext context,
    String id,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('删除账本'),
        content: const Text('删除后不可恢复，确认删除该账本吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await bookProvider.deleteBook(id);
              if (Navigator.of(dialogCtx).canPop()) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final budget = context.watch<BudgetProvider>().budget;
    if (budget.total > 0) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.amber.withOpacity(0.18)
            : Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '预算尚未设置，可前往「预算」添加上限，及时掌握支出节奏。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
