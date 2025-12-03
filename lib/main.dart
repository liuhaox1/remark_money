import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        debugPaintBaselinesEnabled,
        debugPaintLayerBordersEnabled,
        debugPaintPointersEnabled,
        debugPaintSizeEnabled,
        debugRepaintRainbowEnabled,
        debugRepaintTextRainbowEnabled;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/book_provider.dart';
import 'providers/record_provider.dart';
import 'providers/category_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/account_provider.dart';
import 'providers/reminder_provider.dart';
import 'repository/repository_factory.dart';
import 'l10n/app_strings.dart';

import 'pages/root_shell.dart';
import 'pages/add_record_page.dart';
import 'pages/analysis_page.dart';
import 'pages/bill_page.dart';
import 'pages/budget_page.dart';
import 'pages/category_manager_page.dart';
import 'pages/finger_accounting_page.dart';
import 'widgets/device_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 确保全局关闭调试描边/基线/重绘彩虹等调试标记，避免导出的图片出现黄色线条
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
  debugRepaintTextRainbowEnabled = false;
  debugPrint('main start: ${DateTime.now().toIso8601String()}');

  // Windows / Linux / macOS 上初始化 sqflite FFI
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  // 初始化 RepositoryFactory（这会触发数据库迁移）
  await RepositoryFactory.initialize();

  final bookProvider = BookProvider();
  final recordProvider = RecordProvider();
  final categoryProvider = CategoryProvider();
  final budgetProvider = BudgetProvider();
  final themeProvider = ThemeProvider();
  final accountProvider = AccountProvider();
  final reminderProvider = ReminderProvider();

  await Future.wait([
    bookProvider.load(),
    recordProvider.load(),
    categoryProvider.load(),
    budgetProvider.load(),
    accountProvider.load(),
    reminderProvider.load(),
    themeProvider.load(),
  ]);
  debugPrint('providers loaded: ${DateTime.now().toIso8601String()}');

  runApp(
    RemarkMoneyApp(
      bookProvider: bookProvider,
      recordProvider: recordProvider,
      categoryProvider: categoryProvider,
      budgetProvider: budgetProvider,
      accountProvider: accountProvider,
      themeProvider: themeProvider,
      reminderProvider: reminderProvider,
    ),
  );
}

class RemarkMoneyApp extends StatelessWidget {
  const RemarkMoneyApp({
    super.key,
    required this.bookProvider,
    required this.recordProvider,
    required this.categoryProvider,
    required this.budgetProvider,
    required this.accountProvider,
    required this.themeProvider,
    required this.reminderProvider,
  });

  final BookProvider bookProvider;
  final RecordProvider recordProvider;
  final CategoryProvider categoryProvider;
  final BudgetProvider budgetProvider;
  final AccountProvider accountProvider;
  final ThemeProvider themeProvider;
  final ReminderProvider reminderProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bookProvider),
        ChangeNotifierProvider.value(value: recordProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: reminderProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appTitle,
            themeMode: theme.mode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: theme.seedColor,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: theme.seedColor,
              brightness: Brightness.dark,
            ),
            builder: (context, child) =>
                DeviceFrame(child: child ?? const SizedBox.shrink()),
            home: const RootShell(),
            routes: {
              '/stats': (_) => const AnalysisPage(),
              '/bill': (_) => const BillPage(),
              '/budget': (_) => const BudgetPage(),
              '/category-manager': (_) => const CategoryManagerPage(),
              '/finger-accounting': (_) => const FingerAccountingPage(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/add') {
                // 获取传递的参数，默认为 true (支出)
                final isExpense = settings.arguments as bool? ?? true;
                return MaterialPageRoute(
                  builder: (_) => AddRecordPage(isExpense: isExpense),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
