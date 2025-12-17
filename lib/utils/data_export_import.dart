import 'dart:convert';

import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../utils/csv_utils.dart';
import '../utils/category_name_helper.dart';
import '../utils/records_export_bundle.dart';

String _formatDate(DateTime date) {
  final formatter = DateFormat('yyyy-MM-dd HH:mm');
  return formatter.format(date);
}

String _directionLabel(Record record) {
  return record.isIncome ? AppStrings.income : AppStrings.expense;
}

String _boolLabel(bool value) => value ? '是' : '否';

/// Build CSV text for given records.
///
/// Names for category / book / account are looked up by id.
/// Category name falls back to "未分类" when missing to avoid "未知" in exports.
String buildCsvForRecords(
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
    final directionStr = _directionLabel(r);
    final categoryName = CategoryNameHelper.getSafeDisplayName(
      categoriesByKey[r.categoryKey]?.name,
    );
    final bookName = booksById[r.bookId]?.name ?? AppStrings.defaultBook;
    final accountName = accountsById[r.accountId]?.name ?? AppStrings.unknown;
    final remark = r.remark;
    final includeStr = _boolLabel(r.includeInStats);

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

  return toCsv(rows);
}

/// Build a JSON package string for a block of records, used for export/import.
String buildJsonPackageForRecords({
  required List<Record> records,
  required String bookId,
  required DateTime start,
  required DateTime end,
}) {
  final bundle = RecordsExportBundle(
    version: 1,
    exportedAt: DateTime.now().toUtc(),
    type: 'records',
    bookId: bookId,
    start: start,
    end: end,
    records: records,
  );
  return bundle.toJson();
}

/// Parse and validate an import JSON package.
///
/// Throws [FormatException] when the content is invalid.
RecordsExportBundle parseRecordsJsonPackage(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid root JSON');
  }

  final version = decoded['version'];
  if (version is! int) {
    throw const FormatException('Invalid version');
  }
  final type = decoded['type'];
  if (type != 'records') {
    throw const FormatException('Invalid type');
  }
  final records = decoded['records'];
  if (records is! List) {
    throw const FormatException('Invalid records');
  }

  return RecordsExportBundle.fromMap(decoded);
}

/// Parse CSV text and convert to records.
///
/// CSV format: 日期,金额,收支方向,分类,账本,账户,备注,是否计入统计
/// Throws [FormatException] when the content is invalid.
List<Record> parseCsvToRecords(
  String csvText, {
  required Map<String, Category> categoriesByName,
  required Map<String, Book> booksByName,
  required Map<String, Account> accountsByName,
  required String defaultBookId,
  required String defaultAccountId,
  required String defaultCategoryKey,
}) {
  final lines = csvText.split('\n').where((line) => line.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    throw const FormatException('CSV文件为空');
  }

  // 跳过表头
  if (lines.length < 2) {
    throw const FormatException('CSV文件格式不正确：缺少数据行');
  }

  final records = <Record>[];
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    try {
      // 简单的CSV解析（处理引号和逗号）
      final fields = _parseCsvLine(line);
      if (fields.length < 8) {
        continue; // 跳过不完整的行
      }

      final dateStr = fields[0].trim();
      final amountStr = fields[1].trim();
      final directionStr = fields[2].trim();
      final categoryName = fields[3].trim();
      final bookName = fields[4].trim();
      final accountName = fields[5].trim();
      final remark = fields[6].trim();
      final includeStr = fields[7].trim();

      // 解析日期
      DateTime date;
      try {
        date = dateFormat.parse(dateStr);
      } catch (_) {
        // 尝试其他格式
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          continue; // 跳过无法解析的行
        }
      }

      // 解析金额
      final amount = double.tryParse(amountStr);
      if (amount == null || amount <= 0) {
        continue; // 跳过无效金额
      }

      // 解析收支方向
      final isIncome = directionStr == AppStrings.income || directionStr == '收入';
      final direction = isIncome ? TransactionDirection.income : TransactionDirection.out;

      // 查找分类
      String categoryKey = defaultCategoryKey;
      final category = categoriesByName[categoryName];
      if (category != null) {
        categoryKey = category.key;
      }

      // 查找账本
      String bookId = defaultBookId;
      final book = booksByName[bookName];
      if (book != null) {
        bookId = book.id;
      }

      // 查找账户
      String accountId = defaultAccountId;
      final account = accountsByName[accountName];
      if (account != null) {
        accountId = account.id;
      }

      // 解析是否计入统计
      final includeInStats = includeStr == '是' || includeStr == 'true' || includeStr == '1';

      // 创建记录
      final record = Record(
        id: _generateRecordId(),
        date: date,
        amount: amount,
        categoryKey: categoryKey,
        bookId: bookId,
        accountId: accountId,
        remark: remark,
        direction: direction,
        includeInStats: includeInStats,
      );

      records.add(record);
    } catch (e) {
      // 跳过无法解析的行
      continue;
    }
  }

  return records;
}

/// 简单的CSV行解析（处理引号和逗号）
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        // 转义的引号
        current.write('"');
        i++; // 跳过下一个引号
      } else {
        // 切换引号状态
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      // 字段分隔符
      fields.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  fields.add(current.toString()); // 最后一个字段

  return fields;
}

String _generateRecordId() {
  return DateTime.now().millisecondsSinceEpoch.toString() +
      '_' +
      (1000 + (9999 - 1000) * (DateTime.now().microsecond / 1000000)).round().toString();
}
