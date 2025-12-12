import 'dart:io';

import 'dart:math';

import 'dart:typed_data';

import 'dart:ui' as ui;



import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

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

import '../utils/date_utils.dart';
import '../utils/category_name_helper.dart';
import '../utils/error_handler.dart';

import '../widgets/chart_entry.dart';

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

    // 检查加载状态
    if (!recordProvider.loaded || !categoryProvider.loaded || !bookProvider.loaded) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text('报表详情'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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



    // 使用 FutureBuilder 异步加载报表数据（支持100万条记录）
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadReportData(recordProvider, bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('报表详情'),
              backgroundColor: Colors.transparent,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('报表详情'),
              backgroundColor: Colors.transparent,
            ),
            body: Center(child: Text('加载失败: ${snapshot.error}')),
          );
        }

        final data = snapshot.data ?? {};
        final records = data['records'] as List<Record>? ?? [];
        final income = data['income'] as double? ?? 0.0;
        final expense = data['expense'] as double? ?? 0.0;
        final balance = income - expense;
        final comparison = data['comparison'] as _PeriodComparison? ?? _PeriodComparison(balance: 0, hasData: false);
        final expenseDiff = comparison.hasData ? expense - comparison.balance : null;
        final range = _periodRange();
        final hasData = records.isNotEmpty;

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

        final distributionEntries = _showIncomeCategory ? incomeEntries : expenseEntries;
        final rankingEntries = _showIncomeCategory ? incomeEntries : expenseEntries;

        final ranking = List<ChartEntry>.from(rankingEntries)
          ..sort((a, b) => b.value.compareTo(a.value));

        // 趋势图：月/周模式显示日趋势，年模式显示月趋势
        // 使用 FutureBuilder 单独加载日趋势数据（需要 context）
        final activity = data['activity'] as _PeriodActivity? ?? _PeriodActivity(recordCount: 0, activeDays: 0, streak: 0);
        
        return FutureBuilder<List<ChartEntry>>(
          future: _buildDailyEntriesAsync(recordProvider, bookId),
          builder: (context, dailySnapshot) {
            final dailyEntries = dailySnapshot.data ?? [];

            final totalExpenseValue = distributionEntries.fold<double>(0, (sum, e) => sum + e.value);
            final totalRankingValue = rankingEntries.fold<double>(0, (sum, e) => sum + e.value);

            const emptyText = AppStrings.emptyPeriodRecords;

            String? weeklySummaryText;
            if (_isWeekMode && hasData) {
              final currentExpense = expense;
              final currentRange = range;
              
              // 使用异步方法获取上一周的支出
              final prevExpense = data['prevWeekExpense'] as double? ?? 0.0;
              final diff = currentExpense - prevExpense;
              final topCategory = expenseEntries.isNotEmpty ? expenseEntries.first.label : AppStrings.unknown;

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
          },
        );
      },
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

                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(

                                    color: cs.onSurface.withOpacity(0.4),

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

                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(

                                                    color: cs.onSurface.withOpacity(0.9),

                                                  ),

                                                ),

                                              ),

                                              SizedBox(

                                                width: 100,

                                                child: Text(

                                                  '${_formatAmount(entry.value)} (${(totalExpenseValue == 0 ? 0 : entry.value / totalExpenseValue * 100).toStringAsFixed(1)}%)',

                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(

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

                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(

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

                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(

                                        color: cs.onSurface.withOpacity(0.5),

                                      ),

                                    ),

                                    const SizedBox(height: 6),

                                    Text(

                                      _isYearMode 

                                          ? '当有记账记录时会显示每月支出趋势'

                                          : '当有记账记录时会显示每日支出趋势',

                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                                        color: cs.onSurface.withOpacity(0.4),

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
    for (final view in RendererBinding.instance.renderViews) {
      view.markNeedsPaint();
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 16));
    
    if (!context.mounted) return;
    
    try {
      // 显示加载提示
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

      // 加载报表数据
      final reportData = await _loadReportData(recordProvider, bookId);
      final records = reportData['records'] as List<Record>? ?? [];
      final income = reportData['income'] as double? ?? 0.0;
      final expense = reportData['expense'] as double? ?? 0.0;
      final balance = income - expense;
      final comparison = reportData['comparison'] as _PeriodComparison? ?? _PeriodComparison(balance: 0, hasData: false);
      final expenseDiff = comparison.hasData ? expense - comparison.balance : null;
      final currentRange = range;
      final hasData = records.isNotEmpty;

      // 构建分类条目
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
      final distributionEntries = _showIncomeCategory ? incomeEntries : expenseEntries;
      final rankingEntries = _showIncomeCategory ? incomeEntries : expenseEntries;
      final ranking = List<ChartEntry>.from(rankingEntries)
        ..sort((a, b) => b.value.compareTo(a.value));
      final totalExpenseValue = distributionEntries.fold<double>(0, (sum, e) => sum + e.value);
      final totalRankingValue = rankingEntries.fold<double>(0, (sum, e) => sum + e.value);

      // 加载日趋势数据
      final dailyEntries = await _buildDailyEntriesAsync(recordProvider, bookId);
      final activity = reportData['activity'] as _PeriodActivity? ?? _PeriodActivity(recordCount: 0, activeDays: 0, streak: 0);
      const emptyText = AppStrings.emptyPeriodRecords;

      String? weeklySummaryText;
      if (_isWeekMode && hasData) {
        final prevExpense = reportData['prevWeekExpense'] as double? ?? 0.0;
        final diff = expense - prevExpense;
        final topCategory = expenseEntries.isNotEmpty ? expenseEntries.first.label : AppStrings.unknown;
        weeklySummaryText = AppTextTemplates.weeklySummary(
          expense: expense,
          diff: diff,
          topCategory: topCategory,
        );
      }

      // 创建 GlobalKey 用于截图
      final fullSizeKey = GlobalKey();

      if (!context.mounted) return;

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

      if (!context.mounted) return;

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

      if (!context.mounted) {
        overlayEntry.remove();
        return;
      }

      // 获取 RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = fullSizeKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      overlayEntry.remove();



      if (boundary == null) {
        if (context.mounted) {
          ErrorHandler.showError(context, '无法生成图片，请稍后重试');
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

          ErrorHandler.showError(context, '图片生成失败');

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
            
            if (!context.mounted) return;
            
            final sizeStr = fileSize > 1024 * 1024
                ? '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'
                : '${(fileSize / 1024).toStringAsFixed(2)} KB';

            ErrorHandler.showSuccess(
              context,
              '图片保存成功！文件大小：$sizeStr',
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
        ErrorHandler.handleAsyncError(context, e);
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



  /// 异步加载报表数据（支持100万条记录）
  Future<Map<String, dynamic>> _loadReportData(
    RecordProvider recordProvider,
    String bookId,
  ) async {
    final range = _periodRange();
    
    // 异步加载时间段记录
    final records = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: range.start,
      end: range.end,
    );

    // 计算收入和支出
    double income;
    double expense;
    
    if (_isYearMode) {
      // 年度模式：使用聚合查询
      double totalIncome = 0;
      double totalExpense = 0;
      for (var m = 1; m <= 12; m++) {
        final monthStats = await recordProvider.getMonthStatsAsync(
          DateTime(widget.year, m, 1),
          bookId,
        );
        totalIncome += monthStats.income;
        totalExpense += monthStats.expense;
      }
      income = totalIncome;
      expense = totalExpense;
    } else {
      // 月/周模式：从记录计算
      income = records
          .where((r) => r.isIncome)
          .fold<double>(0, (sum, r) => sum + r.incomeValue);
      expense = records
          .where((r) => r.isExpense)
          .fold<double>(0, (sum, r) => sum + r.expenseValue);
    }

    // 加载对比数据
    final comparison = await _previousBalanceAsync(recordProvider, bookId);

    // 加载活动数据
    final activity = await _periodActivityAsync(recordProvider, bookId);

    // 加载日趋势数据（需要 context，稍后在 build 中处理）
    final dailyEntries = <ChartEntry>[];

    // 加载上一周支出（如果是周模式）
    double? prevWeekExpense;
    if (_isWeekMode) {
      final prevStart = DateUtilsX.startOfWeek(range.start)
          .subtract(const Duration(days: 7));
      final prevEnd = prevStart.add(const Duration(days: 6));
      prevWeekExpense = await recordProvider.periodExpense(
        bookId: bookId,
        start: prevStart,
        end: prevEnd,
      );
    }

    return {
      'records': records,
      'income': income,
      'expense': expense,
      'comparison': comparison,
      'activity': activity,
      'dailyEntries': dailyEntries,
      'prevWeekExpense': prevWeekExpense ?? 0.0,
    };
  }

  /// 异步加载对比数据
  Future<_PeriodComparison> _previousBalanceAsync(
    RecordProvider recordProvider,
    String bookId,
  ) async {
    if (_isYearMode) {
      final prevRange = DateTimeRange(
        start: DateTime(widget.year - 1, 1, 1),
        end: DateTime(widget.year - 1, 12, 31),
      );
      final expense = await recordProvider.periodExpense(
        bookId: bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      final records = await recordProvider.recordsForPeriodAsync(
        bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      return _PeriodComparison(
        balance: expense,
        hasData: records.isNotEmpty,
      );
    }

    if (_isWeekMode) {
      final start = DateUtilsX.startOfWeek(_periodRange().start)
          .subtract(const Duration(days: 7));
      final prevRange = DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
      final expense = await recordProvider.periodExpense(
        bookId: bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      final records = await recordProvider.recordsForPeriodAsync(
        bookId,
        start: prevRange.start,
        end: prevRange.end,
      );
      return _PeriodComparison(
        balance: expense,
        hasData: records.isNotEmpty,
      );
    }

    final currentMonth = DateTime(widget.year, widget.month ?? DateTime.now().month, 1);
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final monthStats = await recordProvider.getMonthStatsAsync(prevMonth, bookId);
    final monthRecords = await recordProvider.recordsForMonthAsync(
      bookId,
      prevMonth.year,
      prevMonth.month,
    );
    return _PeriodComparison(
      balance: monthStats.expense,
      hasData: monthRecords.isNotEmpty,
    );
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

          name: CategoryNameHelper.unknownCategoryName, // 如果找不到分类，使用中文默认名称

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



  /// 异步构建日趋势数据
  Future<List<ChartEntry>> _buildDailyEntriesAsync(
    RecordProvider recordProvider,
    String bookId,
  ) async {
    final cs = Theme.of(context).colorScheme;
    
    if (_isYearMode) {
      // 年模式：构建12个月的月趋势数据
      final entries = <ChartEntry>[];
      for (var month = 1; month <= 12; month++) {
        final monthDate = DateTime(widget.year, month, 1);
        final monthStats = await recordProvider.getMonthStatsAsync(monthDate, bookId);
        // 确保支出值不为负数
        final expense = max(0.0, monthStats.expense);
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

    // 日趋势的横轴应该覆盖完整周期
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

    // 异步加载每天的支出统计
    final entries = <ChartEntry>[];
    for (final d in days) {
      final dayStats = await recordProvider.getDayStatsAsync(bookId, d);
      // 确保支出值不为负数
      final expense = max(0.0, dayStats.expense);
      entries.add(
        ChartEntry(
          label: _isWeekMode ? '${d.month}/${d.day}' : d.day.toString(),
          value: expense,
          color: cs.primary,
        ),
      );
    }

    return entries;
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



    // 根据实际的数据长度计算periodCount，而不是硬编码
    final periodCount = dailyEntries.length;
    
    // 如果数据为空，使用默认值
    final effectivePeriodCount = periodCount > 0 ? periodCount : 
        (_isYearMode ? 12 : (_isWeekMode ? 7 : (_isMonthMode ? 
            (widget.month != null ? DateTime(widget.year, widget.month! + 1, 0).day : 30) : 30)));

    final avgExpense = effectivePeriodCount > 0 ? totalExpense / effectivePeriodCount : 0.0;

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
                    ? (maxIndex != null ? DateTime(widget.year, maxIndex + 1, 1) : null)
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
      return CategoryRepository.sanitizeCategoryName(
        defaultCategory.key,
        defaultCategory.name,
      );
    } catch (e) {
      return null;
    }

  }



  /// 将常见的英文分类 key 映射到中文名称

  String _mapEnglishKeyToChinese(String key) {
    return CategoryNameHelper.mapEnglishKeyToChinese(key);
  }



  /// 异步加载活动数据
  Future<_PeriodActivity> _periodActivityAsync(
    RecordProvider recordProvider,
    String bookId,
  ) async {
    final range = _periodRange();
    final records = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: range.start,
      end: range.end,
    );

    final activeDays = <String>{};
    for (final record in records) {
      activeDays.add(DateUtilsX.ymd(record.date));
    }

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

          color: cs.surface,

          borderRadius: BorderRadius.circular(12),

          boxShadow: isDark

              ? null

              : [

                  BoxShadow(

                    color: cs.shadow.withOpacity(0.08),

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

                      style: Theme.of(context).textTheme.titleMedium?.copyWith(

                        fontWeight: FontWeight.w600,

                        color: cs.onSurface.withOpacity(0.85),

                        letterSpacing: 0.1,

                      ),

                    ),

                    const SizedBox(height: 6),

                    Text(

                      AppStrings.currentBookLabel(bookName),

                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(

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

                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(

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

                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(

                        fontWeight: FontWeight.w500,

                        color: Theme.of(context).colorScheme.onSurface,

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

}



class _SectionCard extends StatelessWidget {

  const _SectionCard({

    required this.title,

    required this.child,

  });



  final String title;

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

              color: cs.shadow.withOpacity(0.08),

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

                  style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w600,

                    color: cs.onSurface.withOpacity(0.9),

                    letterSpacing: 0.2,

                  ),

                ),

              ],

            ),

            const SizedBox(height: 18),

            DefaultTextStyle(
              style: (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
                color: cs.onSurface.withOpacity(0.85),
                height: 1.5,
              ),
              child: child,
            ),

          ],

        ),

      ),

    );

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

          Text(
            AppStrings.emptyPeriodRecords,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
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

          style: Theme.of(context).textTheme.bodySmall?.copyWith(

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

            color: Theme.of(context).colorScheme.onSurface,

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

            style: Theme.of(context).textTheme.bodyLarge?.copyWith(

              color: cs.onSurface.withOpacity(0.7),

              fontWeight: FontWeight.w400,

            ),

          ),

        ),

        Text(

          value,

          style: Theme.of(context).textTheme.titleMedium?.copyWith(

            fontWeight: FontWeight.w700,

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

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(

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

            style: Theme.of(context).textTheme.bodyLarge?.copyWith(

              fontWeight: FontWeight.w500,

              color: cs.onSurface.withOpacity(0.9),

            ),

          ),

        ),

        // 金额

        Text(

          _formatAmount(entry.value),

          style: Theme.of(context).textTheme.bodyLarge?.copyWith(

            fontWeight: FontWeight.w600,

            color: Theme.of(context).colorScheme.onSurface,

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

          style: Theme.of(context).textTheme.bodySmall?.copyWith(

            color: cs.onSurface.withOpacity(0.6),

            fontWeight: FontWeight.w500,

          ),

        ),

        const SizedBox(height: 4),

        Text(

          _formatAmount(value),

          style: Theme.of(context).textTheme.bodyLarge?.copyWith(

            color: Theme.of(context).colorScheme.onSurface,

            fontWeight: FontWeight.w600,

          ),

        ),

        if (date != null) ...[

          const SizedBox(height: 2),

          Text(

            isYearMode ? '${date!.month}月' : '${date!.month}月${date!.day}日',

            style: Theme.of(context).textTheme.bodySmall?.copyWith(

              color: cs.onSurface.withOpacity(0.5),

            ),

          ),

        ],

      ],

    );

  }

}



