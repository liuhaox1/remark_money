import 'package:flutter/material.dart';

import '../services/records_export_service.dart';
import '../utils/date_utils.dart';
import '../utils/validators.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/ymd_date_picker_sheet.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({
    super.key,
    required this.bookId,
    required this.initialRange,
    required this.format,
  });

  final String bookId;
  final DateTimeRange initialRange;
  final RecordsExportFormat format;

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(
      widget.initialRange.start.year,
      widget.initialRange.start.month,
      widget.initialRange.start.day,
    );
    final end = widget.initialRange.end;
    _endDate = DateTime(end.year, end.month, end.day);
  }

  DateTimeRange get _exportRange {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
      999,
    );
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final minDate = DateTime(
      (now.year - 20).clamp(Validators.minDate.year, Validators.maxDate.year),
      1,
      1,
    );
    final maxDate = DateTime(
      (now.year + 5).clamp(Validators.minDate.year, Validators.maxDate.year),
      12,
      31,
    );
    final picked = await showYmdDatePickerSheet(
      context,
      initialDate: _startDate,
      minDate: minDate,
      maxDate: maxDate,
      title: '选择开始日期',
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(
      (now.year + 5).clamp(Validators.minDate.year, Validators.maxDate.year),
      12,
      31,
    );
    final picked = await showYmdDatePickerSheet(
      context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      minDate: _startDate,
      maxDate: maxDate,
      title: '选择结束日期',
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _export() async {
    await RecordsExportService.exportRecords(
      context,
      bookId: widget.bookId,
      range: _exportRange,
      format: widget.format,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: '导出数据'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('开始时间'),
                    trailing: Text(
                      DateUtilsX.ymd(_startDate),
                      style: tt.bodyMedium?.copyWith(color: cs.outline),
                    ),
                    onTap: _pickStartDate,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('结束时间'),
                    trailing: Text(
                      DateUtilsX.ymd(_endDate),
                      style: tt.bodyMedium?.copyWith(color: cs.outline),
                    ),
                    onTap: _pickEndDate,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _export,
                child: const Text('导出'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
