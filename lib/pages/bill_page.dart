import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/providers/account_provider.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/utils/date_utils.dart';

import '../l10n/app_strings.dart';
import '../l10n/app_text_templates.dart';
import '../models/category.dart';
import '../models/period_type.dart';
import '../models/record.dart';
import '../theme/app_tokens.dart';
import '../utils/csv_utils.dart';
import '../utils/data_export_import.dart';
import '../utils/records_export_bundle.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/book_selector_button.dart';
import '../widgets/period_selector.dart';
import '../widgets/timeline_item.dart';
import 'add_record_page.dart';
import 'report_detail_page.dart';

class BillPage extends StatefulWidget {
  const BillPage({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialShowYearMode,
    this.initialRange,
    this.initialPeriodType,
  });

  final int? initialYear;
  final DateTime? initialMonth;
  final bool? initialShowYearMode;
  final DateTimeRange? initialRange;
  final PeriodType? initialPeriodType;

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late PeriodType _periodType;
  late int _selectedYear;
  late DateTime _selectedMonth;
  late DateTimeRange _selectedWeek;

  // 账单页筛选：按分类 + 收支方向
  String? _filterCategoryKey;
  bool? _filterIncomeExpense; // null: 全部, true: 只看收入, false: 只看支出

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodType = widget.initialPeriodType ??
        (widget.initialShowYearMode == true
            ? PeriodType.year
            : PeriodType.month);
    _selectedMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    _selectedYear = widget.initialYear ?? _selectedMonth.year;
    _selectedWeek = widget.initialRange ??
        DateUtilsX.weekRange(_selectedMonth);
    if (_periodType == PeriodType.week && widget.initialRange != null) {
      _selectedYear = widget.initialRange!.start.year;
      _selectedMonth = DateTime(
        widget.initialRange!.start.year,
        widget.initialRange!.start.month,
        1,
      );
    }
    if (_periodType == PeriodType.year && widget.initialYear != null) {
      _selectedYear = widget.initialYear!;
    }
  }

  void _pickYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, 1, 1),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickYear,
    );
    if (picked != null) {
      setState(() => _selectedYear = picked.year);
    }
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickMonth,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeek.start,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
      helpText: AppStrings.pickWeek,
    );
    if (picked != null) {
      setState(() {
        _selectedWeek = DateUtilsX.weekRange(picked);
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

  void _shiftPeriod(int delta) {
    setState(() {
      if (_periodType == PeriodType.year) {
        _selectedYear += delta;
        _selectedMonth = DateTime(_selectedYear, _selectedMonth.month, 1);
      } else if (_periodType == PeriodType.month) {
        _selectedMonth =
            DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
        _selectedYear = _selectedMonth.year;
      } else {
        final newStart =
            _selectedWeek.start.add(Duration(days: 7 * delta));
        _selectedWeek = DateUtilsX.weekRange(newStart);
        _selectedYear = _selectedWeek.start.year;
        _selectedMonth =
            DateTime(_selectedWeek.start.year, _selectedWeek.start.month, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;
    final bookName =
        bookProvider.activeBook?.name ?? AppStrings.defaultBook;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        actions: [
          const BookSelectorButton(compact: true),
          IconButton(
            tooltip: AppStrings.filter,
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _openFilterSheet,
          ),
          TextButton(
            onPressed: () => _openReportDetail(context, bookId),
            child: const Text(
              AppStrings.report,
              style: TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: '导出数据',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _showExportMenuV2(context, bookId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
            const SizedBox(height: 12),

          // -----------------------------------
          // 🔘 周 / 月 / 年 Segmented Button
          // -----------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<PeriodType>(
              segments: const [
                ButtonSegment(
                  value: PeriodType.week,
                  label: Text(AppStrings.weeklyBill),
                ),
                ButtonSegment(
                  value: PeriodType.month,
                  label: Text(AppStrings.monthlyBill),
                ),
                ButtonSegment(
                  value: PeriodType.year,
                  label: Text(AppStrings.yearlyBill),
                ),
              ],
              selected: {_periodType},
              onSelectionChanged: (s) => setState(() {
                _periodType = s.first;
                if (_periodType == PeriodType.week) {
                  _selectedWeek = DateUtilsX.weekRange(_selectedMonth);
                } else if (_periodType == PeriodType.year) {
                  _selectedYear = _selectedMonth.year;
                }
              }),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PeriodSelector(
              label: _periodLabel(),
              periodType: _periodType,
              onPrev: () => _shiftPeriod(-1),
              onNext: () => _shiftPeriod(1),
              onTap: _pickPeriod,
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前账本：$bookName',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.outline,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _periodType == PeriodType.year
                ? _buildYearBill(context, cs, bookId)
                : _periodType == PeriodType.month
                    ? _buildMonthBill2(context, cs, bookId)
                    : _buildWeekBill(context, cs, bookId),
          ),
        ],
      ),
    );
  }

  String _appBarTitle() {
    switch (_periodType) {
      case PeriodType.week:
        return AppStrings.weeklyBill;
      case PeriodType.month:
        return AppStrings.monthlyBill;
      case PeriodType.year:
        return AppStrings.yearlyBill;
    }
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
    
    // 统计全部记录数量
    final allRecords = recordProvider.recordsForBook(bookId);
    final allRecordCount = allRecords.length;
    
    final choice = await showModalBottomSheet<String>(
      context: context,
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
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '导出范围',
                  style: TextStyle(
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
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('导出 CSV（当前范围）'),
                  subtitle: Text('用 Excel 打开查看和分析数据（$recordCount 条）'),
                  onTap: () => Navigator.pop(ctx, 'csv'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('导出 CSV（全部记录）'),
                  subtitle: Text('导出当前账本的所有历史记录（$allRecordCount 条）'),
                  onTap: () => Navigator.pop(ctx, 'csv_all'),
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
    } else if (choice == 'csv_all') {
      await _exportAllCsv(context, bookId);
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
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
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

  Future<void> _showExportMenu(BuildContext context, String bookId) async {
    final range = _currentRange();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('导出 CSV（用于 Excel 查看）'),
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('导出 JSON（用于备份 / 迁移）'),
                onTap: () => Navigator.pop(ctx, 'json'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'csv') {
      await _exportCsv(context, bookId, range);
    } else if (choice == 'json') {
      await _exportJson(context, bookId, range);
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    String bookId,
    DateTimeRange range,
  ) async {
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
              Text('正在导出...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前时间范围内暂无记录')),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导出成功！共 ${records.length} 条记录'),
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
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '指尖记账导出 CSV',
        text: '指尖记账导出记录 CSV，可用 Excel 打开查看。',
      );
    }
  }

  Future<void> _exportJson(
    BuildContext context,
    String bookId,
    DateTimeRange range,
  ) async {
    final recordProvider = context.read<RecordProvider>();

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
              Text('正在导出...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final records = recordProvider.recordsForPeriod(
      bookId,
      start: range.start,
      end: range.end,
    );
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前时间范围内暂无记录')),
        );
      }
      return;
    }

    final bundle = RecordsExportBundle(
      version: 1,
      exportedAt: DateTime.now().toUtc(),
      type: 'records',
      bookId: bookId,
      start: range.start,
      end: range.end,
      records: records,
    );

    final dir = await getTemporaryDirectory();
    final bookProvider = context.read<BookProvider>();
    final bookName = bookProvider.activeBook?.name ?? '默认账本';
    // Windows 文件名不允许包含特殊字符，使用简洁的日期格式
    final startStr = '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final endStr = '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
    // 文件名包含账本名称，更友好
    final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final fileName = '${safeBookName}_${startStr}_$endStr.json';
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(bundle.toJson(), encoding: utf8);

    if (!context.mounted) return;

    // Windows 平台使用文件保存对话框，其他平台使用共享
    if (Platform.isWindows) {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 JSON 备份文件',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
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
                  Text('导出成功！共 ${records.length} 条记录'),
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
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '指尖记账导出 JSON 备份',
        text: '指尖记账记录 JSON 备份，可用于导入或迁移。',
      );
    }
  }

  // 导出全部记录（CSV）
  Future<void> _exportAllCsv(
    BuildContext context,
    String bookId,
  ) async {
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
              Text('正在导出全部记录...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    final records = recordProvider.recordsForBook(bookId);
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前账本暂无记录')),
        );
      }
      return;
    }

    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final bookMap = {
      for (final b in bookProvider.books) b.id: b,
    };
    final accountMap = {
      for (final a in accountProvider.accounts) a.id: a,
    };

    final csv = buildCsvForRecords(
      records,
      categoriesByKey: categoryMap,
      booksById: bookMap,
      accountsById: accountMap,
    );

    final dir = await getTemporaryDirectory();
    final bookName = bookProvider.activeBook?.name ?? '默认账本';
    final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = '${safeBookName}_全部记录_$dateStr.csv';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导出成功！共 ${records.length} 条记录'),
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
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '指尖记账导出 CSV',
        text: '指尖记账导出的全部记录 CSV，可在表格中查看分析。',
      );
    }
  }

  // ======================================================
  // 📘 年度账单（展示 12 个月收入/支出/结余）
  // ======================================================
  Widget _buildYearBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final months = DateUtilsX.monthsInYear(_selectedYear);

    double totalIncome = 0;
    double totalExpense = 0;

    final monthItems = <Widget>[];
    for (final m in months) {
      final income = recordProvider.monthIncome(m, bookId);
      final expense = recordProvider.monthExpense(m, bookId);
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
      ),
    );

    items.addAll(monthItems);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  Widget _buildWeekBill(BuildContext context, ColorScheme cs, String bookId) {
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final days =
        List.generate(7, (i) => _selectedWeek.start.add(Duration(days: i)));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    double totalIncome = 0;
    double totalExpense = 0;
    int emptyDays = 0;

    final items = <Widget>[];

    for (final d in days) {
      final dayDate = DateTime(d.year, d.month, d.day);
      final allRecords = recordProvider.recordsForDay(bookId, d);
      final records = _applyFilters(allRecords, categoryMap);

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
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  // ======================================================
  // 📕 月度账单（按天 + 明细，支持筛选）
  // ======================================================
  Widget _buildMonthBill2(
    BuildContext context,
    ColorScheme cs,
    String bookId,
  ) {
    final days = DateUtilsX.daysInMonth(_selectedMonth);
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };

    double totalIncome = 0;
    double totalExpense = 0;
    double maxDailyExpense = 0;
    int recordedDays = 0;

    final nonEmptyDays = <DateTime>[];

    for (final d in days) {
      final allRecords = recordProvider.recordsForDay(bookId, d);
      final records = _applyFilters(allRecords, categoryMap);

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
      ),
    );

    for (final d in nonEmptyDays) {
      final allRecords = recordProvider.recordsForDay(bookId, d);
      final records = _applyFilters(allRecords, categoryMap);

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
            onTap: () => _openEditRecord(r),
            onDelete: () => _confirmAndDeleteRecord(r),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  // ======================================================
  // 📕 月度账单（按天显示，旧实现，暂时保留）
  // ======================================================
  Widget _buildMonthBill(BuildContext context, ColorScheme cs, String bookId) {
    final days = DateUtilsX.daysInMonth(_selectedMonth);
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    double totalIncome = 0;
    double totalExpense = 0;
    double maxDailyExpense = 0;
    int recordedDays = 0;

    // 先统计整月概况，并记录哪些日期有记账
    final nonEmptyDays = <DateTime>[];
    for (final d in days) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);

      totalIncome += income;
      totalExpense += expense;

      if (income != 0 || expense != 0) {
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

    // 顶部本月小结
    final subtitleParts = <String>[];
    subtitleParts.add(
        '本月支出 ${totalExpense.toStringAsFixed(2)} 元 · 日均 ${avgExpense.toStringAsFixed(2)} 元');
    subtitleParts.add('记账 $recordedDays 天');
    if (emptyDays > 0) {
      subtitleParts.add(AppTextTemplates.monthEmptyDaysHint(emptyDays));
    }
    if (maxDailyExpense > 0) {
      subtitleParts
          .add('单日最高支出 ${maxDailyExpense.toStringAsFixed(2)} 元');
    }

    items.add(
      _billCard(
        title: AppStrings.monthListTitle,
        subtitle: subtitleParts.join(' · '),
        income: totalIncome,
        expense: totalExpense,
        balance: totalIncome - totalExpense,
        cs: cs,
      ),
    );

    // 只展示有记账的日期，并在每一天下方展示具体明细
    for (final d in nonEmptyDays) {
      final income = recordProvider.dayIncome(bookId, d);
      final expense = recordProvider.dayExpense(bookId, d);
      final balance = income - expense;
      final records = recordProvider.recordsForDay(bookId, d);

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
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
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
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.outlineVariant.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '本期收入 ${income.toStringAsFixed(2)} 元 · 支出 ${expense.toStringAsFixed(2)} 元 · 结余 ${balance.toStringAsFixed(2)} 元',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w500,
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

  Widget _line(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        )
      ],
    );
  }

  Future<void> _openFilterSheet() async {
    final categories = context.read<CategoryProvider>().categories;
    String? tempCategoryKey = _filterCategoryKey;
    bool? tempIncomeExpense = _filterIncomeExpense;
    final categorySearchCtrl = TextEditingController();
    final expandedTopCategories = <String>{};

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom + 16;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final cs = Theme.of(ctx).colorScheme;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
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
                      const SizedBox(height: 12),
                      const Text(
                        AppStrings.filterByCategory,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: categorySearchCtrl,
                        decoration: InputDecoration(
                          hintText: '搜索分类...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: categorySearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    categorySearchCtrl.clear();
                                    setModalState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final searchKeyword =
                              categorySearchCtrl.text.trim().toLowerCase();

                          final secondLevelCategories =
                              categories.where((c) {
                            if (searchKeyword.isEmpty) return true;
                            return c.name.toLowerCase().contains(searchKeyword);
                          }).toList();

                          final expenseTop = Category(
                            key: 'expense_root',
                            name: AppStrings.expenseCategory,
                            icon: Icons.trending_down,
                            isExpense: true,
                          );
                          final incomeTop = Category(
                            key: 'income_root',
                            name: AppStrings.incomeCategory,
                            icon: Icons.trending_up,
                            isExpense: false,
                          );

                          final expenseChildren = secondLevelCategories
                              .where((c) => c.isExpense)
                              .toList();
                          final incomeChildren = secondLevelCategories
                              .where((c) => !c.isExpense)
                              .toList();

                          List<Widget> buildGroup(
                            Category top,
                            List<Category> children,
                          ) {
                            if (children.isEmpty) return [];
                            final isExpanded =
                                expandedTopCategories.contains(top.key);
                            return [
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isExpanded) {
                                      expandedTopCategories.remove(top.key);
                                    } else {
                                      expandedTopCategories.add(top.key);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 18,
                                        color: cs.onSurface.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        top.icon,
                                        size: 16,
                                        color: cs.onSurface.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        top.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${children.length})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              cs.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: children.map((c) {
                                    final selected =
                                        tempCategoryKey == c.key;
                                    return _buildFilterChip(
                                      ctx,
                                      label: c.name,
                                      selected: selected,
                                      onSelected: () {
                                        setModalState(() {
                                          tempCategoryKey =
                                              selected ? null : c.key;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ];
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...buildGroup(expenseTop, expenseChildren),
                              ...buildGroup(incomeTop, incomeChildren),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        AppStrings.filterByType,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            ctx,
                            label: AppStrings.all,
                            selected: tempIncomeExpense == null,
                            onSelected: () {
                              setModalState(() => tempIncomeExpense = null);
                            },
                          ),
                          _buildFilterChip(
                            ctx,
                            label: AppStrings.income,
                            selected: tempIncomeExpense == true,
                            onSelected: () {
                              setModalState(() {
                                tempIncomeExpense =
                                    tempIncomeExpense == true ? null : true;
                              });
                            },
                          ),
                          _buildFilterChip(
                            ctx,
                            label: AppStrings.expense,
                            selected: tempIncomeExpense == false,
                            onSelected: () {
                              setModalState(() {
                                tempIncomeExpense =
                                    tempIncomeExpense == false ? null : false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempCategoryKey = null;
                                tempIncomeExpense = null;
                              });
                            },
                            child: const Text(AppStrings.reset),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop<Map<String, dynamic>>(ctx, {
                                'categoryKey': tempCategoryKey,
                                'incomeExpense': tempIncomeExpense,
                              });
                            },
                            child: const Text(AppStrings.confirm),
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

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _filterCategoryKey = result['categoryKey'] as String?;
        _filterIncomeExpense = result['incomeExpense'] as bool?;
      });
    }
  }

  Widget _buildFilterChip(
    BuildContext ctx, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final cs = Theme.of(ctx).colorScheme;

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

  // 应用筛选（账单页面暂时不需要复杂筛选，直接返回原列表）
  List<Record> _applyFilters(
    List<Record> records,
    Map<String, Category> categoryMap,
  ) {
    var filtered = records;

    // 按分类筛选
    if (_filterCategoryKey != null) {
      filtered = filtered.where((r) => r.categoryKey == _filterCategoryKey).toList();
    }

    // 按收支类型筛选
    if (_filterIncomeExpense != null) {
      if (_filterIncomeExpense == true) {
        // 只看收入
        filtered = filtered.where((r) => r.isIncome).toList();
      } else {
        // 只看支出
        filtered = filtered.where((r) => r.isExpense).toList();
      }
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

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();

    await recordProvider.deleteRecord(
      record.id,
      accountProvider: accountProvider,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除记录')),
    );
  }
}
