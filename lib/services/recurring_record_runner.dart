import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/recurring_record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/recurring_record_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';

class RecurringRecordRunner with WidgetsBindingObserver {
  RecurringRecordRunner._();

  static final RecurringRecordRunner instance = RecurringRecordRunner._();

  static const int _minIntervalMs = 10 * 1000;

  BuildContext? _context;
  bool _started = false;
  bool _running = false;
  int _lastRunMs = 0;
  int _lastPausedAtMs = 0;

  void start(BuildContext context) {
    if (_started) return;
    _started = true;
    _context = context;
    WidgetsBinding.instance.addObserver(this);

    // run once after startup
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      run(reason: 'app_start');
    });
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _context = null;
    _started = false;
    _running = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAtMs = DateTime.now().millisecondsSinceEpoch;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _lastPausedAtMs;
      _lastPausedAtMs = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final backgroundFor = pausedAt == 0 ? 0 : now - pausedAt;
      // Avoid frequent resumed triggers on desktop focus changes.
      if (backgroundFor >= 10 * 1000) {
        run(reason: 'app_resumed');
      }
    }
  }

  Future<void> run({String reason = 'unknown'}) async {
    final ctx = _context;
    if (ctx == null) return;
    if (_running) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRunMs < _minIntervalMs) return;

    _running = true;
    try {
      final bookId = ctx.read<BookProvider>().activeBookId;
      final recurringProvider = ctx.read<RecurringRecordProvider>();
      final recordProvider = ctx.read<RecordProvider>();
      final accountProvider = ctx.read<AccountProvider>();
      final tagProvider = ctx.read<TagProvider>();

      if (!recurringProvider.loaded) {
        await recurringProvider.load();
      }
      await tagProvider.loadForBook(bookId);

      final now = DateTime.now();
      final plans = recurringProvider.plans
          .where((p) => p.enabled)
          .where((p) => (p.bookId.isEmpty ? 'default-book' : p.bookId) == bookId)
          .toList()
        ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

      for (final plan in plans) {
        var next = _dateOnly(plan.nextDate);
        if (next.isAfter(_dateOnly(now))) continue;

        // Safety: avoid infinite loops due to bad data.
        var createdCount = 0;
        while (!next.isAfter(_dateOnly(now))) {
          createdCount++;
          if (createdCount > 366) break;

          final record = await recordProvider.addRecord(
            amount: plan.amount,
            remark: plan.remark,
            date: next,
            categoryKey: plan.categoryKey,
            bookId: bookId,
            accountId: plan.accountId,
            direction: plan.direction,
            includeInStats: plan.includeInStats,
            accountProvider: accountProvider,
          );
          if (plan.tagIds.isNotEmpty) {
            await tagProvider.setTagsForRecord(record.id, plan.tagIds);
          }

          next = _nextDate(next, plan);
        }

        final updated = plan.copyWith(
          nextDate: next,
          lastRunAt: DateTime.now(),
        );
        if (updated.nextDate != plan.nextDate || updated.lastRunAt != plan.lastRunAt) {
          await recurringProvider.upsert(updated);
        }
      }
    } finally {
      _lastRunMs = DateTime.now().millisecondsSinceEpoch;
      _running = false;
    }
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _nextDate(DateTime from, RecurringRecordPlan plan) {
    if (plan.periodType == RecurringPeriodType.weekly) {
      final weekday = plan.weekday ?? plan.startDate.weekday;
      var delta = (weekday - from.weekday) % 7;
      if (delta == 0) delta = 7;
      return from.add(Duration(days: delta));
    }
    final day = plan.monthDay ?? plan.startDate.day;
    return _addMonthsClampedByDay(from, 1, day);
  }

  static DateTime _addMonthsClampedByDay(DateTime from, int monthsToAdd, int dayOfMonth) {
    final year = from.year;
    final month0 = from.month - 1 + monthsToAdd;
    final targetYear = year + month0 ~/ 12;
    final targetMonth = month0 % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = dayOfMonth.clamp(1, lastDay);
    return DateTime(targetYear, targetMonth, day);
  }
}
