import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/services/account_delete_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('enqueue dedupes and merges serverId', () async {
    final queue = AccountDeleteQueue.instance;

    await queue.enqueue(bookId: 'default-book', accountId: 'a1');
    var list = await queue.loadForBook('default-book');
    expect(list.length, 1);
    expect(list.first['id'], 'a1');
    expect(list.first.containsKey('serverId'), isFalse);

    await queue.enqueue(bookId: 'default-book', accountId: 'a1', serverId: 12);
    list = await queue.loadForBook('default-book');
    expect(list.length, 1);
    expect(list.first['id'], 'a1');
    expect(list.first['serverId'], 12);

    await queue.enqueue(bookId: 'default-book', accountId: 'a1', serverId: 12);
    list = await queue.loadForBook('default-book');
    expect(list.length, 1);
  });

  test('clear removes queue', () async {
    final queue = AccountDeleteQueue.instance;
    await queue.enqueue(bookId: 'default-book', accountId: 'a1', serverId: 1);
    expect((await queue.loadForBook('default-book')).length, 1);
    await queue.clear();
    expect((await queue.loadForBook('default-book')).length, 0);
  });
}
