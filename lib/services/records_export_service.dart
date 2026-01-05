import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/category_name_helper.dart';
import '../utils/date_utils.dart';
import '../utils/error_handler.dart';

enum RecordsExportFormat { csv, excel, pdf }

extension RecordsExportFormatX on RecordsExportFormat {
  String get label => switch (this) {
        RecordsExportFormat.csv => 'CSV',
        RecordsExportFormat.excel => 'Excel',
        RecordsExportFormat.pdf => 'PDF',
      };

  String get extension => switch (this) {
        RecordsExportFormat.csv => 'csv',
        RecordsExportFormat.excel => 'xlsx',
        RecordsExportFormat.pdf => 'pdf',
      };
}

class RecordsExportService {
  /// Generate an export file in the temporary directory without invoking any platform UI
  /// (FilePicker/Share) and without showing toasts/snackbars.
  ///
  /// Intended for automated tests and non-interactive flows.
  static Future<File> generateTempExportFile(
    BuildContext context, {
    required String bookId,
    required DateTimeRange range,
    required RecordsExportFormat format,
  }) async {
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    final records = await recordProvider.recordsForPeriodAsync(
      bookId,
      start: range.start,
      end: range.end,
    );
    final exportRecords = records.where((r) => r.includeInStats).toList();
    if (exportRecords.isEmpty) {
      throw StateError('No records in range');
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

    Book? book;
    for (final b in bookProvider.books) {
      if (b.id == bookId) {
        book = b;
        break;
      }
    }
    book ??= bookProvider.activeBook;
    final bookName = book?.name ?? AppStrings.defaultBook;
    final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final startStr = DateUtilsX.ymd(range.start).replaceAll('/', '-');
    final endStr = DateUtilsX.ymd(range.end).replaceAll('/', '-');
    final fileName = '${safeBookName}_${startStr}_$endStr.${format.extension}';

    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$fileName');

    switch (format) {
      case RecordsExportFormat.csv:
        final csv = _buildCsvText(
          exportRecords,
          categoriesByKey: categoryMap,
          booksById: bookMap,
          accountsById: accountMap,
        );
        await tempFile.writeAsString(csv, encoding: utf8);
        break;
      case RecordsExportFormat.excel:
        final bytes = _buildExcelBytes(
          exportRecords,
          categoriesByKey: categoryMap,
          booksById: bookMap,
          accountsById: accountMap,
        );
        await tempFile.writeAsBytes(bytes, flush: true);
        break;
      case RecordsExportFormat.pdf:
        final bytes = await _buildPdfBytesSafe(
          exportRecords,
          bookName: bookName,
          range: range,
          categoriesByKey: categoryMap,
          booksById: bookMap,
          accountsById: accountMap,
        );
        await tempFile.writeAsBytes(bytes, flush: true);
        break;
    }

    return tempFile;
  }

  static Future<void> exportRecords(
    BuildContext context, {
    required String bookId,
    required DateTimeRange range,
    required RecordsExportFormat format,
  }) async {
    try {
      if (context.mounted) {
        ErrorHandler.showInfo(context, '正在导出...');
      }

      final recordProvider = context.read<RecordProvider>();
      final bookProvider = context.read<BookProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final accountProvider = context.read<AccountProvider>();

      final records = await recordProvider.recordsForPeriodAsync(
        bookId,
        start: range.start,
        end: range.end,
      );
      final exportRecords = records.where((r) => r.includeInStats).toList();
      if (exportRecords.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showWarning(context, '当前时间范围内暂无记录');
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

      Book? book;
      for (final b in bookProvider.books) {
        if (b.id == bookId) {
          book = b;
          break;
        }
      }
      book ??= bookProvider.activeBook;
      final bookName = book?.name ?? AppStrings.defaultBook;
      final safeBookName = bookName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final startStr = DateUtilsX.ymd(range.start).replaceAll('/', '-');
      final endStr = DateUtilsX.ymd(range.end).replaceAll('/', '-');
      final fileName = '${safeBookName}_${startStr}_$endStr.${format.extension}';

      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/$fileName');

      switch (format) {
        case RecordsExportFormat.csv:
          final csv = _buildCsvText(
            exportRecords,
            categoriesByKey: categoryMap,
            booksById: bookMap,
            accountsById: accountMap,
          );
          await tempFile.writeAsString(csv, encoding: utf8);
          break;
        case RecordsExportFormat.excel:
          final bytes = _buildExcelBytes(
            exportRecords,
            categoriesByKey: categoryMap,
            booksById: bookMap,
            accountsById: accountMap,
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          break;
      case RecordsExportFormat.pdf:
          final bytes = await _buildPdfBytesSafe(
            exportRecords,
            bookName: bookName,
            range: range,
            categoriesByKey: categoryMap,
            booksById: bookMap,
            accountsById: accountMap,
          );
          await tempFile.writeAsBytes(bytes, flush: true);
          break;
      }

      if (!context.mounted) return;

      if (Platform.isWindows) {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存 ${format.label} 文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [format.extension],
        );
        if (savedPath == null) return;

        await tempFile.copy(savedPath);
        if (!context.mounted) return;
        ErrorHandler.showSuccess(context, '已导出：${File(savedPath).path}');
        return;
      }

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '指尖记账导出 ${format.label}',
        text: '指尖记账导出记录（${format.label}）。',
      );

      if (context.mounted) {
        ErrorHandler.showSuccess(
          context,
          '导出成功！共 ${exportRecords.length} 条记录',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  static List<List<String>> _buildRows(
    List<Record> records, {
    required Map<String, Category> categoriesByKey,
    required Map<String, Book> booksById,
    required Map<String, Account> accountsById,
  }) {
    final rows = <List<String>>[
      [
        '日期',
        '金额',
        '收支方向',
        '分类',
        '账本',
        '账户',
        '备注',
        '是否计入统计',
      ],
    ];

    for (final r in records) {
      final dateStr = _formatDate(r.date);
      final amountStr = r.amount.toStringAsFixed(2);
      final directionStr = r.isIncome ? AppStrings.income : AppStrings.expense;
      final categoryName = CategoryNameHelper.getSafeDisplayName(
        categoriesByKey[r.categoryKey]?.name,
      );
      final bookName = booksById[r.bookId]?.name ?? AppStrings.defaultBook;
      final accountName = accountsById[r.accountId]?.name ?? AppStrings.unknown;
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

    return rows;
  }

  static String _buildCsvText(
    List<Record> records, {
    required Map<String, Category> categoriesByKey,
    required Map<String, Book> booksById,
    required Map<String, Account> accountsById,
  }) {
    // 复用现有 CSV 导出格式，避免引入不一致。
    final rows = _buildRows(
      records,
      categoriesByKey: categoriesByKey,
      booksById: booksById,
      accountsById: accountsById,
    );

    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  static String _escapeCsvField(String value) {
    if (value.contains('"') || value.contains(',') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static Uint8List _buildExcelBytes(
    List<Record> records, {
    required Map<String, Category> categoriesByKey,
    required Map<String, Book> booksById,
    required Map<String, Account> accountsById,
  }) {
    final rows = _buildRows(
      records,
      categoriesByKey: categoriesByKey,
      booksById: booksById,
      accountsById: accountsById,
    );

    final excel = Excel.createExcel();
    final sheet = excel['记录'];
    for (final row in rows) {
      sheet.appendRow(row.map((v) => TextCellValue(v)).toList(growable: false));
    }
    excel.setDefaultSheet('记录');
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Excel encode failed');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> _buildPdfBytes(
    List<Record> records, {
    required String bookName,
    required DateTimeRange range,
    required Map<String, Category> categoriesByKey,
    required Map<String, Book> booksById,
    required Map<String, Account> accountsById,
  }) async {
    final rows = _buildRows(
      records,
      categoriesByKey: categoriesByKey,
      booksById: booksById,
      accountsById: accountsById,
    );
    final headers = rows.first;
    final data = rows.skip(1).toList(growable: false);

    final doc = pw.Document();

    // 使用在线字体以支持中文；若网络不可用会抛错，由上层统一提示。
    final base = await PdfGoogleFonts.notoSansSCRegular();
    final bold = await PdfGoogleFonts.notoSansSCBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        build: (ctx) => [
          pw.Text(
            '导出数据',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('账本：$bookName'),
          pw.Text(
            '时间范围：${DateUtilsX.ymd(range.start)} 至 ${DateUtilsX.ymd(range.end)}',
          ),
          pw.Text('记录数量：${records.length} 条'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.8),
              7: const pw.FlexColumnWidth(0.8),
            },
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> _buildPdfBytesSafe(
    List<Record> records, {
    required String bookName,
    required DateTimeRange range,
    required Map<String, Category> categoriesByKey,
    required Map<String, Book> booksById,
    required Map<String, Account> accountsById,
  }) async {
    try {
      return await _buildPdfBytes(
        records,
        bookName: bookName,
        range: range,
        categoriesByKey: categoriesByKey,
        booksById: booksById,
        accountsById: accountsById,
      );
    } catch (_) {
      // Fallback: build without downloading fonts (works offline; glyph coverage depends on platform).
      // To avoid unreadable PDFs when the platform font lacks CJK glyphs, use ASCII headers and ids/keys.
      final headers = <String>[
        'Date',
        'Amount',
        'Direction',
        'CategoryKey',
        'BookId',
        'AccountId',
        'Remark',
        'InStats',
      ];
      final data = records.map((r) {
        final directionStr = r.isIncome ? 'income' : 'expense';
        final includeStr = r.includeInStats ? 'Y' : 'N';
        return <String>[
          _formatDate(r.date),
          r.amount.toStringAsFixed(2),
          directionStr,
          r.categoryKey,
          r.bookId,
          r.accountId,
          r.remark,
          includeStr,
        ];
      }).toList(growable: false);
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData(),
          build: (ctx) => [
            pw.Text(
              'Export Data',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Book: $bookName'),
            pw.Text(
              'Range: ${DateUtilsX.ymd(range.start)} ~ ${DateUtilsX.ymd(range.end)}',
            ),
            pw.Text('Count: ${records.length}'),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(1.0),
                5: const pw.FlexColumnWidth(1.0),
                6: const pw.FlexColumnWidth(1.8),
                7: const pw.FlexColumnWidth(0.8),
              },
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      return Uint8List.fromList(bytes);
    }
  }
}
