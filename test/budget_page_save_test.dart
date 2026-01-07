import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remark_money/pages/budget_page.dart';
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

  Future<({BookProvider bookProvider, BudgetProvider budgetProvider})> _pumpBudgetPage(
    WidgetTester tester,
  ) async {
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
        child: const MaterialApp(home: BudgetPage()),
      ),
    );
    await tester.pumpAndSettle();

    return (bookProvider: bookProvider, budgetProvider: budgetProvider);
  }

  Future<void> _tapSave(WidgetTester tester) async {
    final label = find.text('保存');
    Finder target = find.ancestor(
      of: label,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    if (target.evaluate().isEmpty) {
      target = label;
    }
    final tapTarget = target.first;
    await tester.ensureVisible(tapTarget);
    await tester.tap(tapTarget);
  }

  testWidgets('BudgetPage save keeps user input when dismissing keyboard', (tester) async {
    final harness = await _pumpBudgetPage(tester);

    // Enter a total budget and press save.
    final textField = find.byType(TextField).first;
    await tester.enterText(textField, '100');
    await tester.pump();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    final entry = harness.budgetProvider.budgetForBook(harness.bookProvider.activeBookId);
    expect(entry.total, 100);
  });

  testWidgets('BudgetPage total budget empty input shows warning and does not save',
      (tester) async {
    final harness = await _pumpBudgetPage(tester);

    final textField = find.byType(TextField).first;

    // Try saving empty input: should show warning and keep existing value.
    await tester.enterText(textField, '');
    await tester.pump();
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);

    final entry = harness.budgetProvider.budgetForBook(harness.bookProvider.activeBookId);
    expect(entry.total, 0);
  });
}
