import 'dart:convert';

import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../utils/csv_utils.dart';
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
/// Names for category / book / account are looked up by id and fallback to
/// [`AppStrings.unknown`] when missing.
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
    final categoryName =
        categoriesByKey[r.categoryKey]?.name ?? AppStrings.unknown;
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
