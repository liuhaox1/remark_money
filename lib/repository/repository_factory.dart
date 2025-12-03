import 'package:shared_preferences/shared_preferences.dart';
import 'record_repository.dart';
import 'record_repository_db.dart';
import 'category_repository.dart';
import 'category_repository_db.dart';
import 'account_repository.dart';
import 'account_repository_db.dart';
import 'book_repository.dart';
import 'book_repository_db.dart';
import 'budget_repository.dart';
import 'budget_repository_db.dart';
import 'reminder_repository.dart';
import 'reminder_repository_db.dart';
import 'record_template_repository.dart';
import 'record_template_repository_db.dart';
import 'recurring_record_repository.dart';
import 'recurring_record_repository_db.dart';

/// Repository 工厂类
/// 根据配置决定使用数据库版本还是 SharedPreferences 版本
class RepositoryFactory {
  static bool _useDatabase = false;
  static bool _initialized = false;

  /// 初始化工厂（检查是否应该使用数据库）
  static Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    
    // 检查是否有回退标志
    final useSharedPrefs = prefs.getBool('use_shared_preferences') ?? false;

    // 检查迁移是否完成（通过 SharedPreferences 标记）
    // 注意：DatabaseHelper 在首次打开时会根据该标记决定是否迁移
    final migrationCompleted =
        prefs.getBool('db_migration_completed_v1') ?? false;

    // 如果迁移完成且没有回退标志，使用数据库
    _useDatabase = migrationCompleted && !useSharedPrefs;
    _initialized = true;
  }

  /// 创建记录仓库
  static dynamic createRecordRepository() {
    if (_useDatabase) {
      return RecordRepositoryDb();
    }
    return RecordRepository();
  }

  /// 创建分类仓库
  static dynamic createCategoryRepository() {
    if (_useDatabase) {
      return CategoryRepositoryDb();
    }
    return CategoryRepository();
  }

  /// 创建账户仓库
  static dynamic createAccountRepository() {
    if (_useDatabase) {
      return AccountRepositoryDb();
    }
    return AccountRepository();
  }

  /// 创建账本仓库
  static dynamic createBookRepository() {
    if (_useDatabase) {
      return BookRepositoryDb();
    }
    return BookRepository();
  }

  /// 创建预算仓库
  static dynamic createBudgetRepository() {
    if (_useDatabase) {
      return BudgetRepositoryDb();
    }
    return BudgetRepository();
  }

  /// 创建提醒仓库
  static dynamic createReminderRepository() {
    if (_useDatabase) {
      return ReminderRepositoryDb();
    }
    return ReminderRepository();
  }

  /// 创建记录模板仓库
  static dynamic createRecordTemplateRepository() {
    if (_useDatabase) {
      return RecordTemplateRepositoryDb();
    }
    return RecordTemplateRepository();
  }

  /// 创建循环记账仓库
  static dynamic createRecurringRecordRepository() {
    if (_useDatabase) {
      return RecurringRecordRepositoryDb();
    }
    return RecurringRecordRepository();
  }

  /// 强制使用数据库版本（用于测试）
  static void forceUseDatabase() {
    _useDatabase = true;
    _initialized = true;
  }

  /// 强制使用 SharedPreferences 版本（用于回退）
  static void forceUseSharedPreferences() {
    _useDatabase = false;
    _initialized = true;
  }
}
