import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../utils/date_utils.dart';
import '../models/period_type.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/home_budget_bar.dart';
import '../widgets/period_selector.dart';
import '../widgets/timeline_item.dart';
import '../widgets/week_strip.dart';
import 'add_record_page.dart';
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

  // 记录列表选择 / 批量删除状态
  bool _selectionMode = false;
  final Set<String> _selectedRecordIds = <String>{};
  List<Record> _currentVisibleRecords = const [];
  final Map<DateTime, GlobalKey> _dayHeaderKeys = {};
  final String _searchKeyword = '';
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

    final monthRecords = recordProvider.recordsForMonth(
      bookId,
      _selectedDay.year,
      _selectedDay.month,
    );
    final hasMonthRecords = monthRecords.isNotEmpty;
    final Map<String, Category> categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final filteredRecords = _applyFilters(monthRecords, categoryMap);
    _currentVisibleRecords = filteredRecords;

    debugPrint(
      'HomePage build duration: '
      '${DateTime.now().difference(start).inMilliseconds}ms',
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isToday = DateUtilsX.isToday(_selectedDay);
    final dateLabel = isToday
        ? '${AppStrings.today} ${DateUtilsX.ymd(_selectedDay)}'
        : DateUtilsX.ymd(_selectedDay);

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
                      const HomeBudgetBar(),
                      const SizedBox(height: 4),
                      if (_selectionMode)
                        _SelectionToolbar(
                          selectedCount: _selectedRecordIds.length,
                          totalCount: _currentVisibleRecords.length,
                          onExit: _exitSelectionMode,
                          onSelectAll: _handleSelectAll,
                          onDeleteSelected: _handleDeleteSelectedBatch,
                        ),
                      Expanded(
                        child: hasMonthRecords
                            ? _buildMonthTimeline(
                                filteredRecords,
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
      filtered =
          filtered.where((r) => r.categoryKey == _filterCategoryKey).toList();
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
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom + 16;

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
                    AppStrings.filter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    AppStrings.filterByCategory,
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
                          AppStrings.expenseCategory,
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
                              return _buildFilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey =
                                      selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          AppStrings.incomeCategory,
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
                              return _buildFilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey =
                                      selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ]
                      // 当用户选择了特定的收支类型时，只显示对应的分类
                      else if (tempIncomeExpense == false) ...[
                        const Text(
                          AppStrings.incomeCategory,
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
                              return _buildFilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey =
                                      selected ? null : c.key);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          AppStrings.expenseCategory,
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
                              return _buildFilterChip(
                                label: c.name,
                                selected: selected,
                                onSelected: () {
                                  setModalState(() => tempCategoryKey =
                                      selected ? null : c.key);
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
                    AppStrings.filterByAmount,
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
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '¥ ',
                            hintText: AppStrings.minAmount,
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
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '¥ ',
                            hintText: AppStrings.maxAmount,
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
                    AppStrings.filterByType,
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
                      _buildFilterChip(
                        label: AppStrings.all,
                        selected: tempIncomeExpense == null,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense = null);
                        },
                      ),
                      _buildFilterChip(
                        label: AppStrings.income,
                        selected: tempIncomeExpense == true,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense =
                              tempIncomeExpense == true ? null : true);
                        },
                      ),
                      _buildFilterChip(
                        label: AppStrings.expense,
                        selected: tempIncomeExpense == false,
                        onSelected: () {
                          setModalState(() => tempIncomeExpense =
                              tempIncomeExpense == false ? null : false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 添加日期范围筛选
                  const Text(
                    AppStrings.filterByDateRange,
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
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              labelText: AppStrings.startDate,
                            ),
                            child: Text(
                              tempStartDate == null
                                  ? AppStrings.pleaseSelect
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
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              labelText: AppStrings.endDate,
                            ),
                            child: Text(
                              tempEndDate == null
                                  ? AppStrings.pleaseSelect
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
                        child: const Text(AppStrings.reset),
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
                        child: const Text(AppStrings.confirm),
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

        _minAmount = minText.isEmpty ? null : double.tryParse(minText);
        _maxAmount = maxText.isEmpty ? null : double.tryParse(maxText);

        // 更新日期范围状态
        _startDate = result['startDate'] as DateTime?;
        _endDate = result['endDate'] as DateTime?;
      });
    }
  }

  // 自定义 FilterChip 组件，避免 ChoiceChip 的布局抖动问题
  Widget _buildFilterChip({
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
          color: selected ? cs.primary.withOpacity(0.2) : cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.5),
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

    if (_cachedRecords == records &&
        _cachedGroups != null &&
        _cachedDays != null) {
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
            AppStrings.monthDayWithCount(
              day.month,
              day.day,
              DateUtilsX.weekdayShort(day),
              dayRecords.length,
            );

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
                  final selected = _selectedRecordIds.contains(record.id);
                  return TimelineItem(
                    key: ValueKey(record.id), // 为每个项目添加唯一键
                    record: record,
                    category: categoryMap[record.categoryKey],
                    leftSide: false,
                    onTap: () => _handleRecordTap(record),
                    onLongPress: () => _handleRecordLongPress(record),
                    onDelete: () => _confirmAndDeleteSingle(record),
                    selectionMode: _selectionMode,
                    selected: selected,
                    onSelectedChanged: (value) =>
                        _toggleRecordSelection(record, value),
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
            AppStrings.emptyToday,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(AppStrings.quickAddHint),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openAddRecordPage,
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.quickAdd),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddRecordPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRecordPage()),
    );
  }

  void _handleRecordTap(Record record) {
    if (_selectionMode) {
      _toggleRecordSelection(record, !_selectedRecordIds.contains(record.id));
      return;
    }

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

  void _handleRecordLongPress(Record record) {
    if (_selectionMode) return;
    setState(() {
      _selectionMode = true;
      _selectedRecordIds
        ..clear()
        ..add(record.id);
    });
  }

  void _toggleRecordSelection(Record record, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecordIds.add(record.id);
      } else {
        _selectedRecordIds.remove(record.id);
        if (_selectedRecordIds.isEmpty) {
          _selectionMode = false;
        }
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedRecordIds.clear();
    });
  }

  void _handleSelectAll() {
    setState(() {
      _selectionMode = true;
      _selectedRecordIds
        ..clear()
        ..addAll(_currentVisibleRecords.map((e) => e.id));
    });
  }

  Future<void> _handleDeleteSelectedBatch() async {
    if (_selectedRecordIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.delete),
            content: Text('确定删除选中的 ${_selectedRecordIds.length} 条记录吗？'),
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

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final savingGoalProvider = context.read<SavingGoalProvider>();

    final ids = List<String>.from(_selectedRecordIds);
    for (final id in ids) {
      await recordProvider.deleteRecord(
        id,
        accountProvider: accountProvider,
        savingGoalProvider: savingGoalProvider,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${ids.length} 条记录')),
    );

    _exitSelectionMode();
  }

  Future<void> _confirmAndDeleteSingle(Record record) async {
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

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final savingGoalProvider = context.read<SavingGoalProvider>();

    await recordProvider.deleteRecord(
      record.id,
      accountProvider: accountProvider,
      savingGoalProvider: savingGoalProvider,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记录已删除')),
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

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onExit,
    required this.onSelectAll,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onExit;
  final VoidCallback onSelectAll;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text =
        selectedCount == 0 ? '选择记录' : '已选 $selectedCount 条记录';
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onExit,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: totalCount == 0 ? null : onSelectAll,
            child: Text(allSelected ? '全不选' : '全选'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: selectedCount == 0 ? null : onDeleteSelected,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text(AppStrings.delete),
          ),
        ],
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
                  child: buildAmountText(AppStrings.dayIncome, income),
                ),
              if (income > 0) const SizedBox(width: 8),
              Expanded(
                child: buildAmountText(AppStrings.dayExpense, expense),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildAmountText(AppStrings.dayBalance, net),
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
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    } else if (absValue >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    } else {
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
  });

  final double income;
  final double expense;
  final double balance;
  final String dateLabel;
  final VoidCallback onTapDate;
  final VoidCallback onTapSearch;

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
                PeriodSelector(
                  label: dateLabel,
                  periodType: PeriodType.month,
                  onTap: onTapDate,
                  compact: true,
                ),
                const BookSelectorButton(),
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
                        AppStrings.monthBalance,
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
                          label: AppStrings.income,
                          value: income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceMiniItem(
                          label: AppStrings.expense,
                          value: expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
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

// _ShortcutButton 已移除：顶部仅保留日期/账本/筛选，不再放账单/预算入口
