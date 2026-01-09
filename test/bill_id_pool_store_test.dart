import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/services/bill_id_pool_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('BillIdPoolStore take consumes sequential ids and persists cursor', () async {
    final store = BillIdPoolStore.instance;
    await store.setPool(bookId: 'b1', nextId: 10, endId: 12);

    final first = await store.take(bookId: 'b1', count: 2);
    expect(first, [10, 11]);

    final second = await store.take(bookId: 'b1', count: 2);
    expect(second, [12]);

    final third = await store.take(bookId: 'b1', count: 1);
    expect(third, isEmpty);
  });
}

