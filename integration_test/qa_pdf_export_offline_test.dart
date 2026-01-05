import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:remark_money/services/records_export_service.dart';

class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('offline');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF export works offline (font download failure fallback)', (tester) async {
    HttpOverrides.global = _FailingHttpOverrides();
    addTearDown(() {
      HttpOverrides.global = null;
    });

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
    await QaSeedService.seed(ctx);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final file = await RecordsExportService.generateTempExportFile(
      ctx,
      bookId: 'qa-book',
      range: DateTimeRange(start: start, end: end),
      format: RecordsExportFormat.pdf,
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(100));

    try {
      await file.delete();
    } catch (_) {}
  });
}

