import 'package:flutter_test/flutter_test.dart';
import 'package:remark_money/models/savings_plan.dart';
import 'package:remark_money/utils/savings_plan_schedule.dart';

void main() {
  test('computeDuePeriods monthlyFixed clamps to last day of month', () {
    final plan = SavingsPlan(
      id: 'p',
      bookId: 'default-book',
      accountId: 'acc',
      name: 'plan',
      type: SavingsPlanType.monthlyFixed,
      targetAmount: 0,
      includeInStats: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      startDate: DateTime(2026, 1, 1),
      monthlyDay: 31,
      monthlyAmount: 10,
    );

    final periods = computeDuePeriods(plan, now: DateTime(2026, 3, 1));
    // Jan 31 + Feb 28 (clamped)
    expect(periods.length, 2);
    expect(periods[0].dueDate, DateTime(2026, 1, 31));
    expect(periods[1].dueDate, DateTime(2026, 2, 28));
    expect(periods[0].key, 'm_202601');
    expect(periods[1].key, 'm_202602');
  });

  test('computeDuePeriods weeklyFixed generates weekly dates on weekday', () {
    final plan = SavingsPlan(
      id: 'p',
      bookId: 'default-book',
      accountId: 'acc',
      name: 'plan',
      type: SavingsPlanType.weeklyFixed,
      targetAmount: 0,
      includeInStats: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      startDate: DateTime(2026, 1, 1), // Thu
      weeklyWeekday: 5, // Fri
      weeklyAmount: 10,
    );

    final periods = computeDuePeriods(plan, now: DateTime(2026, 1, 10));
    // Fri 1/2 and Fri 1/9
    expect(periods.map((p) => p.dueDate).toList(), [DateTime(2026, 1, 2), DateTime(2026, 1, 9)]);
    expect(periods[0].key, 'w_20251229'); // week starts Monday 2025-12-29
    expect(periods[1].key, 'w_20260105'); // week starts Monday 2026-01-05
  });
}
