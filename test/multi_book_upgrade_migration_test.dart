import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/models/budget.dart';
import 'package:remark_money/models/recurring_record.dart';
import 'package:remark_money/models/record.dart';
import 'package:remark_money/models/tag.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/repository/repository_factory.dart';
import 'package:remark_money/services/sync_outbox_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'use_shared_preferences': true,
      'auth_token': 'token',
      'auth_user_id': 1,
    });
    await RepositoryFactory.initialize();
  });

  test('upgradeLocalBookToServer migrates book-scoped data and rebuilds outbox', () async {
    expect(RepositoryFactory.isUsingDatabase, isFalse);
    final bookProvider = BookProvider();
    await bookProvider.load();

    await bookProvider.addBook('Local Book');
    final oldBookId = bookProvider.books.last.id;
    await bookProvider.selectBook(oldBookId);

    // Seed records under old book (with serverId to ensure we reset sync meta on upgrade).
    final recordRepo = RepositoryFactory.createRecordRepository() as dynamic;
    await recordRepo.saveRecords(<Record>[
      Record(
        id: 'r1',
        serverId: 999,
        serverVersion: 7,
        amount: 10,
        remark: 'a',
        date: DateTime(2026, 1, 1),
        categoryKey: 'top_expense_food',
        bookId: oldBookId,
        accountId: 'acc',
        direction: TransactionDirection.out,
      ),
    ]);
    final beforeRecords = await recordRepo.loadRecords() as List<Record>;
    expect(beforeRecords.single.bookId, oldBookId);

    // Seed budget.
    final budgetRepo = RepositoryFactory.createBudgetRepository() as dynamic;
    await budgetRepo.saveBudget(
      Budget(
        entries: <String, BudgetEntry>{
          oldBookId: const BudgetEntry(total: 100, categoryBudgets: <String, double>{}),
        },
      ),
    );

    // Seed tags.
    final tagRepo = RepositoryFactory.createTagRepository() as dynamic;
    await tagRepo.saveTagsForBook(
      oldBookId,
      <Tag>[
        const Tag(id: 't1', bookId: 'x', name: 'Tag1'),
      ],
    );

    // Seed recurring plan.
    final recurringRepo =
        RepositoryFactory.createRecurringRecordRepository() as dynamic;
    await recurringRepo.savePlans(<RecurringRecordPlan>[
      RecurringRecordPlan(
        id: 'p1',
        bookId: oldBookId,
        categoryKey: 'top_expense_food',
        accountId: 'acc',
        direction: TransactionDirection.out,
        includeInStats: true,
        amount: 1,
        remark: 'plan',
        periodType: RecurringPeriodType.monthly,
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 2, 1),
      ),
    ]);

    // Perform upgrade.
    const newBookId = '12345';
    await bookProvider.upgradeLocalBookToServer(
      oldBookId,
      newBookId,
      queueUploadAllRecords: true,
    );

    expect(bookProvider.books.any((b) => b.id == oldBookId), isFalse);
    expect(bookProvider.books.any((b) => b.id == newBookId), isTrue);
    expect(bookProvider.activeBookId, newBookId);

    // Records migrated + reset server sync fields.
    final migratedRecords = await recordRepo.loadRecords();
    final r = (migratedRecords as List<Record>).single;
    expect(r.bookId, newBookId);
    expect(r.serverId, isNull);
    expect(r.serverVersion, isNull);

    // Budget moved.
    final migratedBudget = await budgetRepo.loadBudget() as Budget;
    expect(migratedBudget.entries.containsKey(oldBookId), isFalse);
    expect(migratedBudget.entries[newBookId]?.total, 100);

    // Tags moved.
    final tagsNew = await tagRepo.loadTags(bookId: newBookId) as List<Tag>;
    expect(tagsNew, isNotEmpty);
    final tagsOld = await tagRepo.loadTags(bookId: oldBookId) as List<Tag>;
    expect(tagsOld, isEmpty);

    // Recurring plan moved.
    final plans = await recurringRepo.loadPlans() as List<RecurringRecordPlan>;
    expect(plans.single.bookId, newBookId);

    // Outbox rebuilt for new book.
    final outbox = await SyncOutboxService.instance.loadPending(newBookId);
    expect(outbox, isNotEmpty);
    expect(outbox.single.bookId, newBookId);
  });
}
