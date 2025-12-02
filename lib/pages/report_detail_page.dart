import 'dart:io';

import 'dart:math';

import 'dart:typed_data';

import 'dart:ui' as ui;



import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'package:share_plus/share_plus.dart';



import '../l10n/app_strings.dart';

import '../l10n/app_text_templates.dart';

import '../models/book.dart';

import '../models/category.dart';

import '../models/period_type.dart';

import '../models/record.dart';

import '../providers/book_provider.dart';

import '../providers/category_provider.dart';

import '../providers/record_provider.dart';

import '../repository/category_repository.dart';

import '../theme/app_tokens.dart';

import '../utils/date_utils.dart';

import '../widgets/chart_bar.dart';

import '../widgets/chart_line.dart';

import '../widgets/chart_pie.dart';

import '../widgets/book_selector_button.dart';

import 'add_record_page.dart';

import 'bill_page.dart';



class ReportDetailPage extends StatefulWidget {

  const ReportDetailPage({

    super.key,

    required this.bookId,

    required this.year,

    this.month,

    this.weekRange,

    required this.periodType,

  });



  final String bookId;

  final int year;

  final int? month;

  final DateTimeRange? weekRange;

  final PeriodType periodType;



  @override

  State<ReportDetailPage> createState() => _ReportDetailPageState();

}



class _ReportDetailPageState extends State<ReportDetailPage> {

  bool _showIncomeCategory = false;

  

  // 用于保存图片的 GlobalKey

  final GlobalKey _reportContentKey = GlobalKey();


  bool get _isYearMode => widget.periodType == PeriodType.year;

  bool get _isMonthMode => widget.periodType == PeriodType.month;

  bool get _isWeekMode => widget.periodType == PeriodType.week;

  @override
  void initState() {
    super.initState();
    // 防止调试基线/描边在桌面导出时被外部工具开启，初始化时关闭相关调试绘制
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    debugRepaintTextRainbowEnabled = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;
      debugPaintPointersEnabled = false;
      debugPaintLayerBordersEnabled = false;
      debugRepaintRainbowEnabled = false;
      debugRepaintTextRainbowEnabled = false;
    });
  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final cs = theme.colorScheme;

    final recordProvider = context.watch<RecordProvider>();

    final categoryProvider = context.watch<CategoryProvider>();

    final bookProvider = context.watch<BookProvider>();

    final bookId = widget.bookId;

    Book? targetBook;

    for (final book in bookProvider.books) {

      if (book.id == bookId) {

        targetBook = book;

        break;

      }

    }

    targetBook ??= bookProvider.activeBook;

    final bookName = targetBook?.name ?? AppStrings.defaultBook;



    final records = _periodRecords(recordProvider, bookId);

    final hasData = records.isNotEmpty;

    final income = _periodIncome(recordProvider, bookId, records);

    final expense = _periodExpense(recordProvider, bookId, records);

    final balance = income - expense;

    final comparison = _previousBalance(recordProvider, bookId);

    final expenseDiff =

        comparison.hasData ? expense - comparison.balance : null;

    final range = _periodRange();



    final expenseEntries = _buildCategoryEntries(

      records,

      categoryProvider,

      cs,

      isIncome: false,

    );

    final incomeEntries = _buildCategoryEntries(

      records,

      categoryProvider,

      cs,

      isIncome: true,

    );

    final distributionEntries =

        _showIncomeCategory ? incomeEntries : expenseEntries;

    final rankingEntries = _showIncomeCategory ? incomeEntries : expenseEntries;

    final ranking = List<ChartEntry>.from(rankingEntries)

      ..sort((a, b) => b.value.compareTo(a.value));

    // 趋势图：月/周模式显示日趋势，年模式显示月趋势

    final dailyEntries = _buildDailyEntries(recordProvider, bookId, cs);



    final activity = _periodActivity(recordProvider, bookId);

    final totalExpenseValue =

        distributionEntries.fold<double>(0, (sum, e) => sum + e.value);

    final totalRankingValue =

        rankingEntries.fold<double>(0, (sum, e) => sum + e.value);

    const emptyText = AppStrings.emptyPeriodRecords;

    String? weeklySummaryText;

    if (_isWeekMode && hasData) {

      final currentExpense = expense;

      final currentRange = range;

      final prevStart = DateUtilsX.startOfWeek(currentRange.start)

          .subtract(const Duration(days: 7));

      final prevEnd = prevStart.add(const Duration(days: 6));

      final prevExpense = recordProvider.periodExpense(

        bookId: bookId,

        start: prevStart,

        end: prevEnd,

      );

      final diff = currentExpense - prevExpense;

      final topCategory =

          expenseEntries.isNotEmpty ? expenseEntries.first.label : AppStrings.unknown;

      weeklySummaryText = AppTextTemplates.weeklySummary(

        expense: currentExpense,

        diff: diff,

        topCategory: topCategory,

      );

    }



    return Scaffold(

      backgroundColor:

          isDark ? const Color(0xFF111418) : const Color(0xFFF8F9FA),

      appBar: AppBar(

        title: Text(_appBarTitle(range)),

        actions: [

          IconButton(

            tooltip: '保存图片',

            icon: const Icon(Icons.image_outlined),

            onPressed: () => _saveReportAsImage(context, bookName, range),

          ),

          const BookSelectorButton(compact: true),

          const SizedBox(width: 8),

        ],

      ),

      body: SafeArea(

        child: Center(

          child: ConstrainedBox(

            constraints: const BoxConstraints(maxWidth: 430),

            child: RepaintBoundary(

              key: _reportContentKey,

              child: SingleChildScrollView(

                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

                child: _buildReportContent(

                  context: context,

                  cs: cs,

                  isDark: isDark,

                  bookName: bookName,

                  range: range,

                  income: income,

                  expense: expense,

                  balance: balance,

                  expenseDiff: expenseDiff,

                  comparison: comparison,

                  hasData: hasData,

                  weeklySummaryText: weeklySummaryText,

                  onViewDetail: () => _openBillDetail(context, range, bookName),

                  showViewDetailButton: true,

                  distributionEntries: distributionEntries,

                  totalExpenseValue: totalExpenseValue,

                  ranking: ranking,

                  totalRankingValue: totalRankingValue,

                  categoryProvider: categoryProvider,

                  dailyEntries: dailyEntries,

                  activity: activity,

                  emptyText: emptyText,

                ),

              ),

            ),

          ),

        ),

      ),

    );

  }



  // 构建报表内容（用于正常显示和保存图片）

  Widget _buildReportContent({

    required BuildContext context,

    required ColorScheme cs,

    required bool isDark,

    required String bookName,

    required DateTimeRange range,

    required double income,

    required double expense,

    required double balance,

    required double? expenseDiff,

    required _PeriodComparison comparison,

    required bool hasData,

    String? weeklySummaryText,

    VoidCallback? onViewDetail,

    bool showViewDetailButton = true,

    required List<ChartEntry> distributionEntries,

    required double totalExpenseValue,

    required List<ChartEntry> ranking,

    required double totalRankingValue,

    required CategoryProvider categoryProvider,

    required List<ChartEntry> dailyEntries,

    required _PeriodActivity activity,

    required String emptyText,

  }) {

    return Column(

      children: [

                  _PeriodHeaderCard(

                    cs: cs,

                    isDark: isDark,

                    title: _headerTitle(range),

                    bookName: bookName,

                    range: range,

                    periodType: widget.periodType,

                    income: income,

                    expense: expense,

                    balance: balance,

                    balanceDiff: expenseDiff,

                    hasComparison: comparison.hasData,

                    hasData: hasData,

                    weeklySummaryText: weeklySummaryText,

                    onViewDetail: onViewDetail ?? (() =>

                        _openBillDetail(context, range, bookName)),

                    showViewDetailButton: showViewDetailButton,

                  ),

                  const SizedBox(height: 16),

                  if (!hasData)

                    _EmptyPeriodCard(cs: cs)

                  else ...[

                    _SectionCard(

                      title: _showIncomeCategory

                          ? AppStrings.incomeDistribution

                          : AppStrings.expenseDistribution,

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          SegmentedButton<bool>(

                            segments: const [

                              ButtonSegment(

                                value: false,

                                label: Text(AppStrings.expense),

                              ),

                              ButtonSegment(

                                value: true,

                                label: Text(AppStrings.income),

                              ),

                            ],

                            selected: {_showIncomeCategory},

                            onSelectionChanged: (value) {

                              setState(() {

                                _showIncomeCategory = value.first;

                              });

                            },

                          ),

                          const SizedBox(height: 16),

                          if (distributionEntries.isEmpty)

                            Padding(

                              padding:

                                  const EdgeInsets.symmetric(vertical: 32),

                              child: Center(

                                child: Text(

                                  emptyText,

                                  style: TextStyle(

                                    color: cs.onSurface.withOpacity(0.4),

                                    fontSize: 13,

                                  ),

                                ),

                              ),

                            )

                          else ...[

                            // 饼图和分类列表横向布局

                            Row(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                // 左侧：饼图

                                SizedBox(

                                  width: 120,

                                  height: 120,

                                  child: ChartPie(entries: distributionEntries),

                                ),

                                const SizedBox(width: 16),

                                // 右侧：分类列表

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      for (final entry in distributionEntries)

                                        Padding(

                                          padding: const EdgeInsets.only(bottom: 12),

                                          child: Row(

                                            crossAxisAlignment: CrossAxisAlignment.start,

                                            children: [

                                              Container(

                                                width: 12,

                                                height: 12,

                                                margin: const EdgeInsets.only(top: 2),

                                                decoration: BoxDecoration(

                                                  color: entry.color,

                                                  borderRadius:

                                                      BorderRadius.circular(3),

                                                ),

                                              ),

                                              const SizedBox(width: 10),

                                              Expanded(

                                                child: Text(

                                                  entry.label,

                                                  style: TextStyle(

                                                    fontSize: 14,

                                                    fontWeight: FontWeight.w500,

                                                    color: cs.onSurface.withOpacity(0.9),

                                                  ),

                                                ),

                                              ),

                                              SizedBox(

                                                width: 100,

                                                child: Text(

                                                  '${_formatAmount(entry.value)} (${(totalExpenseValue == 0 ? 0 : entry.value / totalExpenseValue * 100).toStringAsFixed(1)}%)',

                                                  style: TextStyle(

                                                    fontSize: 14,

                                                    fontWeight: FontWeight.w600,

                                                    color: cs.onSurface,

                                                    letterSpacing: 0.2,

                                                  ),

                                                  textAlign: TextAlign.right,

                                                ),

                                              ),

                                            ],

                                          ),

                                        ),

                                    ],

                                  ),

                                ),

                              ],

                            ),

                            const SizedBox(height: 12),

                            Text(

                              distributionEntries.length == 1

                                  ? AppTextTemplates.singleCategoryFullSummary(

                                      label: distributionEntries.first.label,

                                      amount: distributionEntries.first.value,

                                    )

                                  : AppTextTemplates

                                      .chartCategoryDistributionDesc,

                              style: TextStyle(

                                fontSize: 12,

                                color: cs.onSurface.withOpacity(0.6),

                                height: 1.5,

                              ),

                            ),

                          ],

                        ],

                      ),

                    ),

                    const SizedBox(height: 16),

                    // 支出排行TOP3

                    if (ranking.isNotEmpty)

                      _SectionCard(

                        title: _showIncomeCategory

                            ? '收入排行'

                            : AppStrings.expenseRanking,

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            for (var i = 0; i < ranking.take(3).length; i++)

                              Padding(

                                padding: EdgeInsets.only(

                                  bottom: i < 2 ? 16 : 0,

                                ),

                                child: _RankingItem(

                                  rank: i + 1,

                                  entry: ranking[i],

                                  categoryProvider: categoryProvider,

                                  cs: cs,

                                ),

                              ),

                          ],

                        ),

                      ),

                    if (ranking.isNotEmpty) const SizedBox(height: 16),

                    _SectionCard(

                      title: _isYearMode ? '月趋势' : AppStrings.dailyTrend,

                      child: dailyEntries.isEmpty

                          ? Padding(

                              padding:

                                  const EdgeInsets.symmetric(vertical: 40),

                              child: Center(

                                child: Column(

                                  children: [

                                    Icon(

                                      Icons.show_chart_outlined,

                                      size: 48,

                                      color: cs.onSurface.withOpacity(0.2),

                                    ),

                                    const SizedBox(height: 12),

                                    Text(

                                      _isYearMode ? '暂无月趋势数据' : '暂无日趋势数据',

                                      style: TextStyle(

                                        color: cs.onSurface.withOpacity(0.5),

                                        fontSize: 14,

                                        fontWeight: FontWeight.w500,

                                      ),

                                    ),

                                    const SizedBox(height: 6),

                                    Text(

                                      _isYearMode 

                                          ? '当有记账记录时会显示每月支出趋势'

                                          : '当有记账记录时会显示每日支出趋势',

                                      style: TextStyle(

                                        color: cs.onSurface.withOpacity(0.4),

                                        fontSize: 12,

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            )

                          : _buildDailyTrendContent(

                              dailyEntries: dailyEntries,

                              totalExpense: expense,

                              cs: cs,

                            ),

                    ),

                    const SizedBox(height: 16),

                    _SectionCard(

                      title: AppStrings.reportAchievements,

                      child: Column(

                        children: [

                          _AchievementRow(

                            label: AppStrings.recordCount,

                            value: activity.recordCount.toString(),

                          ),

                          const SizedBox(height: 14),

                          _AchievementRow(

                            label: AppStrings.activeDays,

                            value: activity.activeDays.toString(),

                          ),

                          const SizedBox(height: 14),

                          _AchievementRow(

                            label: AppStrings.streakDays,

                            value: activity.streak.toString(),

                          ),

                        ],

                      ),

                    ),

                  ],

      ],

    );

  }



  // 保存报表为图片

  Future<void> _saveReportAsImage(
    BuildContext context,
    String bookName,
    DateTimeRange range,
  ) async {
    // 关闭调试描边，避免导出图片出现黄色基线/尺寸线（无论 debug/运行时是否打开 DevTools 调试，都强制关闭）
    final prevDebugPaintSizeEnabled = debugPaintSizeEnabled;
    final prevDebugPaintBaselinesEnabled = debugPaintBaselinesEnabled;
    final prevDebugPaintPointersEnabled = debugPaintPointersEnabled;
    final prevDebugPaintLayerBordersEnabled = debugPaintLayerBordersEnabled;
    final prevDebugRepaintRainbowEnabled = debugRepaintRainbowEnabled;
    final prevDebugRepaintTextRainbowEnabled = debugRepaintTextRainbowEnabled;
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    debugRepaintTextRainbowEnabled = false;
    // 确保关闭后再出一帧，避免上一次调试基线残留在截图里
    RendererBinding.instance.renderView.markNeedsPaint();
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 16));
    try {
      // 显示加载提示

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Row(

              children: [

                SizedBox(

                  width: 16,

                  height: 16,

                  child: CircularProgressIndicator(strokeWidth: 2),

                ),

                SizedBox(width: 12),

                Text('正在生成图片...'),

              ],

            ),

            duration: Duration(seconds: 1),

          ),

        );

      }



      // 获取当前状态数据（用于构建全尺寸 widget）

      final theme = Theme.of(context);

      final isDark = theme.brightness == Brightness.dark;

      final cs = theme.colorScheme;

      final recordProvider = context.read<RecordProvider>();

      final categoryProvider = context.read<CategoryProvider>();

      final bookProvider = context.read<BookProvider>();

      final bookId = widget.bookId;

      Book? targetBook;

      for (final book in bookProvider.books) {

        if (book.id == bookId) {

          targetBook = book;

          break;

        }

      }

      targetBook ??= bookProvider.activeBook;

      final currentBookName = targetBook?.name ?? AppStrings.defaultBook;



      final records = _periodRecords(recordProvider, bookId);

      final hasData = records.isNotEmpty;

      final income = _periodIncome(recordProvider, bookId, records);

      final expense = _periodExpense(recordProvider, bookId, records);

      final balance = income - expense;

      final comparison = _previousBalance(recordProvider, bookId);

      final expenseDiff =

          comparison.hasData ? expense - comparison.balance : null;

      final currentRange = _periodRange();



      final expenseEntries = _buildCategoryEntries(

        records,

        categoryProvider,

        cs,

        isIncome: false,

      );

      final incomeEntries = _buildCategoryEntries(

        records,

        categoryProvider,

        cs,

        isIncome: true,

      );

      final distributionEntries =

          _showIncomeCategory ? incomeEntries : expenseEntries;

      final rankingEntries = _showIncomeCategory ? incomeEntries : expenseEntries;

      final ranking = List<ChartEntry>.from(rankingEntries)

        ..sort((a, b) => b.value.compareTo(a.value));

      // 趋势图：月/周模式显示日趋势，年模式显示月趋势

      final dailyEntries = _buildDailyEntries(recordProvider, bookId, cs);

      final activity = _periodActivity(recordProvider, bookId);

      final totalExpenseValue =

          distributionEntries.fold<double>(0, (sum, e) => sum + e.value);

      final totalRankingValue =

          rankingEntries.fold<double>(0, (sum, e) => sum + e.value);

      const emptyText = AppStrings.emptyPeriodRecords;

      String? weeklySummaryText;

      if (_isWeekMode && hasData) {

        final currentExpense = expense;

        final prevStart = DateUtilsX.startOfWeek(currentRange.start)

            .subtract(const Duration(days: 7));

        final prevEnd = prevStart.add(const Duration(days: 6));

        final prevExpense = recordProvider.periodExpense(

          bookId: bookId,

          start: prevStart,

          end: prevEnd,

        );

        final diff = currentExpense - prevExpense;

        final topCategory =

            expenseEntries.isNotEmpty ? expenseEntries.first.label : AppStrings.unknown;

        weeklySummaryText = AppTextTemplates.weeklySummary(

          expense: currentExpense,

          diff: diff,

          topCategory: topCategory,

        );

      }



      // 创建一个临时的全尺寸 widget 用于截图（不使用 SingleChildScrollView）

      final fullSizeKey = GlobalKey();

      final fullSizeWidget = RepaintBoundary(

        key: fullSizeKey,

        child: Container(

          width: 430,

          color: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),

          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),

          child: _buildReportContent(

            context: context,

            cs: cs,

            isDark: isDark,

            bookName: currentBookName,

            range: currentRange,

            income: income,

            expense: expense,

            balance: balance,

            expenseDiff: expenseDiff,

            comparison: comparison,

            hasData: hasData,

            weeklySummaryText: weeklySummaryText,

            onViewDetail: null,

            showViewDetailButton: false,

            distributionEntries: distributionEntries,

            totalExpenseValue: totalExpenseValue,

            ranking: ranking,

            totalRankingValue: totalRankingValue,

            categoryProvider: categoryProvider,

            dailyEntries: dailyEntries,

            activity: activity,

            emptyText: emptyText,

          ),

        ),

      );



      // 使用 Overlay 来渲染全尺寸 widget（放在屏幕外）

      final overlay = Overlay.of(context);

      final overlayEntry = OverlayEntry(

        builder: (context) => Positioned(

          left: -10000, // 放在屏幕外

          top: -10000,

          child: IgnorePointer(

            child: fullSizeWidget,

          ),

        ),

      );

      overlay.insert(overlayEntry);



      // 等待渲染完成

      await Future.delayed(const Duration(milliseconds: 300));

      await WidgetsBinding.instance.endOfFrame;



      // 获取 RenderRepaintBoundary

      final RenderRepaintBoundary? boundary = fullSizeKey.currentContext

          ?.findRenderObject() as RenderRepaintBoundary?;



      overlayEntry.remove();



      if (boundary == null) {

        if (context.mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('无法生成图片，请稍后重试')),

          );

        }

        return;

      }



      // 转换为图片

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);

      final ByteData? byteData =

          await image.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();



      if (byteData == null) {

        if (context.mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('图片生成失败')),

          );

        }

        return;

      }



      // 保存到临时文件

      final dir = await getTemporaryDirectory();

      final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final now = DateTime.now();

      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final periodLabel = widget.periodType == PeriodType.week

          ? '周报表'

          : widget.periodType == PeriodType.month

              ? '月报表'

              : '年报表';

      final fileName = '${safeBookName}_${periodLabel}_$dateStr.png';

      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(byteData.buffer.asUint8List());



      if (!context.mounted) return;



      // Windows 平台使用文件保存对话框，其他平台使用共享

      if (Platform.isWindows) {

        final savedPath = await FilePicker.platform.saveFile(

          dialogTitle: '保存图片',

          fileName: fileName,

          type: FileType.custom,

          allowedExtensions: ['png'],

        );



        if (savedPath != null) {

          await file.copy(savedPath);

          if (context.mounted) {

            final fileSize = await File(savedPath).length();

            final sizeStr = fileSize > 1024 * 1024

                ? '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'

                : '${(fileSize / 1024).toStringAsFixed(2)} KB';

            ScaffoldMessenger.of(context).showSnackBar(

              SnackBar(

                content: Column(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text('图片保存成功！'),

                    Text(

                      '文件大小：$sizeStr',

                      style: const TextStyle(fontSize: 12),

                    ),

                  ],

                ),

                duration: const Duration(seconds: 3),

              ),

            );

          }

        }

      } else {

        // 其他平台使用共享

        await Share.shareXFiles(

          [XFile(file.path)],

          subject: '指尖记账报表图片',

          text: '指尖记账报表截图',

        );

      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存图片失败，请稍后重试')),
        );
      }
    } finally {
      debugPaintSizeEnabled = prevDebugPaintSizeEnabled;
      debugPaintBaselinesEnabled = prevDebugPaintBaselinesEnabled;
      debugPaintPointersEnabled = prevDebugPaintPointersEnabled;
      debugPaintLayerBordersEnabled = prevDebugPaintLayerBordersEnabled;
      debugRepaintRainbowEnabled = prevDebugRepaintRainbowEnabled;
      debugRepaintTextRainbowEnabled = prevDebugRepaintTextRainbowEnabled;
    }
  }



  String _appBarTitle(DateTimeRange range) {

    if (_isWeekMode) {

      return DateUtilsX.weekLabel(_weekIndex(range.start));

    }

    if (_isMonthMode) {

      return AppStrings.monthReport;

    }

    return AppStrings.yearReport;

  }



  String _headerTitle(DateTimeRange range) {

    if (_isWeekMode) {

      return AppStrings.weekRangeLabel(range);

    }

    return AppStrings.periodBillTitle(widget.year, month: widget.month);

  }



  int _weekIndex(DateTime start) {

    final first = DateUtilsX.startOfWeek(DateTime(widget.year, 1, 1));

    final diff = start.difference(first).inDays;

    return (diff ~/ 7) + 1;

  }



  void _openBillDetail(

    BuildContext context,

    DateTimeRange range,

    String bookName,

  ) {

    Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) => BillPage(

          initialYear: widget.year,

          initialMonth: _isMonthMode

              ? DateTime(range.start.year, range.start.month, 1)

              : null,

          initialShowYearMode: _isYearMode,

          initialRange: _isWeekMode ? range : null,

          initialPeriodType: widget.periodType,

        ),

      ),

    );

  }



  List<Record> _periodRecords(

    RecordProvider recordProvider,

    String bookId,

  ) {

    final range = _periodRange();

    return recordProvider.recordsForPeriod(

      bookId,

      start: range.start,

      end: range.end,

    );

  }



  double _periodIncome(

    RecordProvider recordProvider,

    String bookId,

    List<Record> records,

  ) {

    if (_isYearMode) {

      double total = 0;

      for (var m = 1; m <= 12; m++) {

        total += recordProvider.monthIncome(

          DateTime(widget.year, m, 1),

          bookId,

        );

      }

      return total;

    }

    return records

        .where((r) => r.isIncome)

        .fold<double>(0, (sum, r) => sum + r.incomeValue);

  }



  double _periodExpense(

    RecordProvider recordProvider,

    String bookId,

    List<Record> records,

  ) {

    if (_isYearMode) {

      double total = 0;

      for (var m = 1; m <= 12; m++) {

        total += recordProvider.monthExpense(

          DateTime(widget.year, m, 1),

          bookId,

        );

      }

      return total;

    }

    return records

        .where((r) => r.isExpense)

        .fold<double>(0, (sum, r) => sum + r.expenseValue);

  }



  _PeriodComparison _previousBalance(

    RecordProvider recordProvider,

    String bookId,

  ) {

    if (_isYearMode) {

      final prevRange = DateTimeRange(

        start: DateTime(widget.year - 1, 1, 1),

        end: DateTime(widget.year - 1, 12, 31),

      );

      final records = recordProvider.recordsForPeriod(

        bookId,

        start: prevRange.start,

        end: prevRange.end,

      );

      final expense = records

          .where((r) => r.isExpense)

          .fold<double>(0, (sum, r) => sum + r.expenseValue);

      return _PeriodComparison(

        balance: expense,

        hasData: records.isNotEmpty,

      );

    }

    if (_isWeekMode) {

      final start = DateUtilsX.startOfWeek(_periodRange().start)

          .subtract(const Duration(days: 7));

      final prevRange = DateTimeRange(start: start, end: start.add(const Duration(days: 6)));

      final records = recordProvider.recordsForPeriod(

        bookId,

        start: prevRange.start,

        end: prevRange.end,

      );

      final expense = records

          .where((r) => r.isExpense)

          .fold<double>(0, (sum, r) => sum + r.expenseValue);

      return _PeriodComparison(

        balance: expense,

        hasData: records.isNotEmpty,

      );

    }



    final currentMonth =

        DateTime(widget.year, widget.month ?? DateTime.now().month, 1);

    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);

    final expense = recordProvider.monthExpense(prevMonth, bookId);

    final hasData = recordProvider

        .recordsForMonth(bookId, prevMonth.year, prevMonth.month)

        .isNotEmpty;

    return _PeriodComparison(balance: expense, hasData: hasData);

  }



  List<ChartEntry> _buildCategoryEntries(

    List<Record> records,

    CategoryProvider categoryProvider,

    ColorScheme cs, {

    required bool isIncome,

  }) {

    final Map<String, double> expenseMap = {};

    for (final record in records) {

      if (record.isIncome != isIncome) continue;

      final value = record.isIncome ? record.incomeValue : record.expenseValue;

      expenseMap[record.categoryKey] =

          (expenseMap[record.categoryKey] ?? 0) + value;

    }



    final categories = categoryProvider.categories;

    // 统一的分类调色板：保证不同分类在饼图/柱状图中使用不同的颜色

    const palette = <Color>[

      Color(0xFF3B82F6), // 蓝

      Color(0xFFF59E0B), // 橙

      Color(0xFF10B981), // 绿

      Color(0xFFE11D48), // 红

      Color(0xFF8B5CF6), // 紫

      Color(0xFF06B6D4), // 青

      Color(0xFF84CC16), // 黄绿

    ];

    var colorIndex = 0;

    final entries = <ChartEntry>[];

    for (final entry in expenseMap.entries) {

      final category = categories.firstWhere(

        (c) => c.key == entry.key,

        orElse: () => Category(

          key: entry.key,

          name: '未分类', // 如果找不到分类，使用中文默认名称

          icon: Icons.category_outlined,

          isExpense: true,

        ),

      );

      // 如果分类名称是英文（只包含英文字母、数字、下划线），尝试根据 key 映射到中文名称

      String categoryName = category.name;

      if (_isEnglishOnly(category.name)) {

        // 先尝试从默认分类中查找对应的中文名称

        final defaultCategory = _getDefaultCategoryName(entry.key);

        if (defaultCategory != null) {

          categoryName = defaultCategory;

        } else {

          // 如果找不到，尝试根据 key 的常见模式映射

          categoryName = _mapEnglishKeyToChinese(entry.key);

        }

      }

      final color = palette[colorIndex % palette.length];

      colorIndex++;

      entries.add(

        ChartEntry(

          label: categoryName,

          value: entry.value,

          color: color,

        ),

      );

    }



    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries;

  }



  List<ChartEntry> _buildDailyEntries(

    RecordProvider recordProvider,

    String bookId,

    ColorScheme cs,

  ) {

    if (_isYearMode) {

      // 年模式：构建12个月的月趋势数据

      final entries = <ChartEntry>[];

      for (var month = 1; month <= 12; month++) {

        final monthDate = DateTime(widget.year, month, 1);

        final expense = recordProvider.monthExpense(monthDate, bookId);

        entries.add(

          ChartEntry(

            label: '$month月',

            value: expense,

            color: cs.primary,

          ),

        );

      }

      return entries;

    }

    

    // 日趋势的横轴应该覆盖完整周期：

    // - 月视图：当月 1 号 ~ 当月最后一天（即使还没到月底，后面的天数也显示为 0）

    // - 周视图：本周 7 天

    final baseRange = _periodRange();

    DateTime start = baseRange.start;

    DateTime end = baseRange.end;



    if (_isMonthMode) {

      // 当月从 1 号到最后一天

      start = DateTime(start.year, start.month, 1);

      end = DateTime(start.year, start.month + 1, 0);

    } else if (_isWeekMode) {

      // 确保是完整的一周（7 天）

      start = DateUtilsX.startOfWeek(start);

      end = start.add(const Duration(days: 6));

    }



    final dayCount = end.difference(start).inDays + 1;

    final days = List.generate(

      dayCount,

      (i) => start.add(Duration(days: i)),

    );



    return days

        .map(

          (d) => ChartEntry(

            label: _isWeekMode ? '${d.month}/${d.day}' : d.day.toString(),

            value: recordProvider.dayExpense(bookId, d),

            color: cs.primary,

          ),

        )

        .toList();

  }



  // 构建趋势内容（包含统计摘要和图表）：日趋势或月趋势

  Widget _buildDailyTrendContent({

    required List<ChartEntry> dailyEntries,

    required double totalExpense,

    required ColorScheme cs,

  }) {

    double maxDailyExpense = 0;

    int? maxIndex;

    DateTime? maxDate;

    

    if (_isYearMode) {

      // 年模式：月趋势统计

      for (var i = 0; i < dailyEntries.length; i++) {

        if (dailyEntries[i].value > maxDailyExpense) {

          maxDailyExpense = dailyEntries[i].value;

          maxIndex = i;

        }

      }

    } else {

      // 日趋势统计

      final baseRange = _periodRange();

      DateTime start = baseRange.start;

      DateTime end = baseRange.end;



      if (_isMonthMode) {

        start = DateTime(start.year, start.month, 1);

        end = DateTime(start.year, start.month + 1, 0);

      } else if (_isWeekMode) {

        start = DateUtilsX.startOfWeek(start);

        end = start.add(const Duration(days: 6));

      }



      final dayCount = end.difference(start).inDays + 1;

      final days = List.generate(

        dayCount,

        (i) => start.add(Duration(days: i)),

      );



      // 计算统计数据

      final minLength = min(dailyEntries.length, days.length);

      for (var i = 0; i < minLength; i++) {

        if (dailyEntries[i].value > maxDailyExpense) {

          maxDailyExpense = dailyEntries[i].value;

          maxDate = days[i];

        }

      }

    }



    final periodCount = _isYearMode ? 12 : (_isWeekMode ? 7 : (_isMonthMode ? DateTime(widget.year, widget.month ?? 12, 0).day : 30));

    final avgExpense = periodCount > 0 ? totalExpense / periodCount : 0.0;

    final periodLabel = _isYearMode ? '本年' : (_isWeekMode ? '本周' : _isMonthMode ? '本月' : '本期');



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        // 统计摘要

        Row(

          children: [

            Expanded(

              child: _DailyTrendStatItem(

                label: _isYearMode ? '单月支出最高' : '单日支出最高',

                value: maxDailyExpense,

                date: _isYearMode 

                    ? (maxIndex != null ? DateTime(widget.year, maxIndex! + 1, 1) : null)

                    : maxDate,

                isYearMode: _isYearMode,

                cs: cs,

              ),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: _DailyTrendStatItem(

                label: _isYearMode ? '月均支出' : '日均支出',

                value: avgExpense,

                cs: cs,

              ),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: _DailyTrendStatItem(

                label: '$periodLabel支出',

                value: totalExpense,

                cs: cs,

              ),

            ),

          ],

        ),

        const SizedBox(height: 16),

        // 图表：年模式不需要横向滚动，月/周模式需要

        SizedBox(
          height: 200,
          width: double.infinity,
          child: ChartLine(entries: dailyEntries),
        ),
        const SizedBox(height: 12),

        Text(

          _isYearMode 

              ? '展示本年度每月的支出趋势，方便你了解消费高峰和低谷。'

              : AppStrings.chartDailyTrendDesc,

          style: TextStyle(

            fontSize: 12,

            color: cs.onSurface.withOpacity(0.6),

            height: 1.5,

          ),

        ),

      ],

    );

  }





  /// 检查字符串是否只包含英文字母、数字、下划线

  bool _isEnglishOnly(String text) {

    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(text);

  }



  /// 根据分类 key 获取默认的中文名称

  String? _getDefaultCategoryName(String key) {

    // 从默认分类中查找对应的中文名称

    final defaultCategories = CategoryRepository.defaultCategories;

    try {

      final defaultCategory = defaultCategories.firstWhere(

        (c) => c.key == key,

      );

      return defaultCategory.name;

    } catch (e) {

      return null;

    }

  }



  /// 将常见的英文分类 key 映射到中文名称

  String _mapEnglishKeyToChinese(String key) {

    // 常见英文分类 key 到中文名称的映射

    final Map<String, String> keyMap = {

      'food': '餐饮',

      'shopping': '购物',

      'transport': '出行',

      'living': '居住与账单',

      'leisure': '娱乐休闲',

      'education': '教育成长',

      'health': '健康医疗',

      'family': '家庭与人情',

      'finance': '金融与其他',

      'meal': '正餐/工作餐',

      'breakfast': '早餐',

      'snack': '零食小吃',

      'drink': '饮料/奶茶/咖啡',

      'takeout': '外卖',

      'supper': '夜宵',

      'daily': '日用百货',

      'supermarket': '超市采购',

      'clothes': '服饰鞋包',

      'digital': '数码家电',

      'beauty': '美妆护肤',

      'commute': '通勤交通',

      'taxi': '打车/网约车',

      'drive': '自驾油费/停车',

      'rent': '房租/房贷',

      'utility': '水电燃气',

      'internet': '网费/电视/宽带',

      'sport': '运动健身',

      'travel': '旅游度假',

      'course': '课程培训',

      'book': '书籍/电子书',

      'medicine': '药品',

      'gift': '礼金/红包',

    };

    

    // 如果 key 完全匹配，直接返回

    if (keyMap.containsKey(key)) {

      return keyMap[key]!;

    }

    

    // 如果 key 包含常见前缀，尝试匹配

    for (final entry in keyMap.entries) {

      if (key.contains(entry.key) || entry.key.contains(key)) {

        return entry.value;

      }

    }

    

    // 如果都找不到，返回"未分类"

    return '未分类';

  }



  _PeriodActivity _periodActivity(

    RecordProvider recordProvider,

    String bookId,

  ) {

    final range = _periodRange();

    final records = recordProvider.recordsForPeriod(

      bookId,

      start: range.start,

      end: range.end,

    );

    final activeDays = <String>{};

    for (final record in records) {

      activeDays.add(DateUtilsX.ymd(record.date));

    }

    // 杩炵画澶╂暟锛氱畝鍖栦负娲诲姩澶╂暟

    return _PeriodActivity(

      recordCount: records.length,

      activeDays: activeDays.length,

      streak: activeDays.length,

    );

  }



  DateTimeRange _periodRange() {

    if (_isWeekMode) {

      if (widget.weekRange != null) return widget.weekRange!;

      final today = DateTime.now();

      final base = DateTime(widget.year, today.month, today.day);

      final range = DateUtilsX.weekRange(base);

      return DateTimeRange(start: range.start, end: range.end);

    }

    final start = DateTime(widget.year, widget.month ?? 1, 1);

    final end = _isYearMode

        ? DateTime(widget.year, 12, 31)

        : DateUtilsX.lastDayOfMonth(start);

    return DateTimeRange(start: start, end: end);

  }

}



// 金额格式化工具（千分位）

String _formatAmount(double value) {

  final abs = value.abs();

  if (abs >= 100000000) {

    return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';

  }

  if (abs >= 10000) {

    return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';

  }

  return value.toStringAsFixed(2);

}



class _PeriodHeaderCard extends StatelessWidget {

  const _PeriodHeaderCard({

    required this.cs,

    required this.isDark,

    required this.title,

    required this.bookName,

    required this.range,

    required this.periodType,

    required this.income,

    required this.expense,

    required this.balance,

    required this.balanceDiff,

    required this.hasComparison,

    required this.hasData,

    this.weeklySummaryText,

    this.onViewDetail,

    this.showViewDetailButton = true,

  });



  final ColorScheme cs;

  final bool isDark;

  final String title;

  final String bookName;

  final DateTimeRange range;

  final PeriodType periodType;

  final double income;

  final double expense;

  final double balance;

  final double? balanceDiff;

  final bool hasComparison;

    final bool hasData;

    final String? weeklySummaryText;

    final VoidCallback? onViewDetail;

    final bool showViewDetailButton;

  

    @override

    Widget build(BuildContext context) {

      final conclusion = _buildConclusion();

      final bool useWeeklySummary =

          periodType == PeriodType.week && weeklySummaryText != null;

      // 鍓爣棰樺彧灞曠ず褰撳墠璐︽湰锛岄伩鍏嶄笌 AppBar 鍜屾爣棰橀噸澶嶅睍绀哄懆鏈熶俊鎭?      final subtitle = AppStrings.currentBookLabel(bookName);

      return Container(

        width: double.infinity,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(

          color: isDark ? cs.surface : Colors.white,

          borderRadius: BorderRadius.circular(12),

          boxShadow: isDark

              ? null

              : [

                  BoxShadow(

                    color: Colors.black.withOpacity(0.04),

                    blurRadius: 8,

                    offset: const Offset(0, 2),

                  ),

                ],

        ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: TextStyle(

                        fontSize: 15,

                        fontWeight: FontWeight.w600,

                        color: cs.onSurface.withOpacity(0.85),

                        letterSpacing: 0.1,

                      ),

                    ),

                    const SizedBox(height: 6),

                    Text(

                      AppStrings.currentBookLabel(bookName),

                      style: TextStyle(

                        fontSize: 12,

                        color: cs.onSurface.withOpacity(0.5),

                        fontWeight: FontWeight.w400,

                      ),

                    ),

                  ],

                ),

              ),

              if (showViewDetailButton && onViewDetail != null)

                OutlinedButton(

                  onPressed: onViewDetail,

                  style: OutlinedButton.styleFrom(

                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(6),

                    ),

                    side: BorderSide(color: cs.primary.withOpacity(0.3)),

                  ),

                  child: Text(

                    AppTextTemplates.viewBillList,

                    style: TextStyle(

                      fontSize: 13,

                      color: cs.primary,

                      fontWeight: FontWeight.w500,

                    ),

                  ),

                ),

            ],

          ),

          const SizedBox(height: 12),

          Row(

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      AppStrings.balance,

                      style: TextStyle(

                        fontSize: 12,

                        fontWeight: FontWeight.w500,

                        color: cs.onSurface.withOpacity(0.6),

                        letterSpacing: 0.3,

                      ),

                    ),

                    const SizedBox(height: 10),

                    Text(

                      _formatAmount(balance),

                      style: TextStyle(

                        fontSize: 24,

                        fontWeight: FontWeight.w500,

                        color: Colors.black,

                        height: 1.0,

                        letterSpacing: -0.5,

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      useWeeklySummary ? weeklySummaryText! : conclusion,

                      style: TextStyle(

                        fontSize: 11,

                        color: cs.onSurface.withOpacity(0.5),

                        height: 1.4,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(width: 20),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [

                    _SummaryMetric(

                      label: AppStrings.income,

                      value: income,

                      color: cs.primary,

                    ),

                    const SizedBox(height: 18),

                    _SummaryMetric(

                      label: AppStrings.expense,

                      value: expense,

                      color: cs.error,

                    ),

                  ],

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }



  String _buildConclusion() {

    final periodName = periodType == PeriodType.year

        ? '\u672c\u5e74'

        : periodType == PeriodType.week

            ? '\u672c\u5468'

            : '\u672c\u6708';

    final compareLabel =

        periodType == PeriodType.year ? '上年' : periodType == PeriodType.week ? '上周' : '上月';

    if (!hasData) {

      return AppStrings.emptyPeriodRecords;

    }

    if (!hasComparison || balanceDiff == null) {

      return AppStrings.previousPeriodNoData;

    }

    final verb = balanceDiff! >= 0 ? '增加' : '减少';

    return '$periodName\u652f\u51fa ${expense.toStringAsFixed(2)} \u5143\uff0c\u8f83$compareLabel$verb ${balanceDiff!.abs().toStringAsFixed(2)} \u5143';

  }



  int _weekIndexForRange(DateTimeRange range) {

    final first =

        DateUtilsX.startOfWeek(DateTime(range.start.year, 1, 1));

    final diff = range.start.difference(first).inDays;

    return (diff ~/ 7) + 1;

  }

}



class _SectionCard extends StatelessWidget {

  const _SectionCard({

    required this.title,

    this.trailing,

    required this.child,

  });



  final String title;

  final Widget? trailing;

  final Widget child;



  @override

  Widget build(BuildContext context) {

    final cs = Theme.of(context).colorScheme;

      return Container(

        margin: EdgeInsets.zero,

        decoration: BoxDecoration(

          color: cs.surface,

          borderRadius: BorderRadius.circular(12),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withOpacity(0.03),

              blurRadius: 8,

              offset: const Offset(0, 2),

            ),

          ],

        ),

        child: Padding(

          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Text(

                  title,

                  style: TextStyle(

                    fontSize: 15,

                    fontWeight: FontWeight.w600,

                    color: cs.onSurface.withOpacity(0.9),

                    letterSpacing: 0.2,

                  ),

                ),

                const Spacer(),

                if (trailing != null) trailing!,

              ],

            ),

            const SizedBox(height: 18),

            DefaultTextStyle(

              style: TextStyle(

                color: cs.onSurface.withOpacity(0.85),

                fontSize: 14,

                height: 1.5,

              ),

              child: child,

            ),

          ],

        ),

      ),

    );

  }



  int _weekIndexForRange(DateTimeRange range) {

    final first =

        DateUtilsX.startOfWeek(DateTime(range.start.year, 1, 1));

    final diff = range.start.difference(first).inDays;

    return (diff ~/ 7) + 1;

  }

}



class _EmptyPeriodCard extends StatelessWidget {

  const _EmptyPeriodCard({required this.cs});



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

          const Text(

            AppStrings.emptyPeriodRecords,

            style: TextStyle(

              fontWeight: FontWeight.w700,

              fontSize: 14,

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



class _SummaryMetric extends StatelessWidget {

  const _SummaryMetric({

    required this.label,

    required this.value,

    required this.color,

  });



  final String label;

  final double value;

  final Color color;



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.end,

      children: [

        Text(

          label,

          style: TextStyle(

            fontSize: 11,

            fontWeight: FontWeight.w500,

            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),

            letterSpacing: 0.2,

          ),

        ),

        const SizedBox(height: 6),

        Text(

          _formatAmount(value),

          style: TextStyle(

            fontSize: 16,

            fontWeight: FontWeight.w500,

            color: Colors.black,

            height: 1.2,

            letterSpacing: -0.3,

          ),

          textAlign: TextAlign.right,

        ),

      ],

    );

  }

}



class _AchievementRow extends StatelessWidget {

  const _AchievementRow({

    required this.label,

    required this.value,

  });



  final String label;

  final String value;



  @override

  Widget build(BuildContext context) {

    final cs = Theme.of(context).colorScheme;

    return Row(

      children: [

        Expanded(

          child: Text(

            label,

            style: TextStyle(

              color: cs.onSurface.withOpacity(0.7),

              fontSize: 14,

              fontWeight: FontWeight.w400,

            ),

          ),

        ),

        Text(

          value,

          style: TextStyle(

            fontWeight: FontWeight.w700,

            fontSize: 15,

            color: cs.onSurface,

          ),

        ),

      ],

    );

  }

}



class _PeriodActivity {

  _PeriodActivity({

    required this.recordCount,

    required this.activeDays,

    required this.streak,

  });



  final int recordCount;

  final int activeDays;

  final int streak;

}



class _PeriodComparison {

  _PeriodComparison({

    required this.balance,

    required this.hasData,

  });



  final double balance;

  final bool hasData;

}



// 排行项组件

class _RankingItem extends StatelessWidget {

  const _RankingItem({

    required this.rank,

    required this.entry,

    required this.categoryProvider,

    required this.cs,

  });



  final int rank;

  final ChartEntry entry;

  final CategoryProvider categoryProvider;

  final ColorScheme cs;



  String _formatAmount(double value) {

    final abs = value.abs();

    if (abs >= 100000000) {

      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';

    }

    if (abs >= 10000) {

      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';

    }

    return value.toStringAsFixed(2);

  }



  Category _findCategoryByLabel(String label) {

    // 尝试通过名称匹配分类

    final categories = categoryProvider.categories;

    try {

      return categories.firstWhere(

        (c) => c.name == label,

      );

    } catch (_) {

      // 如果精确匹配失败，尝试模糊匹配

      try {

        return categories.firstWhere(

          (c) => c.name.contains(label) || label.contains(c.name),

        );

      } catch (_) {

        // 如果都找不到，返回默认分类

        return Category(

          key: '',

          name: label,

          icon: Icons.category_outlined,

          isExpense: true,

        );

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    final category = _findCategoryByLabel(entry.label);

    return Row(

      children: [

        // 排名

        Container(

          width: 24,

          height: 24,

          decoration: BoxDecoration(

            color: cs.primary.withOpacity(0.1),

            borderRadius: BorderRadius.circular(4),

          ),

          child: Center(

            child: Text(

              rank.toString(),

              style: TextStyle(

                fontSize: 12,

                fontWeight: FontWeight.w600,

                color: cs.primary,

              ),

            ),

          ),

        ),

        const SizedBox(width: 12),

        // 分类图标

        Container(

          width: 32,

          height: 32,

          decoration: BoxDecoration(

            color: entry.color.withOpacity(0.1),

            borderRadius: BorderRadius.circular(6),

          ),

          child: Icon(

            category.icon,

            size: 18,

            color: entry.color,

          ),

        ),

        const SizedBox(width: 12),

        // 分类名称

        Expanded(

          child: Text(

            entry.label,

            style: TextStyle(

              fontSize: 14,

              fontWeight: FontWeight.w500,

              color: cs.onSurface.withOpacity(0.9),

            ),

          ),

        ),

        // 金额

        Text(

          _formatAmount(entry.value),

          style: TextStyle(

            fontSize: 14,

            fontWeight: FontWeight.w600,

            color: Colors.black,

          ),

        ),

      ],

    );

  }

}



// 日趋势统计项组件

class _DailyTrendStatItem extends StatelessWidget {

  const _DailyTrendStatItem({

    required this.label,

    required this.value,

    this.date,

    this.isYearMode = false,

    required this.cs,

  });



  final String label;

  final double value;

  final DateTime? date;

  final bool isYearMode;

  final ColorScheme cs;



  String _formatAmount(double value) {

    final abs = value.abs();

    if (abs >= 100000000) {

      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';

    }

    if (abs >= 10000) {

      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';

    }

    return value.toStringAsFixed(2);

  }



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: TextStyle(

            fontSize: 11,

            color: cs.onSurface.withOpacity(0.6),

            fontWeight: FontWeight.w500,

          ),

        ),

        const SizedBox(height: 4),

        Text(

          _formatAmount(value),

          style: TextStyle(

            fontSize: 14,

            color: Colors.black,

            fontWeight: FontWeight.w600,

          ),

        ),

        if (date != null) ...[

          const SizedBox(height: 2),

          Text(

            isYearMode ? '${date!.month}月' : '${date!.month}月${date!.day}日',

            style: TextStyle(

              fontSize: 10,

              color: cs.onSurface.withOpacity(0.5),

            ),

          ),

        ],

      ],

    );

  }

}



