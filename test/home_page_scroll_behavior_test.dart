import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/models/record.dart';
import 'package:remark_money/pages/home_page.dart';
import 'package:remark_money/providers/account_provider.dart';
import 'package:remark_money/providers/book_provider.dart';
import 'package:remark_money/providers/budget_provider.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/providers/record_provider.dart';
import 'package:remark_money/providers/recurring_record_provider.dart';
import 'package:remark_money/providers/tag_provider.dart';
import 'package:remark_money/providers/theme_provider.dart';
import 'package:remark_money/repository/repository_factory.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'use_shared_preferences': true,
    });
    await RepositoryFactory.initialize();
  });

  testWidgets('HomePage uses single scrollable and avoids nested ListView scrolling', (tester) async {
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

    final account =
        await accountProvider.ensureDefaultWallet(bookId: bookProvider.activeBookId);
    final categoryKey = categoryProvider.categories
        .firstWhere((c) => !c.key.startsWith('transfer'))
        .key;
    await recordProvider.addRecord(
      amount: 10,
      remark: 'qa',
      date: DateTime.now(),
      categoryKey: categoryKey,
      bookId: bookProvider.activeBookId,
      accountId: account.id,
      direction: TransactionDirection.out,
      accountProvider: accountProvider,
    );

    const navBarHeight = 96.0;
    const viewBottom = 20.0;

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
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            navigationBarTheme: const NavigationBarThemeData(height: navBarHeight),
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(430, 900),
              devicePixelRatio: 1.0,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.only(bottom: viewBottom),
            ),
            child: const HomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Outer scroll view should own the controller so scrolling works anywhere.
    final scrollViewFinder = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.controller != null,
    );
    expect(scrollViewFinder, findsOneWidget);

    final scrollView = tester.widget<SingleChildScrollView>(scrollViewFinder);
    final outerBottomPadding = (scrollView.padding ?? EdgeInsets.zero)
        .resolve(TextDirection.ltr)
        .bottom;
    expect(outerBottomPadding, closeTo(viewBottom + navBarHeight + 12, 0.001));

    // Inner records ListView must be non-scrollable so it doesn't eat gestures.
    final recordListFinder = find.byWidgetPredicate((w) {
      if (w is! ListView) return false;
      if (!w.shrinkWrap) return false;
      if (w.cacheExtent != 1000) return false;
      return w.physics is NeverScrollableScrollPhysics && w.primary == false;
    });
    expect(recordListFinder, findsOneWidget);
  });
}

