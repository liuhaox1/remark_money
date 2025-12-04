import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';

import '../providers/book_provider.dart';

import '../providers/category_provider.dart';

import '../providers/record_provider.dart';

import '../providers/account_provider.dart';

import '../utils/date_utils.dart';
import '../utils/error_handler.dart';

import '../models/period_type.dart';
import '../theme/app_tokens.dart';

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

    // 检查加载状态
    if (!recordProvider.loaded || !categoryProvider.loaded || !bookProvider.loaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111418)
            : const Color(0xFFF3F4F6),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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

        child: Align(

          alignment: Alignment.topCenter,

          child: ConstrainedBox(

            constraints: const BoxConstraints(maxWidth: 430),

            child: SingleChildScrollView(

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

                  hasRecords

                            ? _buildMonthTimeline(

                                filteredRecords,

                                categoryMap,

                              )

                            : _buildEmptyState(context),

                    ],

                  ),

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

      if (_timeRangeType == type && type != HomeTimeRangeType.month) {

        _timeRangeType = HomeTimeRangeType.month;

      } else {

        _timeRangeType = type;

      }

      if (_timeRangeType != HomeTimeRangeType.custom) {

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



  // 快捷金额选项的辅助方法

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



  // 快捷日期选项的辅助方法

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



  // 计算筛选结果数量的辅助方法

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



  // 已选条件标签

  Widget _buildSelectedTag(String label, VoidCallback onRemove, ColorScheme cs) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(

        color: cs.primaryContainer,

        borderRadius: BorderRadius.circular(16),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Text(

            label,

            style: Theme.of(context).textTheme.bodyMedium?.copyWith(

              color: cs.onPrimaryContainer,

            ),

          ),

          const SizedBox(width: 6),

          GestureDetector(

            onTap: onRemove,

            child: Icon(

              Icons.close,

              size: 14,

              color: cs.onPrimaryContainer,

            ),

          ),

        ],

      ),

    );

  }



  // 分类分组组件
  // ignore: unused_element
  Widget _buildCategoryGroup(
    Category topCategory,

    List<Category> children,

    Set<String> selectedKeys,

    ValueChanged<String> onToggle,

    ColorScheme cs,

  ) {

    final isExpanded = true; // 默认展开，后续可以添加折叠功能

    final selectedCount = children.where((c) => selectedKeys.contains(c.key)).length;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const SizedBox(height: 8),

        Row(

          children: [

            Icon(

              topCategory.icon,

              size: 16,

              color: cs.primary,

            ),

            const SizedBox(width: 6),

            Expanded(

              child: Text(

                topCategory.name,

                style: Theme.of(context).textTheme.bodyLarge?.copyWith(

                  fontWeight: FontWeight.w600,

                  color: cs.onSurface,

                ),

              ),

            ),

            if (selectedCount > 0)

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                decoration: BoxDecoration(

                  color: cs.primary,

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Text(

                  '$selectedCount',

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(

                    color: cs.onPrimary,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

          ],

        ),

        if (isExpanded) ...[

          const SizedBox(height: 8),

          Wrap(

            spacing: 6,

            runSpacing: 6,

            children: children.map((c) {

              final selected = selectedKeys.contains(c.key);

              return _buildFilterChip(

                label: c.name,

                selected: selected,

                onSelected: () => onToggle(c.key),

              );

            }).toList(),

          ),

        ],

      ],

    );

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

          style: Theme.of(context).textTheme.bodyMedium?.copyWith(

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

        shrinkWrap: true,

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

              Text(
                AppStrings.emptyToday,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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

    try {
      for (final id in ids) {
        await recordProvider.deleteRecord(
          id,
          accountProvider: accountProvider,
        );
      }

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已删除 ${ids.length} 条记录');
      _exitSelectionMode();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }

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



    Future<void> _openFilterSheet() async {
    final categories = context.read<CategoryProvider>().categories;
    final accounts = context.read<AccountProvider>().accounts;
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final bookId = bookProvider.activeBookId;
    final categoryMap = {for (final c in categories) c.key: c};

    final baseRange = _startDate != null || _endDate != null
        ? DateTimeRange(
            start: _startDate ?? _currentTimeRange().start,
            end: _endDate ?? _currentTimeRange().end,
          )
        : _currentTimeRange();
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
                    lastDate: DateTime(now.year + 2, 12, 31),
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? cs.primary : cs.onSurface,
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
                        const Text(
                          '高级筛选',
                          style: TextStyle(
                            fontSize: 16,
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '预计找到 ${filteredCount()} 条记录',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                                style: const TextStyle(
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                      style: TextStyle(
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
                                _timeRangeType = HomeTimeRangeType.custom;
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

  double? _currentMin(String? quickKey, String textValue) {
    if (quickKey != null) return _getQuickAmountMin(quickKey);
    return textValue.trim().isEmpty ? null : double.tryParse(textValue.trim());
  }

  double? _currentMax(String? quickKey, String textValue) {
    if (quickKey != null) return _getQuickAmountMax(quickKey);
    return textValue.trim().isEmpty ? null : double.tryParse(textValue.trim());
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
          ? ['工資', '理財', '禮金', '退款', '兼職']
          : ['餐飲', '購物', '交通', '日用', '居住', '娛樂'];
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
                                style: TextStyle(
                                  fontWeight: selectedAll
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selectedAll
                                      ? cs.primary
                                      : cs.onSurface,
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
                            const Text(
                              '选择分类',
                              style: TextStyle(
                                fontSize: 16,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
  }) {
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
                          const Text(
                            '选择账户',
                            style: TextStyle(
                              fontSize: 16,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
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

    final cs = Theme.of(context).colorScheme;

    final kw = keyword.trim().toLowerCase();

    final hasHistory = history.isNotEmpty;

    final matchedCategories = kw.isEmpty

        ? <Category>[]

        : categories

            .where(

              (c) => c.name.toLowerCase().contains(kw),

            )

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

              color: Colors.black.withOpacity(0.04),

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

                          style: TextStyle(

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

                        style: TextStyle(

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

                      style: TextStyle(

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

                style: TextStyle(

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

        style: TextStyle(

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

          style: TextStyle(

            fontSize: 14,

            fontWeight: FontWeight.w500,

            color: cs.onSurface,

          ),

          children: [

            TextSpan(text: before),

            TextSpan(

              text: match,

              style: TextStyle(

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

                    style: TextStyle(

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

              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,

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

/// 让桌面端（Windows/macOS/Linux）支持鼠标拖动进行滚动
class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
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

    final valueColor = AppColors.amount(balance);



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

                      Text(

                        AppStrings.monthBalance,

                        style: TextStyle(

                          fontSize: 12,

                          fontWeight: FontWeight.w600,

                          color: cs.onSurface.withOpacity(0.7),

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

    final cs = Theme.of(context).colorScheme;
    Color valueColor;
    if (label == AppStrings.expense) {
      valueColor = AppColors.danger;
    } else if (label == AppStrings.income) {
      valueColor = AppColors.success;
    } else {
      valueColor = AppColors.amount(value);
    }



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withOpacity(0.65),
          ),

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

