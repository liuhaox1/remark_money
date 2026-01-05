import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _SeedRunner extends StatefulWidget {
  const _SeedRunner({required this.onDone});

  final void Function(QaSeedReport report) onDone;

  @override
  State<_SeedRunner> createState() => _SeedRunnerState();
}

class _SeedRunnerState extends State<_SeedRunner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final report = await QaSeedService.seed(context);
      widget.onDone(report);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'use_shared_preferences': true,
    });
    await RepositoryFactory.initialize();
  });

  testWidgets('QA seed generates baseline dataset', (tester) async {
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

    QaSeedReport? report;
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
          home: _SeedRunner(
            onDone: (r) => report = r,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(report, isNotNull);
    expect(report!.bookId, 'qa-book');
    expect(bookProvider.activeBookId, 'qa-book');

    // Accounts
    expect(
      accountProvider.accounts.any((a) => a.id == 'default_wallet'),
      isTrue,
    );
    expect(
      accountProvider.accounts.any((a) => a.id == 'qa_credit_card'),
      isTrue,
    );

    // Tags
    expect(tagProvider.tags.where((t) => t.bookId == 'qa-book').length, greaterThanOrEqualTo(6));

    // Records
    final all = recordProvider.recordsForBookAll('qa-book');
    expect(all.length, greaterThanOrEqualTo(50));
    // includeInStats subset should be non-empty too.
    final inStats = recordProvider.recordsForBook('qa-book');
    expect(inStats.length, greaterThanOrEqualTo(30));
  });
}

