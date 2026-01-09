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
import 'providers/tag_provider.dart';
import 'providers/recurring_record_provider.dart';
import 'repository/repository_factory.dart';
import 'database/database_helper.dart';
import 'l10n/app_strings.dart';
import 'theme/brand_theme.dart';

import 'pages/root_shell.dart';
import 'pages/login_landing_page.dart';
import 'pages/add_record_page.dart';
import 'services/auth_service.dart';
import 'pages/analysis_page.dart';
import 'pages/bill_page.dart';
import 'pages/budget_page.dart';
import 'pages/category_manager_page.dart';
import 'pages/finger_accounting_page.dart';
import 'pages/ui_lab_page.dart';
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

  // 先打开数据库：如有需要会自动从 SharedPreferences 迁移到加密 SQLite
  await DatabaseHelper().database;

  // 然后初始化 RepositoryFactory（根据迁移标记决定是否使用数据库版仓库）
  await RepositoryFactory.initialize();

  final bookProvider = BookProvider();
  final recordProvider = RecordProvider();
  final categoryProvider = CategoryProvider();
  final budgetProvider = BudgetProvider();
  final themeProvider = ThemeProvider();
  final accountProvider = AccountProvider();
  final tagProvider = TagProvider();
  final recurringRecordProvider = RecurringRecordProvider();

  await bookProvider.load();
  await Future.wait([
    recordProvider.load(),
    categoryProvider.load(),
    budgetProvider.load(),
    accountProvider.loadForBook(bookProvider.activeBookId),
    recurringRecordProvider.load(),
    themeProvider.load(),
  ]);
  await tagProvider.loadForBook(bookProvider.activeBookId);
  debugPrint('providers loaded: ${DateTime.now().toIso8601String()}');

  runApp(
    RemarkMoneyApp(
      bookProvider: bookProvider,
      recordProvider: recordProvider,
      categoryProvider: categoryProvider,
      budgetProvider: budgetProvider,
      accountProvider: accountProvider,
      themeProvider: themeProvider,
      tagProvider: tagProvider,
      recurringRecordProvider: recurringRecordProvider,
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
    required this.tagProvider,
    required this.recurringRecordProvider,
  });

  final BookProvider bookProvider;
  final RecordProvider recordProvider;
  final CategoryProvider categoryProvider;
  final BudgetProvider budgetProvider;
  final AccountProvider accountProvider;
  final ThemeProvider themeProvider;
  final TagProvider tagProvider;
  final RecurringRecordProvider recurringRecordProvider;

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
        ChangeNotifierProvider.value(value: tagProvider),
        ChangeNotifierProvider.value(value: recurringRecordProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final baseLight = AppTheme.light(theme.style, theme.tone);
          final baseDark = AppTheme.dark(theme.style, theme.tone);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appTitle,
            themeMode: theme.mode,
            theme: baseLight,
            darkTheme: baseDark,
            builder: (context, child) =>
                DeviceFrame(child: child ?? const SizedBox.shrink()),
            home: const _AuthWrapper(),
            routes: {
              '/stats': (_) => const AnalysisPage(),
              '/bill': (_) => const BillPage(),
              '/budget': (_) => const BudgetPage(),
              '/category-manager': (_) => const CategoryManagerPage(),
              '/finger-accounting': (_) => const FingerAccountingPage(),
              '/login': (_) => const LoginLandingPage(),
              '/ui-lab': (_) => const UiLabPage(),
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

/// 认证包装器：根据 token 状态决定显示登录页还是主页面
class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  final _authService = const AuthService();
  bool _isChecking = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当路由变化时，重新检查认证状态（例如从登录页返回时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isChecking) {
        _checkAuth();
      }
    });
  }

  Future<void> _checkAuth() async {
    try {
      final isValid = await _authService.isTokenValid();
      if (mounted) {
        setState(() {
          _isLoggedIn = isValid;
          _isChecking = false;
        });
      }
    } catch (e) {
      // 检查失败，默认显示登录页
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isChecking = false;
        });
      }
    }
  }

  // 添加一个方法来重新检查认证状态（供外部调用）
  void refreshAuth() {
    setState(() {
      _isChecking = true;
    });
    _checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // 显示加载中
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 如果已登录，显示主页面；否则显示登录页
    if (_isLoggedIn) {
      return const RootShell();
    } else {
      // 产品策略：支持免登录（游客模式），用户可从 Profile 入口自行登录
      return const RootShell();
    }
  }
}
