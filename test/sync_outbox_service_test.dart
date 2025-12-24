import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/models/record.dart';
import 'package:remark_money/repository/repository_factory.dart';
import 'package:remark_money/services/sync_outbox_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'use_shared_preferences': true,
    });
    await RepositoryFactory.initialize();
  });

  test('enqueueUpsert writes v2 payload with expectedVersion', () async {
    final outbox = SyncOutboxService.instance;
    final record = Record(
      id: 'local_1',
      serverId: null,
      serverVersion: 7,
      amount: 12.34,
      remark: 'hi',
      date: DateTime.parse('2025-01-01T00:00:00Z'),
      categoryKey: 'food',
      bookId: 'book_1',
      accountId: 'acc_1',
      direction: TransactionDirection.out,
      includeInStats: true,
    );

    await outbox.enqueueUpsert(record);
    final pending = await outbox.loadPending('book_1');
    expect(pending.length, 1);

    final payload = pending.first.payload;
    expect(payload['type'], 'upsert');
    expect(payload['opId'], isNotEmpty);
    expect(payload['expectedVersion'], 7);

    final bill = payload['bill'] as Map;
    expect(bill['localId'], 'local_1');
    expect(bill['bookId'], 'book_1');
  });

  test('runSuppressed prevents enqueue', () async {
    final outbox = SyncOutboxService.instance;
    final record = Record(
      id: 'local_2',
      serverId: null,
      serverVersion: 1,
      amount: 1,
      remark: 'x',
      date: DateTime.parse('2025-01-01T00:00:00Z'),
      categoryKey: 'food',
      bookId: 'book_2',
      accountId: 'acc_1',
      direction: TransactionDirection.out,
    );

    await outbox.runSuppressed(() => outbox.enqueueUpsert(record));
    final pending = await outbox.loadPending('book_2');
    expect(pending, isEmpty);
  });

  test('enqueueDelete ignores unsynced record, enqueues synced record', () async {
    final outbox = SyncOutboxService.instance;
    final unsynced = Record(
      id: 'local_3',
      serverId: null,
      serverVersion: null,
      amount: 1,
      remark: 'x',
      date: DateTime.parse('2025-01-01T00:00:00Z'),
      categoryKey: 'food',
      bookId: 'book_3',
      accountId: 'acc_1',
      direction: TransactionDirection.out,
    );

    await outbox.enqueueDelete(unsynced);
    expect(await outbox.loadPending('book_3'), isEmpty);

    final synced = unsynced.copyWith(serverId: 99, serverVersion: 2);
    await outbox.enqueueDelete(synced);
    final pending = await outbox.loadPending('book_3');
    expect(pending.length, 1);
    expect(pending.first.payload['type'], 'delete');
    expect(pending.first.payload['serverId'], 99);
    expect(pending.first.payload['expectedVersion'], 2);
  });

  test('enqueueDelete removes pending upsert for unsynced record', () async {
    final outbox = SyncOutboxService.instance;
    final record = Record(
      id: 'local_4',
      serverId: null,
      serverVersion: null,
      amount: 1,
      remark: 'x',
      date: DateTime.parse('2025-01-01T00:00:00Z'),
      categoryKey: 'food',
      bookId: 'book_4',
      accountId: 'acc_1',
      direction: TransactionDirection.out,
    );

    await outbox.enqueueUpsert(record);
    expect((await outbox.loadPending('book_4')).length, 1);

    await outbox.enqueueDelete(record);
    expect(await outbox.loadPending('book_4'), isEmpty);
  });

  test('enqueueDelete collapses existing upsert for synced record', () async {
    final outbox = SyncOutboxService.instance;
    final record = Record(
      id: 'server_101',
      serverId: 101,
      serverVersion: 7,
      amount: 1,
      remark: 'x',
      date: DateTime.parse('2025-01-01T00:00:00Z'),
      categoryKey: 'food',
      bookId: 'book_5',
      accountId: 'acc_1',
      direction: TransactionDirection.out,
    );

    await outbox.enqueueUpsert(record);
    expect((await outbox.loadPending('book_5')).length, 1);

    await outbox.enqueueDelete(record);
    final pending = await outbox.loadPending('book_5');
    expect(pending.length, 1);
    expect(pending.single.payload['type'], 'delete');
    expect(pending.single.payload['serverId'], 101);
  });
}
