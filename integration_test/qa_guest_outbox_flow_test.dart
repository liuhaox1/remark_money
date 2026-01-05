import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/models/record.dart';
import 'package:remark_money/providers/account_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/providers/budget_provider.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/recurring_record_provider.dart';
import 'package:remark_money/providers/tag_provider.dart';
import 'package:remark_money/providers/theme_provider.dart';
import 'package:remark_money/repository/repository_factory.dart';
import 'package:remark_money/services/qa_seed_service.dart';
import 'package:remark_money/services/sync_outbox_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Guest create -> outbox adopt after login', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'use_shared_preferences': true,
    });
    await RepositoryFactory.initialize();

    final bookProvider = BookProvider();
    final recordProvider = RecordProvider();
    final categoryProvider = CategoryProvider();
    final budgetProvider = BudgetProvider();
    final accountProvider = AccountProvider();
    final themeProvider = ThemeProvider();
    final tagProvider = TagProvider();
    final recurringProvider = RecurringRecordProvider();

    await bookProvider.load();
    await Future.wait([
      recordProvider.load(),
      categoryProvider.load(),
      budgetProvider.load(),
      accountProvider.load(),
      recurringProvider.load(),
      themeProvider.load(),
    ]);
    await tagProvider.loadForBook(bookProvider.activeBookId);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bookProvider),
          ChangeNotifierProvider.value(value: recordProvider),
          ChangeNotifierProvider.value(value: categoryProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: accountProvider),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: tagProvider),
          ChangeNotifierProvider.value(value: recurringProvider),
        ],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );

    // 1) Seed baseline in qa-book (guest mode).
    final report = await QaSeedService.seed(
      tester.element(find.byType(SizedBox)),
    );
    expect(report.bookId, 'qa-book');

    // 2) Add a new local record while logged out; this should enqueue an upsert into guest outbox.
    final accountId = accountProvider.accounts.isNotEmpty
        ? accountProvider.accounts.first.id
        : (await accountProvider.ensureDefaultWallet(bookId: 'qa-book')).id;
    final expenseCategory =
        categoryProvider.categories.firstWhere((c) => c.isExpense).key;

    await recordProvider.addRecord(
      amount: 12.34,
      remark: 'integration_guest',
      date: DateTime.now(),
      categoryKey: expenseCategory,
      bookId: 'qa-book',
      accountId: accountId,
      direction: TransactionDirection.out,
      includeInStats: true,
      accountProvider: accountProvider,
    );

    final outbox = SyncOutboxService.instance;
    final guestPending = await outbox.loadPending('qa-book');
    expect(guestPending, isNotEmpty);

    // 3) Simulate login: set a non-mock token + user id.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'token_integration');
    await prefs.setInt('auth_user_id', 7);
    await prefs.setInt('sync_owner_user_id', 7);

    // Before adoption, user-scoped outbox should be empty (guest ops not visible).
    final beforeAdopt = await outbox.loadPending('qa-book');
    expect(beforeAdopt, isEmpty);

    // 4) Adopt guest creates to current user.
    await outbox.adoptGuestOutboxToCurrentUser();
    final afterAdopt = await outbox.loadPending('qa-book');
    expect(afterAdopt, isNotEmpty);

    // Ensure adopted ops are upserts (guest deletes should not be adopted).
    expect(afterAdopt.every((e) => e.op == SyncOutboxOp.upsert), isTrue);
  });
}
