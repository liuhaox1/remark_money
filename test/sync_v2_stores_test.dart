import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/services/sync_v2_conflict_store.dart';
import 'package:remark_money/services/sync_v2_cursor_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SyncV2CursorStore persists lastChangeId per book', () async {
    expect(await SyncV2CursorStore.getLastChangeId('b1'), 0);
    await SyncV2CursorStore.setLastChangeId('b1', 123);
    await SyncV2CursorStore.setLastChangeId('b2', 9);
    expect(await SyncV2CursorStore.getLastChangeId('b1'), 123);
    expect(await SyncV2CursorStore.getLastChangeId('b2'), 9);
  });

  test('SyncV2ConflictStore add/list/remove/clear', () async {
    const bookId = 'b1';
    await SyncV2ConflictStore.clear(bookId);
    expect(await SyncV2ConflictStore.count(bookId), 0);

    await SyncV2ConflictStore.addConflict(bookId, {
      'opId': 'op1',
      'serverId': 1,
      'serverVersion': 2,
    });
    await SyncV2ConflictStore.addConflict(bookId, {
      'opId': 'op2',
      'serverId': 2,
      'serverVersion': 3,
    });

    expect(await SyncV2ConflictStore.count(bookId), 2);
    final list = await SyncV2ConflictStore.list(bookId);
    expect(list.length, 2);
    expect(list.first['opId'], 'op2'); // latest-first

    await SyncV2ConflictStore.remove(bookId, opId: 'op2');
    expect(await SyncV2ConflictStore.count(bookId), 1);

    await SyncV2ConflictStore.clear(bookId);
    expect(await SyncV2ConflictStore.count(bookId), 0);
  });
}

