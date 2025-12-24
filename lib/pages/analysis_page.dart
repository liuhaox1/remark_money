import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  _FlowMetric _flowMetric = _FlowMetric.expense;
  final GlobalKey _flowSelectorKey = GlobalKey();
  late DateTime _selectedWeekStart;
  late final ScrollController _weekIndexController;

  static const double _kWeekItemWidth = 52;
  static const double _kWeekItemSpacing = 8;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = DateUtilsX.startOfWeek(DateTime(now.year, now.month, now.day));
    _weekIndexController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedWeek(jump: true);
    });
  }

  @override
  void dispose() {
    _weekIndexController.dispose();
    super.dispose();
  }

  bool _isCountedRecord(Record record) {
    if (!record.includeInStats) return false;
    if (record.categoryKey.startsWith('transfer')) return false;
    return true;
  }

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
    final weekKey = _periodType == PeriodType.week
        ? ':${DateUtilsX.ymd(_selectedWeekStart)}'
        : '';
    final key =
        '$bookId:${_selectedYear}:${_periodType.name}:${_flowMetric.name}$weekKey:$recordChangeCounter:$categorySignature';
    if (_deepAnalysisKey == key && _deepAnalysisFuture != null) return;
    _deepAnalysisKey = key;
    _deepAnalysisFuture = _loadDeepAnalysis(
      recordProvider,
      bookId,
      _selectedYear,
      _periodType,
      _flowMetric,
      categoryProvider,
      weekStart: _selectedWeekStart,
    );
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

  void _ensureSelectedWeekInYear() {
    final now = DateTime.now();
    final maxIndex = _selectedYear == now.year
        ? _weekIndexForYear(DateUtilsX.startOfWeek(DateTime(now.year, now.month, now.day)), _selectedYear)
        : _maxWeekIndexForYear(_selectedYear);
    var idx = _weekIndexForYear(_selectedWeekStart, _selectedYear);
    if (idx < 1) idx = 1;
    if (idx > maxIndex) idx = maxIndex;
    final nextStart = _weekStartForIndex(idx, _selectedYear);
    _selectedWeekStart = DateTime(nextStart.year, nextStart.month, nextStart.day);
  }

  void _scrollToSelectedWeek({bool jump = false}) {
    if (!_weekIndexController.hasClients) return;
    final idx = _weekIndexForYear(_selectedWeekStart, _selectedYear);
    final rawOffset = (idx - 1) * (_kWeekItemWidth + _kWeekItemSpacing) - _kWeekItemWidth * 1.5;
    final position = _weekIndexController.position;
    final offset = rawOffset.clamp(0.0, position.maxScrollExtent);
    if (jump) {
      _weekIndexController.jumpTo(offset);
    } else {
      _weekIndexController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildWeekIndexStrip(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final maxIndex = _selectedYear == now.year
        ? _weekIndexForYear(DateUtilsX.startOfWeek(DateTime(now.year, now.month, now.day)), _selectedYear)
        : _maxWeekIndexForYear(_selectedYear);
    final selectedIndex = _weekIndexForYear(_selectedWeekStart, _selectedYear);

    return SizedBox(
      height: 46,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.separated(
          controller: _weekIndexController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: maxIndex,
          separatorBuilder: (_, __) => const SizedBox(width: _kWeekItemSpacing),
          itemBuilder: (context, i) {
            final index = i + 1;
            final isSelected = index == selectedIndex;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                final weekStart = _weekStartForIndex(index, _selectedYear);
                setState(() {
                  _selectedWeekStart = DateTime(
                    weekStart.year,
                    weekStart.month,
                    weekStart.day,
                  );
                });
                _scrollToSelectedWeek();
              },
              child: SizedBox(
                width: _kWeekItemWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      '${index}周',
                      style: tt.bodyMedium?.copyWith(
                        color: isSelected
                            ? cs.onSurface
                            : cs.onSurface.withOpacity(0.45),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 2,
                      width: 26,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.onSurface.withOpacity(0.85)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openFlowSelector() async {
    final ctx = _flowSelectorKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    final selected = await showDialog<_FlowMetric>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        final tt = Theme.of(dialogContext).textTheme;
        Widget item({
          required _FlowMetric value,
          required IconData icon,
          required String title,
        }) {
          final isSelected = value == _flowMetric;
          return InkWell(
            onTap: () => Navigator.of(dialogContext).pop(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.75)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: cs.primary, size: 20),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  top: offset.dy + size.height + 8,
                  child: Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        item(
                          value: _FlowMetric.expense,
                          icon: Icons.south_rounded,
                          title: '支出',
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.35)),
                        item(
                          value: _FlowMetric.income,
                          icon: Icons.north_rounded,
                          title: '收入',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == _flowMetric) return;
    setState(() {
      _flowMetric = selected;
      // 强制刷新深度分析
      _deepAnalysisKey = null;
      _deepAnalysisFuture = null;
    });
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
            top: false,
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
                      onPrevPeriod: () => setState(() {
                        _selectedYear -= 1;
                        _ensureSelectedWeekInYear();
                        _scrollToSelectedWeek();
                      }),
                      onNextPeriod: () => setState(() {
                        _selectedYear += 1;
                        _ensureSelectedWeekInYear();
                        _scrollToSelectedWeek();
                      }),
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
                            Center(
                              child: InkWell(
                                key: _flowSelectorKey,
                                borderRadius: BorderRadius.circular(999),
                                onTap: _openFlowSelector,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _flowMetric == _FlowMetric.expense
                                            ? '支出'
                                            : '收入',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 20,
                                        color: cs.onSurface.withOpacity(0.7),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SegmentedButton<PeriodType>(
                              segments: const [
                                ButtonSegment(
                                  value: PeriodType.week,
                                  label: Text(AppStrings.weeklyBill),
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
                                setState(() {
                                  _periodType = value.first;
                                  if (_periodType == PeriodType.week) {
                                    // 切到周时，默认定位到该年的“当前周”（当年）或“最后一周”（非当年）
                                    final now = DateTime.now();
                                    final base = _selectedYear == now.year
                                        ? DateTime(now.year, now.month, now.day)
                                        : DateTime(_selectedYear, 12, 31);
                                    final start = DateUtilsX.startOfWeek(base);
                                    _selectedWeekStart =
                                        DateTime(start.year, start.month, start.day);
                                    _ensureSelectedWeekInYear();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _scrollToSelectedWeek();
                                    });
                                  }
                                });
                              },
                            ),
                            if (_periodType == PeriodType.week)
                              SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: _buildWeekIndexStrip(cs),
                                ),
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
      setState(() {
        _selectedYear = selected;
        _ensureSelectedWeekInYear();
        _scrollToSelectedWeek();
      });
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
      final monthRecordCount =
          monthRecords.where(_isCountedRecord).length;
      monthSummaries.add(
        _MonthSummary(
          month: m.month,
          income: monthStats.income,
          expense: monthStats.expense,
          recordCount: monthRecordCount,
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
    final countedYearRecords = yearRecords.where(_isCountedRecord).toList();
    final weekSummaries =
        _buildWeekSummariesFromRecords(countedYearRecords, _selectedYear);

    final yearIncome = monthSummaries.fold<double>(0, (sum, item) => sum + item.income);
    final yearExpense = monthSummaries.fold<double>(0, (sum, item) => sum + item.expense);
    final hasYearRecords = countedYearRecords.isNotEmpty;
    final totalRecordCount = countedYearRecords.length;

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
    _FlowMetric flowMetric,
    CategoryProvider categoryProvider,
    {DateTime? weekStart}
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
    final filteredYearRecords = yearRecords.where(_isCountedRecord).toList();
    
    // 加载去年数据用于对比
    final lastYearStart = DateTime(year - 1, 1, 1);
    final lastYearEnd = DateTime(year - 1, 12, 31, 23, 59, 59);
    final lastYearRecords = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: lastYearStart,
      end: lastYearEnd,
    );
    final filteredLastYearRecords =
        lastYearRecords.where(_isCountedRecord).toList();

    final flowIsExpense = flowMetric == _FlowMetric.expense;

    DateTimeRange periodRange;
    if (periodType == PeriodType.year) {
      periodRange = DateTimeRange(start: yearStart, end: yearEnd);
    } else if (periodType == PeriodType.month) {
      final month = year == now.year ? now.month : 12;
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);
      periodRange = DateTimeRange(start: start, end: end);
    } else {
      final base = weekStart != null
          ? DateTime(weekStart.year, weekStart.month, weekStart.day)
          : (year == now.year ? DateTime(now.year, now.month, now.day) : DateTime(year, 12, 31));
      final range = DateUtilsX.weekRange(base);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      periodRange = DateTimeRange(start: start, end: end);
    }

    final periodRecords = yearRecords
        .where((r) => !r.date.isBefore(periodRange.start) && !r.date.isAfter(periodRange.end))
        .toList();
    final lastPeriodRecords = lastYearRecords
        .where((r) => !r.date.isBefore(DateTime(
              periodRange.start.year - 1,
              periodRange.start.month,
              periodRange.start.day,
            )) &&
            !r.date.isAfter(DateTime(
              periodRange.end.year - 1,
              periodRange.end.month,
              periodRange.end.day,
              23,
              59,
              59,
            )))
        .toList();

    final filteredPeriodRecords = periodRecords.where(_isCountedRecord).toList();
    final filteredLastPeriodRecords =
        lastPeriodRecords.where(_isCountedRecord).toList();

    // 根据 periodType 生成趋势数据
    final trendData = <Map<String, dynamic>>[];
    final compareTrendData = <Map<String, dynamic>>[];

    if (periodType == PeriodType.year) {
      // 年模式：12个月月趋势 + 去年同比
      for (int month = 1; month <= 12; month++) {
        final monthDate = DateTime(year, month, 1);
        final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
        final monthRecords = filteredYearRecords
            .where((r) =>
                !r.date.isBefore(monthDate) && !r.date.isAfter(monthEnd))
            .toList();
        final income = monthRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final expense = monthRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        trendData.add({
          'label': '$month月',
          'income': income,
          'expense': math.max(0.0, expense),
          'balance': income - expense,
        });

        final lastYearMonthDate = DateTime(year - 1, month, 1);
        final lastYearMonthEnd =
            DateTime(year - 1, month + 1, 0, 23, 59, 59);
        final lastMonthValue = filteredLastYearRecords
            .where((r) =>
                !r.date.isBefore(lastYearMonthDate) &&
                !r.date.isAfter(lastYearMonthEnd))
            .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        compareTrendData.add({
          'label': '$month月',
          'value': math.max(0.0, lastMonthValue),
        });
      }
    } else if (periodType == PeriodType.month) {
      // 月账单：当月每日趋势
      final start = DateTime(periodRange.start.year, periodRange.start.month, 1);
      final lastDay = DateTime(start.year, start.month + 1, 0).day;
      for (int day = 1; day <= lastDay; day++) {
        final dayDate = DateTime(start.year, start.month, day);
        final dayRecords = filteredPeriodRecords
            .where((r) => DateUtilsX.isSameDay(r.date, dayDate))
            .toList();
        final income = dayRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final expense = dayRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        trendData.add({
          'label': day.toString().padLeft(2, '0'),
          'income': income,
          'expense': math.max(0.0, expense),
          'balance': income - expense,
        });
      }
    } else {
      // 周账单：本周每日趋势（7天）
      final start = DateTime(
        periodRange.start.year,
        periodRange.start.month,
        periodRange.start.day,
      );
      for (int i = 0; i < 7; i++) {
        final dayDate = start.add(Duration(days: i));
        final dayRecords = filteredPeriodRecords
            .where((r) => DateUtilsX.isSameDay(r.date, dayDate))
            .toList();
        final expense = dayRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final income = dayRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final mm = dayDate.month.toString().padLeft(2, '0');
        final dd = dayDate.day.toString().padLeft(2, '0');
        trendData.add({
          'label': '$mm-$dd',
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
    for (final record
        in filteredPeriodRecords.where((r) => flowIsExpense ? r.isExpense : r.isIncome)) {
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
    
    // 当前周期总额（用于占比/排行榜等）
    final periodTotal = filteredPeriodRecords
        .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.amount);
    final lastPeriodTotal = filteredLastPeriodRecords
        .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.amount);

    // 年度同比：仍以“本年 vs 去年”计算（更符合“洞察”语义）
    final thisYearTotal = filteredYearRecords
        .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.amount);
    final lastYearTotal = filteredLastYearRecords
        .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
        .fold<double>(0, (sum, r) => sum + r.amount);
    final yearOverYearChange = lastYearTotal > 0
        ? ((thisYearTotal - lastYearTotal) / lastYearTotal * 100)
        : 0.0;
    
    // 计算月度平均：只按「有记录的月份」计算，避免新用户/数据稀疏时被 12 个月平均拉得过低
    final expenseByMonth = <int, double>{};
    for (final r in filteredYearRecords
        .where((r) => flowIsExpense ? r.isExpense : r.isIncome)) {
      expenseByMonth[r.date.month] = (expenseByMonth[r.date.month] ?? 0) + r.amount;
    }
    final monthsWithExpense = expenseByMonth.length;
    final avgMonthlyExpense =
        monthsWithExpense > 0 ? (thisYearTotal / monthsWithExpense) : 0.0;
    
    // 预测本月总支出（仅在查看「当前年份」时展示）
    final nowDate = DateTime.now();
    final predictionAvailable = year == nowDate.year;
    final currentMonth = nowDate;
    final currentMonthStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final currentMonthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);
    final currentMonthRecords = yearRecords.where((r) => 
      r.date.isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
      r.date.isBefore(currentMonthEnd.add(const Duration(days: 1))) &&
      (flowIsExpense ? r.isExpense : r.isIncome)
    ).toList();
    final filteredCurrentMonthRecords =
        currentMonthRecords.where(_isCountedRecord).toList();
    final currentMonthExpense = predictionAvailable
        ? filteredCurrentMonthRecords.fold<double>(0, (sum, r) => sum + r.amount)
        : 0.0;
    final daysPassed = currentMonth.day;
    final totalDays = currentMonthEnd.day;
    final predictedMonthExpense = predictionAvailable && daysPassed > 0
        ? (currentMonthExpense / daysPassed * totalDays)
        : 0.0;

    // 更稳健的预测：基于近几个月的日均（中位数） + 当前月偏离程度修正，降低“单笔大额/月初月末”误差。
    // 数据不足（天数过少/历史过少）时自动降级到线性外推或直接不展示。
    const minPredictionDays = 5;
    final currentExpenseDays = filteredCurrentMonthRecords
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet()
        .length;

    double robustPredicted = predictedMonthExpense;
    double robustPredictedLow = 0.0;
    double robustPredictedHigh = 0.0;
    int robustHistoryMonths = 0;
    String predictionMethod = '按天线性外推';
    bool predictionLowConfidence = false;

    final canTryRobust = predictionAvailable && daysPassed >= minPredictionDays;
    if (canTryRobust) {
      final history = <double>[];
      // 取最近 6 个「已结束」月份（跨年则取去年），用月总支出/当月天数得到日均。
      // 只统计计入统计的支出记录。
      final allForHistory = <Record>[...yearRecords, ...lastYearRecords]
          .where(_isCountedRecord)
          .where((r) => flowIsExpense ? r.isExpense : r.isIncome)
          .toList();

      DateTime cursor = DateTime(currentMonth.year, currentMonth.month, 1);
      for (var i = 0; i < 6; i++) {
        cursor = DateTime(cursor.year, cursor.month - 1, 1);
        final monthStart = cursor;
        final monthEnd = DateTime(cursor.year, cursor.month + 1, 0, 23, 59, 59);
        final monthExpense = allForHistory
            .where((r) =>
                !r.date.isBefore(monthStart) && !r.date.isAfter(monthEnd))
            .fold<double>(0, (s, r) => s + r.amount);
        if (monthExpense > 0) {
          history.add(monthExpense / monthEnd.day);
        }
      }

      history.sort();
      robustHistoryMonths = history.length;
      if (history.length >= 3) {
        final dailyMedian = _quantileSorted(history, 0.5);
        final dailyP25 = _quantileSorted(history, 0.25);
        final dailyP75 = _quantileSorted(history, 0.75);

        // 当前月到今天的实际累计 vs 历史日均的“应有累计”，做温和修正（避免过拟合）。
        final expectedSoFar = dailyMedian * daysPassed;
        final rawRatio =
            expectedSoFar > 0 ? (currentMonthExpense / expectedSoFar) : 1.0;
        final ratio = rawRatio.clamp(0.6, 1.6);
        // 记录很少时降低置信度（例如只有 1-2 天有支出）。
        predictionLowConfidence = currentExpenseDays < 3;

        robustPredicted = dailyMedian * totalDays * ratio;
        robustPredictedLow = dailyP25 * totalDays * ratio;
        robustPredictedHigh = dailyP75 * totalDays * ratio;
        predictionMethod = '近${history.length}个月日均中位数';
      } else if (daysPassed > 0) {
        // 历史不足：仍允许显示，但视为低置信度
        predictionLowConfidence = true;
        predictionMethod = '按天线性外推';
      }
    }
    
    // 生成洞察
    final insights = <String>[];
    if (yearOverYearChange > 10) {
      insights.add(
        '本年${flowIsExpense ? '支出' : '收入'}比去年增加${yearOverYearChange.toStringAsFixed(1)}%'
        '${flowIsExpense ? '，建议控制支出' : ''}',
      );
    } else if (yearOverYearChange < -10) {
      insights.add(
        '本年${flowIsExpense ? '支出' : '收入'}比去年减少${yearOverYearChange.abs().toStringAsFixed(1)}%'
        '${flowIsExpense ? '，继续保持' : ''}',
      );
    }
    
    if (categoryList.isNotEmpty) {
      final topCategory = categoryList.first;
      final topPercent =
          periodTotal > 0 ? (topCategory.value / periodTotal * 100) : 0.0;
      insights.add(
        '${topCategory.key}是您的主要${flowIsExpense ? '支出' : '收入'}类别，占比${topPercent.toStringAsFixed(1)}%',
      );
    }
    
    if (currentMonthExpense > avgMonthlyExpense * 1.2) {
      insights.add(flowIsExpense
          ? '本月支出已超过月均支出20%，建议控制'
          : '本月收入已超过月均收入20%');
    }
    
    return {
      'trendData': trendData,
      'compareTrendData': compareTrendData,
      'categoryData': categoryList.take(10).map((e) {
        return {
          'category': e.key,
          'amount': e.value,
          'percent': periodTotal > 0 ? (e.value / periodTotal * 100) : 0.0,
        };
      }).toList(),
      'yearOverYearChange': yearOverYearChange,
      'avgMonthlyExpense': avgMonthlyExpense,
      'predictedMonthExpense': robustPredicted,
      'predictedMonthExpenseLow': robustPredictedLow,
      'predictedMonthExpenseHigh': robustPredictedHigh,
      'currentMonthExpense': currentMonthExpense,
      'monthsWithExpense': monthsWithExpense,
      'predictionAvailable': predictionAvailable,
      'predictionMethod': predictionMethod,
      'predictionLowConfidence': predictionLowConfidence,
      'predictionHistoryMonths': robustHistoryMonths,
      'flowIsExpense': flowIsExpense,
      'insights': insights,
      'thisYearExpense': periodTotal,
      'lastYearExpense': lastPeriodTotal,
    };
  }

  /// 已排序数组的分位数（0..1），线性插值
  static double _quantileSorted(List<double> sorted, double q) {
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted.first;
    final clamped = q.clamp(0.0, 1.0);
    final pos = (sorted.length - 1) * clamped;
    final lower = pos.floor();
    final upper = pos.ceil();
    if (lower == upper) return sorted[lower];
    final weight = pos - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  /// 构建趋势分析卡片
  Widget _buildTrendAnalysisCard(ColorScheme cs, Map<String, dynamic> data) {
    final trendData = data['trendData'] as List<Map<String, dynamic>>? ?? [];
    if (trendData.isEmpty) return const SizedBox.shrink();
    final compareTrendData =
        data['compareTrendData'] as List<Map<String, dynamic>>? ?? [];
    final flowIsExpense = data['flowIsExpense'] as bool? ?? true;

    final totalValue = trendData.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (flowIsExpense
              ? (item['expense'] as double? ?? 0.0)
              : (item['income'] as double? ?? 0.0)),
    );
    final units = trendData.isEmpty ? 1 : trendData.length;
    final avgValue = totalValue / units;
    final unitLabel = _periodType == PeriodType.year ? '月' : '天';
      
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
                  flowIsExpense ? '支出趋势' : '收入趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${flowIsExpense ? '总支出' : '总收入'}：${totalValue.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '平均值：${avgValue.toStringAsFixed(2)}/$unitLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _buildTrendChart(trendData, compareTrendData, cs, flowIsExpense),
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
    final predictionAvailable = data['predictionAvailable'] as bool? ?? true;
    if (!predictionAvailable) return const SizedBox.shrink();
    final flowIsExpense = data['flowIsExpense'] as bool? ?? true;

    final predictedMonthExpense = data['predictedMonthExpense'] as double? ?? 0.0;
    final predictedMonthExpenseLow =
        data['predictedMonthExpenseLow'] as double? ?? 0.0;
    final predictedMonthExpenseHigh =
        data['predictedMonthExpenseHigh'] as double? ?? 0.0;
    final avgMonthlyExpense = data['avgMonthlyExpense'] as double? ?? 0.0;
    final currentMonthExpense = data['currentMonthExpense'] as double? ?? 0.0;
    final monthsWithExpense = data['monthsWithExpense'] as int? ?? 0;
    final predictionMethod = data['predictionMethod'] as String? ?? '';
    final predictionLowConfidence =
        data['predictionLowConfidence'] as bool? ?? false;
    final predictionHistoryMonths =
        data['predictionHistoryMonths'] as int? ?? 0;
    
    if (predictedMonthExpense == 0 &&
        avgMonthlyExpense == 0 &&
        currentMonthExpense == 0) {
      return const SizedBox.shrink();
    }
    
    final diff = predictedMonthExpense - avgMonthlyExpense;
    final diffPercent = avgMonthlyExpense > 0 ? (diff / avgMonthlyExpense * 100) : 0.0;
    final hasRange = predictedMonthExpenseLow > 0 &&
        predictedMonthExpenseHigh > 0 &&
        (predictedMonthExpenseHigh - predictedMonthExpenseLow).abs() >= 1;
    
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
                      flowIsExpense ? '本月已支出' : '本月已收入',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${currentMonthExpense.toStringAsFixed(0)}',
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
                      flowIsExpense ? '预计本月支出' : '预计本月收入',
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
                    if (hasRange) ...[
                      const SizedBox(height: 2),
                      Text(
                        '范围 ¥${predictedMonthExpenseLow.toStringAsFixed(0)} - ¥${predictedMonthExpenseHigh.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.65),
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (monthsWithExpense > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  predictionHistoryMonths >= 3 && predictionMethod.isNotEmpty
                      ? '参考：$predictionMethod（近$monthsWithExpense个月月均 ¥${avgMonthlyExpense.toStringAsFixed(0)}）'
                      : '参考：近$monthsWithExpense个月月均支出 ¥${avgMonthlyExpense.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            if (predictionLowConfidence && predictionHistoryMonths >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '提示：本月数据较少，预测仅供参考',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                ),
              ),
            if (monthsWithExpense >= 2 && diffPercent.abs() > 20)
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
                              ? '预计本月${flowIsExpense ? '支出' : '收入'}将比近$monthsWithExpense个月均高出${diffPercent.toStringAsFixed(1)}%'
                                  '${flowIsExpense ? '，建议控制支出' : ''}'
                              : '预计本月${flowIsExpense ? '支出' : '收入'}将比近$monthsWithExpense个月均低${diffPercent.abs().toStringAsFixed(1)}%'
                                  '${flowIsExpense ? '，继续保持' : ''}',
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
      final recordDay = DateTime(record.date.year, record.date.month, record.date.day);
      final start = DateUtilsX.startOfWeek(recordDay);
      final range = DateUtilsX.weekRange(recordDay);
      final summary = map.putIfAbsent(
        start,
        () => _WeekSummary(
          start: start,
          end: DateTime(range.end.year, range.end.month, range.end.day),
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
    final today = DateTime(now.year, now.month, now.day);
    final currentStart = DateUtilsX.startOfWeek(today);
    if (now.year == year && !map.containsKey(currentStart)) {
      final range = DateUtilsX.weekRange(today);
      map[currentStart] = _WeekSummary(
        start: currentStart,
        end: DateTime(range.end.year, range.end.month, range.end.day),
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
      final recordDay = DateTime(record.date.year, record.date.month, record.date.day);
      final start = DateUtilsX.startOfWeek(recordDay);
      final range = DateUtilsX.weekRange(recordDay);
      final summary = map.putIfAbsent(
        start,
        () => _WeekSummary(
          start: start,
          end: DateTime(range.end.year, range.end.month, range.end.day),
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
    final today = DateTime(now.year, now.month, now.day);
    final currentStart = DateUtilsX.startOfWeek(today);
    if (now.year == year && !map.containsKey(currentStart)) {
      final range = DateUtilsX.weekRange(today);
      map[currentStart] = _WeekSummary(
        start: currentStart,
        end: DateTime(range.end.year, range.end.month, range.end.day),
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
    bool flowIsExpense,
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
            value: (flowIsExpense
                    ? (e['expense'] as num?)
                    : (e['income'] as num?))
                ?.toDouble() ??
                0.0,
            color: cs.primary,
          ),
        )
        .toList();

    final compareEntries = compareData
        .map(
          (e) => ChartEntry(
            label: (e['label'] as String?) ?? '',
            value: (e['value'] as num?)?.toDouble() ?? 0.0,
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

    // 不展示均值线，仅保留异常点高亮
    final anomalyIndices = findAnomalyIndices(entries);

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ChartLine(
        entries: entries,
        compareEntries: compareEntries.isEmpty ? null : compareEntries,
        highlightIndices: anomalyIndices.isEmpty ? null : anomalyIndices,
        bottomLabelBuilder: (index, entry) {
          switch (_periodType) {
            case PeriodType.year:
              final month = index + 1;
              if (month == 1 || month % 3 == 0) return entry.label;
              return null;
            case PeriodType.month:
              final day = index + 1;
              final lastDay = entries.length;
              if (day == 30 && lastDay == 31) return null;
              if (day == 1 || day % 5 == 0 || day == lastDay) {
                return day.toString().padLeft(2, '0');
              }
              return null;
            case PeriodType.week:
              return entry.label;
          }
        },
      ),
    );
  }
}

enum _FlowMetric { expense, income }

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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.22),
          ),
          borderRadius: BorderRadius.circular(24),
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
                    color: cs.onSurface,
                  ),
                  _SummaryItem(
                    label: AppStrings.expense,
                    value: expense,
                    color: cs.onSurface,
                  ),
                  _SummaryItem(
                    label: AppStrings.balance,
                    value: balance,
                    color: cs.onSurface,
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
