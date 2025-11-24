import 'dart:convert';

import '../models/record.dart';

class RecordsExportBundle {
  RecordsExportBundle({
    required this.version,
    required this.exportedAt,
    required this.type,
    required this.bookId,
    required this.start,
    required this.end,
    required this.records,
  });

  final int version;
  final DateTime exportedAt;
  final String type;
  final String bookId;
  final DateTime start;
  final DateTime end;
  final List<Record> records;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'type': type,
      'bookId': bookId,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'records': records.map((r) => r.toMap()).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory RecordsExportBundle.fromMap(Map<String, dynamic> map) {
    final records = (map['records'] as List<dynamic>? ?? [])
        .map((e) => Record.fromMap(e as Map<String, dynamic>))
        .toList();

    return RecordsExportBundle(
      version: map['version'] as int? ?? 1,
      exportedAt: DateTime.tryParse(map['exportedAt'] as String? ?? '') ??
          DateTime.now(),
      type: map['type'] as String? ?? 'records',
      bookId: map['bookId'] as String? ?? 'default-book',
      start: DateTime.parse(map['start'] as String),
      end: DateTime.parse(map['end'] as String),
      records: records,
    );
  }

  factory RecordsExportBundle.fromJson(String source) =>
      RecordsExportBundle.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

