import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
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

enum HomeTimeRangeType {
  month,
  last3Months,
  year,
  all,
  custom,
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDay = DateTime.now();
  final ScrollController _monthScrollController = ScrollController();

  // 记录列表选择 / 批量删除状态
  bool _selectionMode = false;
  final Set<String> _selectedRecordIds = <String>{};
  List<Record> _currentVisibleRecords = const [];
  final Map<DateTime, GlobalKey> _dayHeaderKeys = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchKeyword = '';
  List<String> _searchHistory = <String>[];
  bool _showSuggestions = false;
  HomeTimeRangeType _timeRangeType = HomeTimeRangeType.month;
  Set<String> _filterCategoryKeys = {}; // 改为多选
  double? _minAmount;
  double? _maxAmount;
  // 添加新的筛选状态变量
  bool? _filterIncomeExpense; // null: 全部, true: 只看收入, false: 只看支出
  Set<String> _filterAccountIds = <String>{};
  DateTime? _startDate; // 日期范围开始
  DateTime? _endDate; // 日期范围结束

  // 添加缓存来存储每天的统计信息
  final Map<DateTime, _DayStats> _dayStatsCache = {};

  // 添加缓存来存储分组结果
  Map<DateTime, List<Record>>? _cachedGroups;
  List<DateTime>? _cachedDays;
  List<Record>? _cachedRecords;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _loadSearchHistory();
  }

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

    final timeRange = _currentTimeRange();
    final allRecords = recordProvider.recordsForPeriod(
      bookId,
      start: timeRange.start,
      end: timeRange.end,
    );
    final hasRecords = allRecords.isNotEmpty;
    final Map<String, Category> categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final filteredRecords = _applyFilters(allRecords, categoryMap);
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
        bottom: false, // 禁用底部 SafeArea，手动处理底部导航栏
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _HomeSearchBar(
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
                  _HomeSearchSuggestionPanel(
                    keyword: _searchKeyword,
                    history: _searchHistory,
                    categories: categoryProvider.categories,
                    onTapHistory: _applyHistoryKeyword,
                    onClearHistory: _clearSearchHistory,
                    onTapCategory: _applyCategorySuggestion,
                  ),
                _HomeQuickFiltersBar(
                  timeRangeType: _timeRangeType,
                  filterIncomeExpense: _filterIncomeExpense,
                  minAmount: _minAmount,
                  onSelectTimeRange: _handleQuickTimeRange,
                  onToggleIncomeOnly: _handleQuickIncomeOnly,
                  onToggleExpenseOnly: _handleQuickExpenseOnly,
                  onToggleHighExpense: _handleQuickHighExpense,
                ),
                if (_hasActiveFilterOrSearch)
                  _HomeFilterSummaryBar(
                    summaryText: _buildFilterSummaryText(),
                    onClearAll: _handleClearAllFilters,
                  ),
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
                        child: hasRecords
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
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  DateTimeRange _currentTimeRange() {
    final now = DateTime.now();
    switch (_timeRangeType) {
      case HomeTimeRangeType.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case HomeTimeRangeType.last3Months:
        final start = DateTime(now.year, now.month - 2, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case HomeTimeRangeType.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      case HomeTimeRangeType.all:
        return DateTimeRange(
          start: DateTime(2000, 1, 1),
          end: DateTime(2100, 12, 31),
        );
      case HomeTimeRangeType.custom:
        final start = _startDate ?? now;
        final end = _endDate ?? now;
        return DateTimeRange(start: start, end: end);
    }
  }

  bool get _hasActiveFilterOrSearch {
    final hasKeyword = _searchKeyword.trim().isNotEmpty;
    final hasCategory = _filterCategoryKeys.isNotEmpty;
    final hasAmount = _minAmount != null || _maxAmount != null;
    final hasType = _filterIncomeExpense != null;
    final hasAccounts = _filterAccountIds.isNotEmpty;
    final isDefaultRange =
        _timeRangeType == HomeTimeRangeType.month && _startDate == null && _endDate == null;
    return hasKeyword || hasCategory || hasAmount || hasType || hasAccounts || !isDefaultRange;
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
    final list = prefs.getStringList('home_search_history') ?? <String>[];
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
    await prefs.setStringList('home_search_history', history);
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('home_search_history');
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

  void _handleQuickTimeRange(HomeTimeRangeType type) {
    setState(() {
      _timeRangeType = type;
      if (type != HomeTimeRangeType.custom) {
        _startDate = null;
        _endDate = null;
      }
    });
  }

  void _handleQuickIncomeOnly() {
    setState(() {
      _filterIncomeExpense =
          _filterIncomeExpense == true ? null : true;
    });
  }

  void _handleQuickExpenseOnly() {
    setState(() {
      _filterIncomeExpense =
          _filterIncomeExpense == false ? null : false;
    });
  }

  void _handleQuickHighExpense() {
    const threshold = 500.0;
    setState(() {
      if (_minAmount != null && _minAmount == threshold) {
        _minAmount = null;
      } else {
        _minAmount = threshold;
      }
    });
  }

  void _handleClearAllFilters() {
    setState(() {
      _searchKeyword = '';
      _searchController.clear();
      _timeRangeType = HomeTimeRangeType.month;
      _startDate = null;
      _endDate = null;
      _filterCategoryKeys = <String>{};
      _minAmount = null;
      _maxAmount = null;
      _filterIncomeExpense = null;
      _filterAccountIds = <String>{};
      _showSuggestions = false;
    });
  }

  String _buildFilterSummaryText() {
    final parts = <String>[];
    final kw = _searchKeyword.trim();
    if (kw.isNotEmpty) {
      parts.add('“$kw”');
    }

    switch (_timeRangeType) {
      case HomeTimeRangeType.month:
        break;
      case HomeTimeRangeType.last3Months:
        parts.add('最近3个月');
        break;
      case HomeTimeRangeType.year:
        parts.add('今年');
        break;
      case HomeTimeRangeType.all:
        parts.add('全部时间');
        break;
      case HomeTimeRangeType.custom:
        if (_startDate != null && _endDate != null) {
          parts.add(
            '${DateUtilsX.ymd(_startDate!)} ~ ${DateUtilsX.ymd(_endDate!)}',
          );
        }
        break;
    }

    if (_filterIncomeExpense == true) {
      parts.add('仅收入');
    } else if (_filterIncomeExpense == false) {
      parts.add('仅支出');
    }

    if (_filterCategoryKeys.isNotEmpty) {
      parts.add('分类${_filterCategoryKeys.length}个');
    }

    if (_minAmount != null && _maxAmount != null) {
      parts.add(
        '金额 ${_minAmount!.toStringAsFixed(0)}~${_maxAmount!.toStringAsFixed(0)}',
      );
    } else if (_minAmount != null) {
      parts.add('金额≥${_minAmount!.toStringAsFixed(0)}');
    } else if (_maxAmount != null) {
      parts.add('金额≤${_maxAmount!.toStringAsFixed(0)}');
    }

    if (_filterAccountIds.isNotEmpty) {
      parts.add('账户${_filterAccountIds.length}个');
    }

    if (parts.isEmpty) {
      return '';
    }
    return '已筛选：${parts.join(' · ')}';
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
    if (_startDate != null && false) {
      filtered = filtered.where((r) => !r.date.isBefore(_startDate!)).toList();
    }

    if (_endDate != null && false) {
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
    final accounts = context.read<AccountProvider>().accounts;
    Set<String> tempCategoryKeys = Set<String>.from(_filterCategoryKeys);
    Set<String> tempAccountIds = Set<String>.from(_filterAccountIds);
    final minCtrl = TextEditingController(text: _minAmount?.toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxAmount?.toString() ?? '');
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
              // 根据收支类型过滤分类
              final filteredCategories = categories.where((c) {
                if (tempIncomeExpense == null) return true;
                return tempIncomeExpense == true ? !c.isExpense : c.isExpense;
              }).toList();

              return SafeArea(
                child: SingleChildScrollView(
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
                      const Text(
                        AppStrings.filter,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 分类多选
                      const Text(
                        AppStrings.filterByCategory,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: filteredCategories.map((c) {
                          final selected = tempCategoryKeys.contains(c.key);
                          return _buildFilterChip(
                            label: c.name,
                            selected: selected,
                            onSelected: () {
                              setModalState(() {
                                if (selected) {
                                  tempCategoryKeys.remove(c.key);
                                } else {
                                  tempCategoryKeys.add(c.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 金额范围
                      const Text(
                        AppStrings.filterByAmount,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
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

                      // 收支类型
                      const Text(
                        AppStrings.filterByType,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip(
                            label: AppStrings.all,
                            selected: tempIncomeExpense == null,
                            onSelected: () =>
                                setModalState(() => tempIncomeExpense = null),
                          ),
                          _buildFilterChip(
                            label: AppStrings.income,
                            selected: tempIncomeExpense == true,
                            onSelected: () => setModalState(() {
                              tempIncomeExpense =
                                  tempIncomeExpense == true ? null : true;
                            }),
                          ),
                          _buildFilterChip(
                            label: AppStrings.expense,
                            selected: tempIncomeExpense == false,
                            onSelected: () => setModalState(() {
                              tempIncomeExpense =
                                  tempIncomeExpense == false ? null : false;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 按账户筛选
                      const Text(
                        '按账户筛选',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: accounts.map((a) {
                          final selected = tempAccountIds.contains(a.id);
                          return _buildFilterChip(
                            label: a.name,
                            selected: selected,
                            onSelected: () {
                              setModalState(() {
                                if (selected) {
                                  tempAccountIds.remove(a.id);
                                } else {
                                  tempAccountIds.add(a.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 日期范围
                      const Text(
                        AppStrings.filterByDateRange,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
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
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
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

                      // 底部按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(AppStrings.cancel),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  minCtrl.clear();
                                  maxCtrl.clear();
                                  setModalState(() {
                                    tempCategoryKeys.clear();
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
                                  final minText = minCtrl.text.trim();
                                  final maxText = maxCtrl.text.trim();
                                  final double? min =
                                      minText.isEmpty ? null : double.tryParse(minText);
                                  final double? max =
                                      maxText.isEmpty ? null : double.tryParse(maxText);
                                  if (min != null && max != null && min > max) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('最小金额不能大于最大金额'),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop<Map<String, dynamic>>(ctx, {
                                    'categoryKeys':
                                        tempCategoryKeys.toList(), // 多选
                                    'min': minCtrl.text.trim(),
                                    'max': maxCtrl.text.trim(),
                                    'incomeExpense': tempIncomeExpense,
                                    'startDate': tempStartDate,
                                    'endDate': tempEndDate,
                                    'accountIds': tempAccountIds.toList(),
                                  });
                                },
                                child: const Text(AppStrings.confirm),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      final categoryKeysList = result['categoryKeys'] as List<dynamic>?;
      _filterCategoryKeys = categoryKeysList != null
          ? Set<String>.from(categoryKeysList.cast<String>())
          : <String>{};

      _filterIncomeExpense = result['incomeExpense'] as bool?;

      final accountIdsList = result['accountIds'] as List<dynamic>?;
      _filterAccountIds = accountIdsList != null
          ? Set<String>.from(accountIdsList.cast<String>())
          : <String>{};

      final minText = result['min'] as String;
      final maxText = result['max'] as String;
      _minAmount = minText.isEmpty ? null : double.tryParse(minText);
      _maxAmount = maxText.isEmpty ? null : double.tryParse(maxText);

      _startDate = result['startDate'] as DateTime?;
      _endDate = result['endDate'] as DateTime?;
      if (_startDate != null || _endDate != null) {
        _timeRangeType = HomeTimeRangeType.custom;
      } else {
        _timeRangeType = HomeTimeRangeType.month;
      }
    });
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

    // 计算底部 padding：系统安全区域 + 底部导航栏高度 + 额外安全边距
    final mediaQuery = MediaQuery.of(context);
    final systemBottomPadding = mediaQuery.viewPadding.bottom; // 系统底部安全区域
    const extraPadding = 16.0; // ???????????????????
    final bottomPadding = systemBottomPadding + extraPadding;
    
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16), // 增加底部 padding
        controller: _monthScrollController,
        // 使用 AlwaysScrollableScrollPhysics 确保可以滚动到底部
        physics: const AlwaysScrollableScrollPhysics(),
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

          final dateLabel = AppStrings.monthDayWithCount(
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
              // 对于每天的记录列表，使用 shrinkWrap 让高度自适应，避免估算高度导致底部被裁剪
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayRecords.length,
                itemBuilder: (context, index) {
                  final record = dayRecords[index];
                  final selected = _selectedRecordIds.contains(record.id);
                  return TimelineItem(
                    key: ValueKey(record.id),
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
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: days.length,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
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

    final ids = List<String>.from(_selectedRecordIds);
    for (final id in ids) {
      await recordProvider.deleteRecord(
        id,
        accountProvider: accountProvider,
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

    await recordProvider.deleteRecord(
      record.id,
      accountProvider: accountProvider,
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

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
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
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜索备注、分类、金额（支持跨月）',
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

class _HomeQuickFiltersBar extends StatelessWidget {
  const _HomeQuickFiltersBar({
    required this.timeRangeType,
    required this.filterIncomeExpense,
    required this.minAmount,
    required this.onSelectTimeRange,
    required this.onToggleIncomeOnly,
    required this.onToggleExpenseOnly,
    required this.onToggleHighExpense,
  });

  final HomeTimeRangeType timeRangeType;
  final bool? filterIncomeExpense;
  final double? minAmount;
  final ValueChanged<HomeTimeRangeType> onSelectTimeRange;
  final VoidCallback onToggleIncomeOnly;
  final VoidCallback onToggleExpenseOnly;
  final VoidCallback onToggleHighExpense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildChip(
            context,
            label: '本月',
            selected: timeRangeType == HomeTimeRangeType.month,
            onTap: () => onSelectTimeRange(HomeTimeRangeType.month),
          ),
          _buildChip(
            context,
            label: '最近3个月',
            selected: timeRangeType == HomeTimeRangeType.last3Months,
            onTap: () => onSelectTimeRange(HomeTimeRangeType.last3Months),
          ),
          _buildChip(
            context,
            label: '今年',
            selected: timeRangeType == HomeTimeRangeType.year,
            onTap: () => onSelectTimeRange(HomeTimeRangeType.year),
          ),
          _buildChip(
            context,
            label: '全部时间',
            selected: timeRangeType == HomeTimeRangeType.all,
            onTap: () => onSelectTimeRange(HomeTimeRangeType.all),
          ),
          _buildChip(
            context,
            label: '仅支出',
            selected: filterIncomeExpense == false,
            onTap: onToggleExpenseOnly,
          ),
          _buildChip(
            context,
            label: '仅收入',
            selected: filterIncomeExpense == true,
            onTap: onToggleIncomeOnly,
          ),
          _buildChip(
            context,
            label: '大额支出',
            selected: minAmount != null && minAmount! >= 500,
            onTap: onToggleHighExpense,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.12) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? cs.primary : cs.onSurface.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

class _HomeFilterSummaryBar extends StatelessWidget {
  const _HomeFilterSummaryBar({
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
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onClearAll,
              child: const Text(
                '清空筛选',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchSuggestionPanel extends StatelessWidget {
  const _HomeSearchSuggestionPanel({
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
    final kw = keyword.trim().toLowerCase();
    final hasHistory = history.isNotEmpty;
    final matchedCategories = kw.isEmpty
        ? <Category>[]
        : categories
            .where(
              (c) => c.name.toLowerCase().contains(kw),
            )
            .take(5)
            .toList();

    if (!hasHistory && matchedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHistory) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '最近搜索',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: onClearHistory,
                    child: const Text(
                      '清空',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              ...history.take(5).map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(
                    item,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => onTapHistory(item),
                ),
              ),
              if (matchedCategories.isNotEmpty) const Divider(height: 8),
            ],
            if (matchedCategories.isNotEmpty) ...[
              const Text(
                '匹配的分类',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...matchedCategories.map(
                (c) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(c.icon, size: 18),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    c.isExpense ? '支出' : '收入',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => onTapCategory(c),
                ),
              ),
            ],
          ],
        ),
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
                    child: Icon(Icons.filter_alt_outlined,
                        size: 20, color: cs.onSurface),
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
