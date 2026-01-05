import 'dart:io';

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
import 'package:remark_money/services/records_export_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P0: filter + stats consistency + csv export (guest mode)', (tester) async {
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

    final ctx = tester.element(find.byType(SizedBox));

    // 1) Seed baseline.
    await QaSeedService.seed(ctx);

    // 2) Add a deterministic record for later assertions.
    final accountId = accountProvider.accounts.isNotEmpty
        ? accountProvider.accounts.first.id
        : (await accountProvider.ensureDefaultWallet(bookId: 'qa-book')).id;
    final expenseCategory =
        categoryProvider.categories.firstWhere((c) => c.isExpense).key;

    final now = DateTime.now();
    final added = await recordProvider.addRecord(
      amount: 12.34,
      remark: 'integration_p0',
      date: now,
      categoryKey: expenseCategory,
      bookId: 'qa-book',
      accountId: accountId,
      direction: TransactionDirection.out,
      includeInStats: true,
      accountProvider: accountProvider,
    );

    // 3) Filter/pagination: query current month, ensure the new record is retrievable.
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final page1 = await recordProvider.recordsForPeriodPaginated(
      'qa-book',
      start: monthStart,
      end: monthEnd,
      limit: 20,
      offset: 0,
      isExpense: true,
    );
    expect(page1, isNotEmpty);
    expect(page1.any((r) => r.id == added.id), isTrue);
    // Desc sorting check: page is non-increasing by date.
    for (var i = 1; i < page1.length; i++) {
      expect(page1[i - 1].date.isAfter(page1[i].date) || page1[i - 1].date.isAtSameMomentAs(page1[i].date), isTrue);
    }

    final page2 = await recordProvider.recordsForPeriodPaginated(
      'qa-book',
      start: monthStart,
      end: monthEnd,
      limit: 20,
      offset: 20,
      isExpense: true,
    );
    if (page2.isNotEmpty) {
      expect(
        page1.last.date.isAfter(page2.first.date) ||
            page1.last.date.isAtSameMomentAs(page2.first.date),
        isTrue,
      );
    }

    // 4) Stats consistency: month stats equals manual sum on the same range (includeInStats only).
    final stats = await recordProvider.getMonthStatsAsync(
      DateTime(now.year, now.month, 1),
      'qa-book',
    );
    final monthAll = await recordProvider.recordsForPeriodAllAsync(
      'qa-book',
      start: monthStart,
      end: monthEnd,
    );
    double income = 0;
    double expense = 0;
    for (final r in monthAll) {
      if (!r.includeInStats) continue;
      income += r.incomeValue;
      expense += r.expenseValue;
    }
    expect(stats.income, closeTo(income, 0.0001));
    expect(stats.expense, closeTo(expense, 0.0001));

    // 5) Export: generate temp CSV without any platform UI and assert it contains our record remark.
    final file = await RecordsExportService.generateTempExportFile(
      ctx,
      bookId: 'qa-book',
      range: DateTimeRange(start: monthStart, end: monthEnd),
      format: RecordsExportFormat.csv,
    );
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('integration_p0'));
    expect(content.split('\n').length, greaterThanOrEqualTo(2));

    // Cleanup: keep temp directory from growing on repeated local runs.
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    // A sanity check that the file path is valid on this platform.
    expect(File(file.path).path, isNotEmpty);
  });
}
