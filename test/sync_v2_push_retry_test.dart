import 'package:flutter_test/flutter_test.dart';

import 'package:remark_money/services/sync_v2_push_retry.dart';

void main() {
  test('bumpAttempt increments and stores error', () {
    final p1 = SyncV2PushRetry.bumpAttempt({}, error: 'e1');
    expect(SyncV2PushRetry.getAttempt(p1), 1);
    expect(p1['_lastError'], 'e1');
    expect(p1['_lastAttemptAtMs'], isA<int>());

    final p2 = SyncV2PushRetry.bumpAttempt(p1, error: 'e2');
    expect(SyncV2PushRetry.getAttempt(p2), 2);
    expect(p2['_lastError'], 'e2');
  });

  test('shouldQuarantine after maxAttempts', () {
    var p = <String, dynamic>{};
    for (var i = 0; i < SyncV2PushRetry.maxAttempts; i++) {
      p = SyncV2PushRetry.bumpAttempt(p, error: 'e');
    }
    expect(SyncV2PushRetry.getAttempt(p), SyncV2PushRetry.maxAttempts);
    expect(SyncV2PushRetry.shouldQuarantine(p), isTrue);
  });
}

