import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../l10n/app_strings.dart';
import '../models/period_type.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../providers/category_provider.dart';
import '../utils/date_utils.dart';
import '../utils/category_name_helper.dart';
import '../theme/brand_theme.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/period_selector.dart';
import '../widgets/chart_entry.dart';
import '../widgets/chart_line.dart';
import 'add_record_page.dart';
import 'bill_page.dart';
import 'report_detail_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  int _selectedYear = DateTime.now().year;
  PeriodType _periodType = PeriodType.month;

  String? _yearAnalysisKey;
  Future<Map<String, dynamic>>? _yearAnalysisFuture;
  Map<String, dynamic>? _yearAnalysisCache;

  String? _deepAnalysisKey;
  Future<Map<String, dynamic>>? _deepAnalysisFuture;
  final Map<String, Map<String, dynamic>> _deepAnalysisCacheByKey = {};

  void _ensureYearAnalysisFuture({
    required RecordProvider recordProvider,
    required String bookId,
    required List<DateTime> months,
    required bool isCurrentYear,
    required DateTime now,
    required int recordChangeCounter,
  }) {
    final key = '$bookId:${_selectedYear}:$recordChangeCounter:${isCurrentYear ? 1 : 0}';
    if (_yearAnalysisKey == key && _yearAnalysisFuture != null) return;
    _yearAnalysisKey = key;
    _yearAnalysisFuture =
        _loadYearAnalysisData(recordProvider, bookId, months, isCurrentYear, now);
  }

  void _ensureDeepAnalysisFuture({
    required RecordProvider recordProvider,
    required CategoryProvider categoryProvider,
    required String bookId,
    required int recordChangeCounter,
    required int categorySignature,
  }) {
    final key =
        '$bookId:${_selectedYear}:${_periodType.name}:$recordChangeCounter:$categorySignature';
    if (_deepAnalysisKey == key && _deepAnalysisFuture != null) return;
    _deepAnalysisKey = key;
    _deepAnalysisFuture = _loadDeepAnalysis(
      recordProvider,
      bookId,
      _selectedYear,
      _periodType,
      categoryProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final recordProvider = context.watch<RecordProvider>();
    final recordChangeCounter =
        context.select<RecordProvider, int>((p) => p.changeCounter);
    final bookProvider = context.watch<BookProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final categorySignature = categoryProvider.categories.fold<int>(
      categoryProvider.categories.length,
      (acc, c) => acc ^ c.key.hashCode ^ c.name.hashCode,
    );

    // 检查加载状态
    if (!recordProvider.loaded || !bookProvider.loaded) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 0,
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bookId = bookProvider.activeBookId;
    final bookName = bookProvider.activeBook?.name ?? AppStrings.defaultBook;
    final now = DateTime.now();
    final isCurrentYear = now.year == _selectedYear;

	    final months = DateUtilsX.monthsInYear(_selectedYear);

	    _ensureYearAnalysisFuture(
	      recordProvider: recordProvider,
	      bookId: bookId,
	      months: months,
	      isCurrentYear: isCurrentYear,
	      now: now,
	      recordChangeCounter: recordChangeCounter,
	    );
    
    // 使用 FutureBuilder 异步加载年度统计数据（支持100万条记录）
    _ensureDeepAnalysisFuture(
      recordProvider: recordProvider,
      categoryProvider: categoryProvider,
      bookId: bookId,
      recordChangeCounter: recordChangeCounter,
      categorySignature: categorySignature,
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: _yearAnalysisFuture,
      initialData: _yearAnalysisCache,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          _yearAnalysisCache = snapshot.data;
        }

        final data = snapshot.data ?? _yearAnalysisCache ?? const {};
        final showLoadingOverlay =
            snapshot.connectionState == ConnectionState.waiting;

        if (snapshot.hasError && data.isEmpty) {
          return Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              elevation: 0,
              toolbarHeight: 0,
              backgroundColor: Colors.transparent,
            ),
            body: Center(child: Text('加载失败: ${snapshot.error}')),
          );
        }
        final monthSummaries = data['monthSummaries'] as List<_MonthSummary>? ?? [];
        final visibleMonths = monthSummaries
            .where((m) => m.hasRecords || m.isCurrentMonth)
            .toList();
        final weekSummaries = data['weekSummaries'] as List<_WeekSummary>? ?? [];
        final yearIncome = data['yearIncome'] as double? ?? 0.0;
        final yearExpense = data['yearExpense'] as double? ?? 0.0;
        final yearBalance = yearIncome - yearExpense;
        final hasYearRecords = data['hasYearRecords'] as bool? ?? false;
        final totalRecordCount = data['totalRecordCount'] as int? ?? 0;

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 0,
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                    _HeaderCard(
                      isDark: isDark,
                      cs: cs,
                      bookName: bookName,
                      year: _selectedYear,
                      income: yearIncome,
                      expense: yearExpense,
                      balance: yearBalance,
                      periodLabel: AppStrings.yearLabel(_selectedYear),
                      onTapPeriod: _pickYear,
                      onPrevPeriod: () => setState(() => _selectedYear -= 1),
                      onNextPeriod: () => setState(() => _selectedYear += 1),
                    ),
                    const SizedBox(height: 4),
                    if (hasYearRecords)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${AppStrings.reportSummaryPrefix}$totalRecordCount'
                            '${AppStrings.reportSummaryMiddleRecords}'
                            '${yearExpense.toStringAsFixed(0)}'
                            '${AppStrings.reportSummarySuffixYuan}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<PeriodType>(
                              segments: const [
                                ButtonSegment(
                                  value: PeriodType.week,
                                  label: Text(AppStrings.weekReport),
                                  icon: Icon(Icons.calendar_view_week),
                                ),
                                ButtonSegment(
                                  value: PeriodType.month,
                                  label: Text(AppStrings.monthReport),
                                  icon: Icon(Icons.calendar_view_month),
                                ),
                                ButtonSegment(
                                  value: PeriodType.year,
                                  label: Text(AppStrings.yearReport),
                                  icon: Icon(Icons.date_range),
                                ),
                              ],
                              selected: {_periodType},
                              onSelectionChanged: (value) {
                                setState(() => _periodType = value.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 可滚动内容区域：深度分析卡片 + 期间列表
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                           children: [
                             // 深度分析卡片
                            Builder(
                              builder: (context) {
                                final deepAnalysisKey = _deepAnalysisKey;
                                final deepInitialData = deepAnalysisKey == null
                                    ? null
                                    : _deepAnalysisCacheByKey[deepAnalysisKey];

                                return FutureBuilder<Map<String, dynamic>>(
                                  future: _deepAnalysisFuture,
                                  initialData: deepInitialData,
                                  builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasData) {
                                  if (deepAnalysisKey != null) {
                                    _deepAnalysisCacheByKey[deepAnalysisKey] =
                                        snapshot.data!;
                                  }
                                }

                                final data = snapshot.data ?? deepInitialData;
                                final showLoadingOverlay =
                                    snapshot.connectionState ==
                                        ConnectionState.waiting;

                                if (snapshot.hasError && data == null) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Card(
                                      elevation: 0,
                                      color: cs.surface,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          '加载失败: ${snapshot.error}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: cs.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (data == null) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: SizedBox(
                                      height: 220,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey<String>(
                                      'deep:${deepAnalysisKey ?? 'none'}',
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          children: [
                                            _buildTrendAnalysisCard(cs, data),
                                            const SizedBox(height: 12),
                                            _buildCategoryAnalysisCard(
                                              cs,
                                              data,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildInsightsCard(cs, data),
                                            const SizedBox(height: 12),
                                            _buildPredictionCard(cs, data),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                        if (showLoadingOverlay)
                                          const Positioned(
                                            left: 0,
                                            right: 0,
                                            top: 0,
                                            child: LinearProgressIndicator(
                                              minHeight: 2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // 期间列表
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _PeriodList(
                                year: _selectedYear,
                                cs: cs,
                                periodType: _periodType,
                                months: visibleMonths,
                                weeks: weekSummaries,
                                hasYearRecords: hasYearRecords,
                                 onTapMonth: (month) => _openBillPage(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                   month: month,
                                 ),
                                 onTapMonthReport: (month) => _openReportDetail(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                   month: month,
                                 ),
                                 onTapYear: () => _openBillPage(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                 ),
                                 onTapYearReport: () => _openReportDetail(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                 ),
                                 onTapWeek: (range) => _openBillPage(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                   weekRange: range,
                                 ),
                                 onTapWeekReport: (range) => _openReportDetail(
                                   context,
                                   bookId: bookId,
                                   year: _selectedYear,
                                   weekRange: range,
                                 ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
                if (showLoadingOverlay)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBillPage(
    BuildContext context, {
    required String bookId,
    required int year,
    int? month,
    DateTimeRange? weekRange,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillPage(
          initialYear: year,
          initialMonth:
              month != null ? DateTime(year, month, 1) : null,
          initialRange: weekRange,
          initialPeriodType: weekRange != null
              ? PeriodType.week
              : month != null
                  ? PeriodType.month
                  : PeriodType.year,
        ),
      ),
    );
  }

  void _openReportDetail(
    BuildContext context, {
    required String bookId,
    required int year,
    int? month,
    DateTimeRange? weekRange,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailPage(
          bookId: bookId,
          year: year,
          month: month,
          weekRange: weekRange,
          periodType: weekRange != null
              ? PeriodType.week
              : month != null
                  ? PeriodType.month
                  : PeriodType.year,
        ),
      ),
    );
  }

  Future<void> _pickYear() async {
    final now = DateTime.now().year;
    final years = List<int>.generate(100, (i) => now - 80 + i); // 80年前到20年后
    final itemHeight = 52.0;
    final initialIndex = years.indexOf(now).clamp(0, years.length - 1);
    final controller = ScrollController(
      initialScrollOffset: itemHeight * initialIndex,
    );
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemExtent: itemHeight,
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final y = years[index];
                    return ListTile(
                      title: Text(AppStrings.yearLabel(y)),
                      trailing: y == _selectedYear
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, y),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _selectedYear = selected);
    }
  }

  /// 异步加载年度分析数据（支持100万条记录）
  Future<Map<String, dynamic>> _loadYearAnalysisData(
    RecordProvider recordProvider,
    String bookId,
    List<DateTime> months,
    bool isCurrentYear,
    DateTime now,
  ) async {
    // 异步加载月份统计数据
    final monthSummaries = <_MonthSummary>[];
    for (final m in months) {
      final monthStats = await recordProvider.getMonthStatsAsync(m, bookId);
      final monthRecords = await recordProvider.recordsForMonthAsync(bookId, m.year, m.month);
      monthSummaries.add(
        _MonthSummary(
          month: m.month,
          income: monthStats.income,
          expense: monthStats.expense,
          recordCount: monthRecords.length,
          isCurrentMonth: isCurrentYear && m.month == now.month,
        ),
      );
    }

    // 异步加载年度记录用于周统计
    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    final yearRecords = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: yearStart,
      end: yearEnd,
    );

    final weekSummaries = _buildWeekSummariesFromRecords(yearRecords, _selectedYear);

    final yearIncome = monthSummaries.fold<double>(0, (sum, item) => sum + item.income);
    final yearExpense = monthSummaries.fold<double>(0, (sum, item) => sum + item.expense);
    final hasYearRecords = yearRecords.isNotEmpty;
    final totalRecordCount = yearRecords.length;

    return {
      'monthSummaries': monthSummaries,
      'weekSummaries': weekSummaries,
      'yearIncome': yearIncome,
      'yearExpense': yearExpense,
      'hasYearRecords': hasYearRecords,
      'totalRecordCount': totalRecordCount,
    };
  }

  /// 加载深度分析数据
  Future<Map<String, dynamic>> _loadDeepAnalysis(
    RecordProvider recordProvider,
    String bookId,
    int year,
    PeriodType periodType,
    CategoryProvider categoryProvider,
  ) async {
    final now = DateTime.now();
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);
    
    // 加载本年数据
    final yearRecords = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: yearStart,
      end: yearEnd,
    );
    
    // 加载去年数据用于对比
    final lastYearStart = DateTime(year - 1, 1, 1);
    final lastYearEnd = DateTime(year - 1, 12, 31, 23, 59, 59);
    final lastYearRecords = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: lastYearStart,
      end: lastYearEnd,
    );
    
    // 根据 periodType 生成趋势数据
    final trendData = <Map<String, dynamic>>[];
    final compareTrendData = <Map<String, dynamic>>[];

    DateTime anchor = now;
    if (year != now.year) {
      anchor = DateTime(year, 12, 31, 23, 59, 59);
    }

    if (periodType == PeriodType.year) {
      // 年模式：12个月月趋势 + 去年同比
      for (int month = 1; month <= 12; month++) {
        final monthDate = DateTime(year, month, 1);
        final monthStats =
            await recordProvider.getMonthStatsAsync(monthDate, bookId);
        final expense = math.max(0.0, monthStats.expense);
        trendData.add({
          'label': '$month月',
          'income': monthStats.income,
          'expense': expense,
          'balance': monthStats.income - monthStats.expense,
        });

        final lastYearMonthDate = DateTime(year - 1, month, 1);
        final lastStats =
            await recordProvider.getMonthStatsAsync(lastYearMonthDate, bookId);
        compareTrendData.add({
          'label': '$month月',
          'expense': math.max(0.0, lastStats.expense),
        });
      }
    } else if (periodType == PeriodType.month) {
      // 月账单：近6个月月趋势
      final sixMonthsAgo = DateTime(anchor.year, anchor.month - 5, 1);
      final recentRecords = await recordProvider.recordsForPeriodAsync(
        bookId,
        start: sixMonthsAgo,
        end: anchor,
      );

      for (int i = 5; i >= 0; i--) {
        final month = DateTime(anchor.year, anchor.month - i, 1);
        final monthEnd =
            DateTime(month.year, month.month + 1, 0, 23, 59, 59);
        final monthRecords = recentRecords.where((r) =>
            r.date.isAfter(month.subtract(const Duration(days: 1))) &&
            r.date.isBefore(monthEnd.add(const Duration(days: 1)))).toList();

        final income = monthRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final expense = monthRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        trendData.add({
          'label': '${month.month}月',
          'income': income,
          'expense': math.max(0.0, expense),
          'balance': income - expense,
        });
      }
    } else {
      // 周报：近8周周趋势（按周汇总）
      final start = anchor.subtract(const Duration(days: 7 * 7));
      final recentRecords = await recordProvider.recordsForPeriodAsync(
        bookId,
        start: start,
        end: anchor,
      );

      DateTime weekStart = DateUtilsX.startOfWeek(anchor);
      for (int i = 7; i >= 0; i--) {
        final ws = weekStart.subtract(Duration(days: 7 * i));
        final we = ws.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        final weekRecords = recentRecords.where((r) =>
            !r.date.isBefore(ws) && !r.date.isAfter(we)).toList();
        final expense = weekRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final income = weekRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final label = '${ws.month}/${ws.day}';
        trendData.add({
          'label': label,
          'income': income,
          'expense': math.max(0.0, expense),
          'balance': income - expense,
        });
      }
    }
    
    // 将分类key转换为中文名称
    final categoryNameMap = <String, String>{};
    for (final category in categoryProvider.categories) {
      categoryNameMap[category.key] = category.name;
    }
    
    // 计算分类数据（按展示名称聚合，避免出现“未分类”或未知key）
    final categoryMap = <String, double>{};
    for (final record in yearRecords.where((r) => r.isExpense)) {
      final rawKey = record.categoryKey;
      // 排除不计入统计的记录（如转账、标记不统计的记录）
      if (!record.includeInStats) continue;
      if (rawKey.startsWith('transfer')) continue;
      // 将key映射为展示名，找不到则使用英文映射，再找不到用“其他”
      String displayName =
          categoryNameMap[rawKey] ?? CategoryNameHelper.mapEnglishKeyToChinese(rawKey);
      if (displayName == CategoryNameHelper.unknownCategoryName) {
        displayName = '其他';
        // 调试日志：定位被归入“其他”的记录
        if (kDebugMode) {
          debugPrint('[Analysis] 分类未匹配，归入其他: key=$rawKey, amount=${record.amount}, date=${record.date.toIso8601String()}');
        }
      }
      categoryMap[displayName] = (categoryMap[displayName] ?? 0) + record.amount;
    }
    final categoryList = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // 计算同比数据
    final thisYearExpense = yearRecords.where((r) => r.isExpense).fold<double>(0, (sum, r) => sum + r.amount);
    final lastYearExpense = lastYearRecords.where((r) => r.isExpense).fold<double>(0, (sum, r) => sum + r.amount);
    final yearOverYearChange = lastYearExpense > 0 
        ? ((thisYearExpense - lastYearExpense) / lastYearExpense * 100)
        : 0.0;
    
    // 计算月度平均
    final avgMonthlyExpense = yearRecords.isNotEmpty 
        ? thisYearExpense / 12 
        : 0.0;
    
    // 预测本月总支出（基于当前月份和平均）
    final currentMonth = DateTime.now();
    final currentMonthStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final currentMonthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);
    final currentMonthRecords = yearRecords.where((r) => 
      r.date.isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
      r.date.isBefore(currentMonthEnd.add(const Duration(days: 1))) &&
      r.isExpense
    ).toList();
    final currentMonthExpense = currentMonthRecords.fold<double>(0, (sum, r) => sum + r.amount);
    final daysPassed = currentMonth.day;
    final totalDays = currentMonthEnd.day;
    final predictedMonthExpense = daysPassed > 0 
        ? (currentMonthExpense / daysPassed * totalDays)
        : avgMonthlyExpense;
    
    // 生成洞察
    final insights = <String>[];
    if (yearOverYearChange > 10) {
      insights.add('本年支出比去年增加${yearOverYearChange.toStringAsFixed(1)}%，建议控制支出');
    } else if (yearOverYearChange < -10) {
      insights.add('本年支出比去年减少${yearOverYearChange.abs().toStringAsFixed(1)}%，继续保持');
    }
    
    if (categoryList.isNotEmpty) {
      final topCategory = categoryList.first;
      insights.add('${topCategory.key}是您的主要支出类别，占比${(topCategory.value / thisYearExpense * 100).toStringAsFixed(1)}%');
    }
    
    if (currentMonthExpense > avgMonthlyExpense * 1.2) {
      insights.add('本月支出已超过月均支出20%，建议控制');
    }
    
    return {
      'trendData': trendData,
      'compareTrendData': compareTrendData,
      'categoryData': categoryList.take(10).map((e) {
        return {
          'category': e.key,
          'amount': e.value,
          'percent': thisYearExpense > 0 ? (e.value / thisYearExpense * 100) : 0.0,
        };
      }).toList(),
      'yearOverYearChange': yearOverYearChange,
      'avgMonthlyExpense': avgMonthlyExpense,
      'predictedMonthExpense': predictedMonthExpense,
      'insights': insights,
      'thisYearExpense': thisYearExpense,
      'lastYearExpense': lastYearExpense,
    };
  }

  /// 构建趋势分析卡片
  Widget _buildTrendAnalysisCard(ColorScheme cs, Map<String, dynamic> data) {
    final trendData = data['trendData'] as List<Map<String, dynamic>>? ?? [];
    if (trendData.isEmpty) return const SizedBox.shrink();
    final compareTrendData =
        data['compareTrendData'] as List<Map<String, dynamic>>? ?? [];
     
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '支出趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildTrendChart(trendData, compareTrendData, cs),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分类分析卡片
  Widget _buildCategoryAnalysisCard(ColorScheme cs, Map<String, dynamic> data) {
    final categoryData = data['categoryData'] as List<Map<String, dynamic>>? ?? [];
    if (categoryData.isEmpty) return const SizedBox.shrink();
    
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '分类占比',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...categoryData.take(5).map((item) {
              final percent = item['percent'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['category'] as String,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '¥${(item['amount'] as double).toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: percent / 100,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// 构建消费洞察卡片
  Widget _buildInsightsCard(ColorScheme cs, Map<String, dynamic> data) {
    final insights = data['insights'] as List<String>? ?? [];
    final yearOverYearChange = data['yearOverYearChange'] as double? ?? 0.0;
    
    if (insights.isEmpty && yearOverYearChange == 0) return const SizedBox.shrink();
    
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '消费洞察',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (yearOverYearChange != 0)
              _buildInsightItem(
                cs,
                yearOverYearChange > 0 
                    ? '本年支出比去年${yearOverYearChange.toStringAsFixed(1)}%'
                    : '本年支出比去年减少${yearOverYearChange.abs().toStringAsFixed(1)}%',
                yearOverYearChange > 0 ? Icons.trending_up : Icons.trending_down,
                yearOverYearChange > 0
                    ? (Theme.of(context).extension<BrandTheme>()?.danger ?? cs.error)
                    : (Theme.of(context).extension<BrandTheme>()?.success ?? cs.tertiary),
              ),
            ...insights.map((insight) => _buildInsightItem(
              cs,
              insight,
              Icons.info_outline,
              cs.primary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(ColorScheme cs, String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建预测分析卡片
  Widget _buildPredictionCard(ColorScheme cs, Map<String, dynamic> data) {
    final predictedMonthExpense = data['predictedMonthExpense'] as double? ?? 0.0;
    final avgMonthlyExpense = data['avgMonthlyExpense'] as double? ?? 0.0;
    
    if (predictedMonthExpense == 0 && avgMonthlyExpense == 0) return const SizedBox.shrink();
    
    final diff = predictedMonthExpense - avgMonthlyExpense;
    final diffPercent = avgMonthlyExpense > 0 ? (diff / avgMonthlyExpense * 100) : 0.0;
    
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '预测分析',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '预测本月支出',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${predictedMonthExpense.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '月均支出',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${avgMonthlyExpense.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (diffPercent.abs() > 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: diffPercent > 0 
                        ? (Theme.of(context).extension<BrandTheme>()?.danger ?? cs.error).withOpacity(0.1)
                        : (Theme.of(context).extension<BrandTheme>()?.success ?? cs.tertiary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        diffPercent > 0 ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                        size: 16,
                        color: diffPercent > 0
                            ? (Theme.of(context).extension<BrandTheme>()?.danger ?? cs.error)
                            : (Theme.of(context).extension<BrandTheme>()?.success ?? cs.tertiary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          diffPercent > 0
                              ? '预测本月支出将比月均高出${diffPercent.toStringAsFixed(1)}%，建议控制支出'
                              : '预测本月支出将比月均低${diffPercent.abs().toStringAsFixed(1)}%，继续保持',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
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

  List<_WeekSummary> _buildWeekSummariesFromRecords(
    List<Record> records,
    int year,
  ) {
    final Map<DateTime, _WeekSummary> map = {};
    for (final record in records) {
      final start = DateUtilsX.startOfWeek(record.date);
      final range = DateUtilsX.weekRange(record.date);
      final summary = map.putIfAbsent(
        start,
        () => _WeekSummary(
          start: start,
          end: range.end,
          income: 0,
          expense: 0,
          recordCount: 0,
        ),
      );
      if (record.isIncome) {
        summary.income += record.incomeValue;
      } else {
        summary.expense += record.expenseValue;
      }
      summary.recordCount += 1;
    }

    final now = DateTime.now();
    final currentStart = DateUtilsX.startOfWeek(now);
    if (now.year == year && !map.containsKey(currentStart)) {
      final range = DateUtilsX.weekRange(now);
      map[currentStart] = _WeekSummary(
        start: currentStart,
        end: range.end,
        income: 0,
        expense: 0,
        recordCount: 0,
      );
    }

    final entries = map.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < entries.length; i++) {
      entries[i].weekIndex = i + 1;
    }

    entries.sort((a, b) => b.start.compareTo(a.start));
    return entries;
  }

  List<_WeekSummary> _buildWeekSummaries(
    RecordProvider recordProvider,
    String bookId,
    int year,
  ) {
    final records = recordProvider
        .recordsForBook(bookId)
        .where((r) => r.date.year == year)
        .toList();

    final Map<DateTime, _WeekSummary> map = {};
    for (final record in records) {
      final start = DateUtilsX.startOfWeek(record.date);
      final range = DateUtilsX.weekRange(record.date);
      final summary = map.putIfAbsent(
        start,
        () => _WeekSummary(
          start: start,
          end: range.end,
          income: 0,
          expense: 0,
          recordCount: 0,
        ),
      );
      if (record.isIncome) {
        summary.income += record.incomeValue;
      } else {
        summary.expense += record.expenseValue;
      }
      summary.recordCount += 1;
    }

    final now = DateTime.now();
    final currentStart = DateUtilsX.startOfWeek(now);
    if (now.year == year && !map.containsKey(currentStart)) {
      final range = DateUtilsX.weekRange(now);
      map[currentStart] = _WeekSummary(
        start: currentStart,
        end: range.end,
        income: 0,
        expense: 0,
        recordCount: 0,
      );
    }

    final entries = map.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < entries.length; i++) {
      entries[i].weekIndex = i + 1;
    }

    entries.sort((a, b) => b.start.compareTo(a.start));
    return entries;
  }

  /*
  /// 构建趋势图表
  Widget _buildTrendChart(List<Map<String, dynamic>> data, ColorScheme cs) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    final maxExpense = data.map((e) => e['expense'] as double).reduce((a, b) => a > b ? a : b);
    final minExpense = data.map((e) => e['expense'] as double).reduce((a, b) => a < b ? a : b);
    final range = maxExpense - minExpense;
    final interval = range > 0 ? (range / 5).ceilToDouble() : maxExpense / 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: cs.outline.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1.0, // 设置间隔为1，避免重复
              getTitlesWidget: (value, meta) {
                // 使用严格的整数检查，避免浮点数精度问题
                final roundedValue = value.round();
                final diff = (value - roundedValue).abs();
                
                // 只有当 value 非常接近整数时才显示（容差0.01）
                if (diff > 0.01) {
                  return const SizedBox.shrink();
                }
                
                final index = roundedValue;
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                
                // 确保每个索引只显示一次：检查 value 是否真的等于 index
                if ((value - index).abs() > 0.1) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[index]['month'] as String,
                    style: TextStyle (
                      fontSize: 10,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '¥${value.toInt()}',
                  style: TextStyle (
                    fontSize: 10,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: cs.outline.withOpacity(0.2)),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxExpense * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value['expense'] as double);
            }).toList(),
            isCurved: true,
            color: cs.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
  */

  /// 构建趋势图表
  Widget _buildTrendChart(
    List<Map<String, dynamic>> data,
    List<Map<String, dynamic>> compareData,
    ColorScheme cs,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    final entries = data
        .map(
          (e) => ChartEntry(
            label: (e['label'] as String?) ?? '',
            value: (e['expense'] as num?)?.toDouble() ?? 0.0,
            color: cs.primary,
          ),
        )
        .toList();

    final compareEntries = compareData
        .map(
          (e) => ChartEntry(
            label: (e['label'] as String?) ?? '',
            value: (e['expense'] as num?)?.toDouble() ?? 0.0,
            color: cs.outline,
          ),
        )
        .toList();

    Set<int> findAnomalyIndices(List<ChartEntry> list) {
      if (list.length < 3) return const <int>{};
      final values = list.map((e) => math.max(0.0, e.value)).toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance =
          values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
              values.length;
      final std = math.sqrt(variance);
      final anomalies = <int>{};
      for (var i = 0; i < values.length; i++) {
        if (values[i] > 0 && values[i] >= mean + 3 * std) {
          anomalies.add(i);
        }
      }
      final sorted = values.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.length >= 2 && sorted.first.value > sorted[1].value * 2) {
        anomalies.add(sorted.first.key);
      }
      return anomalies;
    }

    final values = entries.map((e) => math.max(0.0, e.value)).toList();
    final avgY =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final anomalyIndices = findAnomalyIndices(entries);

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ChartLine(
        entries: entries,
        compareEntries: compareEntries.isEmpty ? null : compareEntries,
        avgY: avgY > 0 ? avgY : null,
        highlightIndices: anomalyIndices.isEmpty ? null : anomalyIndices,
        bottomLabelBuilder: (index, entry) => entry.label,
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isDark,
    required this.cs,
    required this.bookName,
    required this.year,
    required this.income,
    required this.expense,
    required this.balance,
    required this.periodLabel,
    required this.onTapPeriod,
    required this.onPrevPeriod,
    required this.onNextPeriod,
  });

  final bool isDark;
  final ColorScheme cs;
  final String bookName;
  final int year;
  final double income;
  final double expense;
  final double balance;
  final String periodLabel;
  final VoidCallback onTapPeriod;
  final VoidCallback onPrevPeriod;
  final VoidCallback onNextPeriod;

  @override
    Widget build(BuildContext context) {
      final brand = Theme.of(context).extension<BrandTheme>();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isDark ? null : brand?.headerGradient,
          color: isDark ? cs.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? null : brand?.headerShadow,
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PeriodSelector(
                    label: periodLabel,
                    periodType: PeriodType.year,
                    onTap: onTapPeriod,
                    onPrev: onPrevPeriod,
                    onNext: onNextPeriod,
                    compact: true,
                  ),
                  const BookSelectorButton(compact: true),
                ],
              ),
              const SizedBox(height: 8),
              // 收入 / 支出 / 结余
              Row(
                children: [
                  _SummaryItem(
                    label: AppStrings.income,
                    value: income,
                    color: isDark ? cs.onSurface : cs.onPrimary,
                  ),
                  _SummaryItem(
                    label: AppStrings.expense,
                    value: expense,
                    color: isDark ? cs.onSurface : cs.onPrimary,
                  ),
                  _SummaryItem(
                    label: AppStrings.balance,
                    value: balance,
                    color: isDark ? cs.onSurface : cs.onPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
          ],
        ),
      ),
    );
  }

}

  class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
    final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodList extends StatelessWidget {
  const _PeriodList({
    required this.year,
    required this.cs,
    required this.periodType,
    required this.months,
    required this.weeks,
    required this.hasYearRecords,
    required this.onTapMonth,
    required this.onTapYear,
    required this.onTapWeek,
    this.onTapMonthReport,
    this.onTapYearReport,
    this.onTapWeekReport,
  });

  final int year;
  final ColorScheme cs;
  final PeriodType periodType;
  final List<_MonthSummary> months;
  final List<_WeekSummary> weeks;
  final bool hasYearRecords;
  final ValueChanged<int> onTapMonth;
  final VoidCallback onTapYear;
  final ValueChanged<DateTimeRange> onTapWeek;
  final ValueChanged<int>? onTapMonthReport;
  final VoidCallback? onTapYearReport;
  final ValueChanged<DateTimeRange>? onTapWeekReport;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '月份 / 周次',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.75),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.income,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.expense,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.balance,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );

    final children = <Widget>[header];

    if (!hasYearRecords && periodType != PeriodType.year) {
      children.add(_EmptyYearCard(cs: cs));
    }

    switch (periodType) {
      case PeriodType.year:
        if (!hasYearRecords) {
          children.add(_EmptyYearCard(cs: cs));
        } else {
          final income = months.fold<double>(0, (sum, m) => sum + m.income);
          final expense = months.fold<double>(0, (sum, m) => sum + m.expense);
          children.add(
            _PeriodTile(
              title: AppStrings.periodBillTitle(year),
              subtitle: '${AppStrings.yearLabel(year)} • ${AppStrings.yearReport}',
              income: income,
              expense: expense,
              balance: income - expense,
              cs: cs,
              hasData: true,
               highlight: true,
               tag: AppStrings.yearReport,
               onTap: onTapYear,
               onTapReport: onTapYearReport,
             ),
          );
        }
        break;
      case PeriodType.month:
        if (months.isEmpty) {
          if (hasYearRecords) {
            children.add(_EmptyYearCard(cs: cs));
          }
        } else {
          for (final m in months) {
            children.add(
              _PeriodTile(
                title: AppStrings.monthLabel(m.month),
                subtitle: AppStrings.yearMonthLabel(year, m.month),
                income: m.income,
                expense: m.expense,
                balance: m.balance,
                cs: cs,
                hasData: m.hasRecords,
                tag: m.isCurrentMonth ? '本月' : null,
                emptyHint: m.isCurrentMonth
                    ? AppStrings.currentMonthEmpty
                    : '无记录',
                  highlight: m.isCurrentMonth || m.hasRecords,
                  onTap: () => onTapMonth(m.month),
                  onTapReport: onTapMonthReport != null
                      ? () => onTapMonthReport!(m.month)
                      : null,
                ),
            );
          }
        }
        break;
      case PeriodType.week:
        if (weeks.isEmpty) {
          if (hasYearRecords) {
            children.add(_EmptyYearCard(cs: cs));
          }
        } else {
          for (final w in weeks) {
            final range = DateTimeRange(start: w.start, end: w.end);
            children.add(
              _PeriodTile(
                title: DateUtilsX.weekLabel(w.weekIndex),
                subtitle: AppStrings.weekRangeLabel(range),
                income: w.income,
                expense: w.expense,
                balance: w.balance,
                cs: cs,
                hasData: w.hasRecords,
                emptyHint: '无记录',
                tag: w.isCurrentWeek ? '本周' : null,
                highlight: w.isCurrentWeek || w.hasRecords,
                onTap: () => onTapWeek(range),
                onTapReport: onTapWeekReport != null
                    ? () => onTapWeekReport!(range)
                    : null,
              ),
            );
          }
        }
        break;
    }

    return Column(children: children);
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.title,
    this.subtitle,
    required this.income,
    required this.expense,
    required this.balance,
    required this.cs,
    required this.onTap,
    this.onTapReport,
    this.highlight = false,
    this.hasData = true,
    this.emptyHint,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final double income;
  final double expense;
  final double balance;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback? onTapReport;
  final bool highlight;
  final bool hasData;
  final String? emptyHint;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final accentColor = highlight ? cs.primary : cs.outlineVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.outlineVariant.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 60,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
	                      Text(
	                        title,
	                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
	                          fontSize: 15,
	                          fontWeight: FontWeight.w700,
	                          color: cs.primary,
	                        ),
	                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
	                          child: Text(
	                            tag!,
	                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
	                              fontSize: 10,
	                              fontWeight: FontWeight.w600,
	                              color: cs.primary,
	                            ),
	                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
	                    Text(
	                      subtitle!,
	                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
	                        fontSize: 12,
	                        color: cs.outline,
	                      ),
	                    ),
                  ],
                  const SizedBox(height: 8),
                  hasData
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _AmountLabel(
                              label: AppStrings.income,
                              value: income,
                              color: cs.onSurface,
                            ),
                            _AmountLabel(
                              label: AppStrings.expense,
                              value: expense,
                              color: cs.onSurface,
                            ),
                            _AmountLabel(
                              label: AppStrings.balance,
                              value: balance,
                              color: cs.onSurface,
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            emptyHint ?? '无记录',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            if (onTapReport != null)
              IconButton(
                tooltip: '查看报告',
                icon: const Icon(Icons.assessment_outlined, size: 18),
                onPressed: onTapReport,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MonthSummary {
  _MonthSummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.recordCount,
    required this.isCurrentMonth,
  });

  final int month;
  final double income;
  final double expense;
  final int recordCount;
  final bool isCurrentMonth;

  bool get hasRecords => recordCount > 0;
  double get balance => income - expense;
}

class _WeekSummary {
  _WeekSummary({
    required this.start,
    required this.end,
    required this.income,
    required this.expense,
    required this.recordCount,
    this.weekIndex = 1,
  });

  final DateTime start;
  final DateTime end;
  double income;
  double expense;
  int recordCount;
  int weekIndex;

  bool get hasRecords => recordCount > 0;
  bool get isCurrentWeek {
    final now = DateTime.now();
    final currentRange = DateUtilsX.weekRange(now);
    return DateUtilsX.isSameDay(currentRange.start, start);
  }

  double get balance => income - expense;
}

class _EmptyYearCard extends StatelessWidget {
  const _EmptyYearCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.emptyYearRecords,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddRecordPage(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.goRecord),
          ),
        ],
      ),
    );
  }
}
