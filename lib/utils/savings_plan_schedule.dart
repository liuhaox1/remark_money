import 'package:flutter/foundation.dart';

import '../models/savings_plan.dart';

@immutable
class SavingsPlanDuePeriod {
  const SavingsPlanDuePeriod({
    required this.key,
    required this.dueDate,
    required this.amount,
  });

  /// Stable idempotency key per period (used in pairId).
  final String key;
  final DateTime dueDate;
  final double amount;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _monthlyDueDate(int year, int month, int day) {
  final last = _lastDayOfMonth(year, month);
  final dd = day.clamp(1, last);
  return DateTime(year, month, dd);
}

DateTime _weekStartMonday(DateTime d) =>
    _dateOnly(d).subtract(Duration(days: _dateOnly(d).weekday - 1));

String _yyyymm(int year, int month) =>
    '$year${month.toString().padLeft(2, '0')}';

String _yyyymmdd(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

@visibleForTesting
List<SavingsPlanDuePeriod> computeDuePeriods(
  SavingsPlan plan, {
  required DateTime now,
}) {
  final today = _dateOnly(now);
  final start = _dateOnly(plan.startDate ?? plan.createdAt);
  final until = plan.endDate == null
      ? today
      : (_dateOnly(plan.endDate!).isBefore(today) ? _dateOnly(plan.endDate!) : today);

  if (until.isBefore(start)) return const [];

  switch (plan.type) {
    case SavingsPlanType.monthlyFixed: {
      final day = plan.monthlyDay ?? 1;
      final amount = plan.monthlyAmount ?? 0;
      if (amount <= 0) return const [];

      final out = <SavingsPlanDuePeriod>[];
      var cursor = DateTime(start.year, start.month, 1);
      while (!cursor.isAfter(until)) {
        final due = _monthlyDueDate(cursor.year, cursor.month, day);
        if (!due.isBefore(start) && !due.isAfter(until)) {
          out.add(
            SavingsPlanDuePeriod(
              key: 'm_${_yyyymm(cursor.year, cursor.month)}',
              dueDate: due,
              amount: amount,
            ),
          );
        }
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
      return out;
    }
    case SavingsPlanType.weeklyFixed: {
      final weekday = plan.weeklyWeekday ?? DateTime.now().weekday;
      final amount = plan.weeklyAmount ?? 0;
      if (amount <= 0) return const [];

      // Find first due date on/after start.
      var first = start;
      while (first.weekday != weekday) {
        first = first.add(const Duration(days: 1));
      }

      final out = <SavingsPlanDuePeriod>[];
      var due = first;
      while (!due.isAfter(until)) {
        final wkStart = _weekStartMonday(due);
        out.add(
          SavingsPlanDuePeriod(
            key: 'w_${_yyyymmdd(wkStart)}',
            dueDate: due,
            amount: amount,
          ),
        );
        due = due.add(const Duration(days: 7));
      }
      return out;
    }
    case SavingsPlanType.flexible:
    case SavingsPlanType.countdown:
      return const [];
  }
}

