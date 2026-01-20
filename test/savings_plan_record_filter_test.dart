import 'package:flutter_test/flutter_test.dart';
import 'package:remark_money/models/record.dart';
import 'package:remark_money/utils/savings_plan_record_filter.dart';

void main() {
  test('filterSavingsPlanRecordsForDisplay keeps only plan incoming leg', () {
    final planId = 'p1';
    final planAccountId = 'acc_plan';
    final pairId = 'sp_${planId}_123';

    final out = Record(
      id: 'r1',
      amount: 10,
      remark: 'save',
      date: DateTime(2026, 1, 1),
      categoryKey: 'saving-out',
      bookId: 'default-book',
      accountId: 'acc_from',
      direction: TransactionDirection.out,
      includeInStats: false,
      pairId: pairId,
      createdByUserId: 0,
      updatedByUserId: 0,
    );
    final incoming = Record(
      id: 'r2',
      amount: 10,
      remark: 'save',
      date: DateTime(2026, 1, 1),
      categoryKey: 'saving-in',
      bookId: 'default-book',
      accountId: planAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: pairId,
      createdByUserId: 0,
      updatedByUserId: 0,
    );
    final otherPlan = Record(
      id: 'r3',
      amount: 10,
      remark: 'save',
      date: DateTime(2026, 1, 1),
      categoryKey: 'saving-in',
      bookId: 'default-book',
      accountId: planAccountId,
      direction: TransactionDirection.income,
      includeInStats: false,
      pairId: 'sp_p2_123',
      createdByUserId: 0,
      updatedByUserId: 0,
    );

    final filtered = filterSavingsPlanRecordsForDisplay(
      planId: planId,
      planAccountId: planAccountId,
      records: [out, incoming, otherPlan],
    );

    expect(filtered, [incoming]);
  });
}

