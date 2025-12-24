import 'package:flutter_test/flutter_test.dart';

import 'package:remark_money/services/sync_v2_pull_utils.dart';

void main() {
  test('computeNextCursor uses max of server and changeId', () {
    final next = SyncV2PullUtils.computeNextCursor(
      previousCursor: 10,
      nextChangeIdFromServer: 11,
      changes: const [
        {'changeId': 12},
        {'changeId': 11},
      ],
    );
    expect(next, 12);
  });

  test('computeNextCursor tolerates missing nextChangeId', () {
    final next = SyncV2PullUtils.computeNextCursor(
      previousCursor: 10,
      nextChangeIdFromServer: null,
      changes: const [
        {'changeId': '13'},
      ],
    );
    expect(next, 13);
  });

  test('computeNextCursor never goes backwards', () {
    final next = SyncV2PullUtils.computeNextCursor(
      previousCursor: 10,
      nextChangeIdFromServer: 9,
      changes: const [
        {'changeId': 8},
      ],
    );
    expect(next, 10);
  });
}

