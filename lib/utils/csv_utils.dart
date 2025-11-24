String _escapeCsvField(String value) {
  final needsQuotes = value.contains(',') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value.contains('"');
  if (!needsQuotes) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

/// Convert rows of string values to CSV text.
String toCsv(List<List<String>> rows) {
  final buffer = StringBuffer();
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    buffer.writeln(row.map(_escapeCsvField).join(','));
  }
  return buffer.toString();
}

