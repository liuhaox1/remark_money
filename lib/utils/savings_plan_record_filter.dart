import 'package:flutter/foundation.dart';

import '../models/record.dart';

@visibleForTesting
List<Record> filterSavingsPlanRecordsForDisplay({
  required String planId,
  required String planAccountId,
  required Iterable<Record> records,
}) {
  final prefix = 'sp_${planId}_';
  return records
      // A savings-plan deposit is recorded as a transfer (out + in).
      // Only show the "in" leg into the plan account to avoid double rows.
      .where((r) =>
          (r.pairId ?? '').startsWith(prefix) &&
          r.accountId == planAccountId &&
          r.direction == TransactionDirection.income)
      .toList(growable: false);
}

