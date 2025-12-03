import 'package:flutter/foundation.dart' show debugPrint;
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
import '../database/database_helper.dart';

/// Repository 工厂类
/// 根据配置决定使用数据库版本还是 SharedPreferences 版本
class RepositoryFactory {
  static bool _useDatabase = false;
  static bool _initialized = false;

  /// 当前是否使用数据库作为主存储（true = 加密 SQLite，false = SharedPreferences）
  static bool get isUsingDatabase => _useDatabase;

  /// 初始化工厂（检查是否应该使用数据库）
  /// 
  /// 逻辑流程：
  /// 1. 检查是否有显式回退标志（use_shared_preferences == true）
  /// 2. 如果没有回退标志，尝试打开数据库（这会自动触发迁移，如果需要）
  /// 3. 检查迁移是否完成（db_migration_completed_v1 == true）
  /// 4. 如果数据库就绪且迁移完成，启用数据库后端
  /// 5. 否则回退到 SharedPreferences
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[RepositoryFactory] Already initialized, useDatabase=$_useDatabase');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // 1. 检查是否有显式回退标志
    final useSharedPrefs = prefs.getBool('use_shared_preferences') ?? false;
    
    if (useSharedPrefs) {
      // 显式要求使用 SharedPreferences，直接回退
      _useDatabase = false;
      _initialized = true;
      debugPrint('[RepositoryFactory] Explicit fallback to SharedPreferences');
      return;
    }

    // 2. 尝试打开数据库（如果需要，会自动触发迁移）
    bool dbReady = false;
    bool migrationCompleted = false;
    String? dbError;
    
    try {
      await DatabaseHelper().database;
      dbReady = true;
      
      // 3. 检查迁移是否完成
      migrationCompleted = prefs.getBool('db_migration_completed_v1') ?? false;
      
      // 如果数据库已打开但迁移未完成，说明可能是首次启动或迁移失败
      // 这种情况下，如果数据库能正常打开，我们仍然尝试使用数据库
      // （可能是全新安装，没有 SP 数据需要迁移）
      if (!migrationCompleted) {
        debugPrint('[RepositoryFactory] Database ready but migration not completed. '
            'This might be a fresh install or migration failed.');
      }
    } catch (e) {
      // 数据库初始化失败，记录错误并回退到 SharedPreferences
      dbError = e.toString();
      debugPrint('[RepositoryFactory] Database init/migration failed: $dbError');
      dbReady = false;
      migrationCompleted = false;
    }

    // 4. 决定使用哪个后端
    // 启用数据库的条件：
    // - 数据库成功初始化（dbReady == true）
    // - 迁移已完成（migrationCompleted == true）或全新安装（没有 SP 数据需要迁移）
    // - 未显式要求使用 SharedPreferences（useSharedPrefs == false）
    // 
    // 注意：如果数据库能打开，说明迁移已成功或无需迁移（全新安装）
    // 如果迁移失败，DatabaseHelper 会抛出异常，我们已捕获并回退到 SP
    _useDatabase = dbReady && !useSharedPrefs;

    debugPrint(
      '[RepositoryFactory] Initialized -> useDatabase=$_useDatabase, '
      'dbReady=$dbReady, migrationCompleted=$migrationCompleted, '
      'useSharedPrefs=$useSharedPrefs${dbError != null ? ", error=$dbError" : ""}',
    );

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

  /// 获取当前存储后端信息（用于诊断）
  /// 
  /// 返回一个 Map，包含：
  /// - backend: 'database' | 'shared_preferences'
  /// - migrationCompleted: 迁移是否完成
  /// - dbReady: 数据库是否就绪
  /// - useSharedPrefs: 是否显式要求使用 SharedPreferences
  static Future<Map<String, dynamic>> getStorageBackendInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final useSharedPrefs = prefs.getBool('use_shared_preferences') ?? false;
    final migrationCompleted = prefs.getBool('db_migration_completed_v1') ?? false;
    
    bool dbReady = false;
    try {
      await DatabaseHelper().database;
      dbReady = true;
    } catch (e) {
      dbReady = false;
    }
    
    return {
      'backend': _useDatabase ? 'database' : 'shared_preferences',
      'migrationCompleted': migrationCompleted,
      'dbReady': dbReady,
      'useSharedPrefs': useSharedPrefs,
      'initialized': _initialized,
    };
  }

  /// 检查迁移状态（用于诊断）
  /// 
  /// 返回迁移相关的详细信息
  static Future<Map<String, dynamic>> checkMigrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final migrationCompleted = prefs.getBool('db_migration_completed_v1') ?? false;
    final useSharedPrefs = prefs.getBool('use_shared_preferences') ?? false;
    
    bool dbReady = false;
    String? dbError;
    try {
      await DatabaseHelper().database;
      dbReady = true;
    } catch (e) {
      dbReady = false;
      dbError = e.toString();
    }
    
    return {
      'migrationCompleted': migrationCompleted,
      'dbReady': dbReady,
      'useSharedPrefs': useSharedPrefs,
      'dbError': dbError,
      'shouldMigrate': !migrationCompleted && dbReady && !useSharedPrefs,
    };
  }

  /// 强制使用数据库版本（显式开关）
  /// 
  /// 功能：
  /// 1. 清除回退标志（use_shared_preferences = false）
  /// 2. 确保数据库已打开（如有需要会触发迁移）
  /// 3. 立即切换到数据库后端
  /// 
  /// 注意：此操作会立即生效，但需要重启应用才能完全切换所有 Provider
  static Future<void> forceUseDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 清除回退标志
    await prefs.setBool('use_shared_preferences', false);
    
    // 确保数据库已经就绪（如有需要会触发迁移）
    try {
      await DatabaseHelper().database;
      
      // 如果迁移未完成，尝试触发迁移
      final migrationCompleted = prefs.getBool('db_migration_completed_v1') ?? false;
      if (!migrationCompleted) {
        debugPrint('[RepositoryFactory] Migration not completed, database will attempt migration on next access');
      }
      
      _useDatabase = true;
      _initialized = true;
      debugPrint('[RepositoryFactory] forceUseDatabase: now using database backend');
    } catch (e) {
      debugPrint('[RepositoryFactory] forceUseDatabase failed: $e');
      // 即使失败，也清除回退标志，让下次启动时重试
      rethrow;
    }
  }

  /// 强制使用 SharedPreferences 版本（紧急回退）
  /// 
  /// 功能：
  /// 1. 设置回退标志（use_shared_preferences = true）
  /// 2. 清除迁移完成标志（db_migration_completed_v1 = false）
  /// 3. 关闭数据库连接
  /// 4. 立即切换到 SharedPreferences 后端
  /// 
  /// 注意：
  /// - 此操作不会删除数据库文件，只是不再使用
  /// - 需要重启应用才能完全切换所有 Provider
  /// - 数据仍在 SharedPreferences 中，可以继续使用
  static Future<void> forceUseSharedPreferences() async {
    final helper = DatabaseHelper();
    
    try {
      // 关闭数据库连接
      await helper.close();
    } catch (e) {
      debugPrint('[RepositoryFactory] Error closing database: $e');
    }
    
    // 执行回退操作
    await helper.rollbackToSharedPreferences();
    
    // 立即切换后端
    _useDatabase = false;
    _initialized = true;
    
    debugPrint('[RepositoryFactory] forceUseSharedPreferences: now using SharedPreferences backend');
  }

  /// 重置迁移状态（用于测试或重新迁移）
  /// 
  /// 功能：
  /// 1. 清除迁移完成标志
  /// 2. 清除回退标志
  /// 3. 关闭数据库连接
  /// 4. 重置初始化状态
  /// 
  /// 注意：下次启动时会重新尝试迁移
  static Future<void> resetMigrationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('db_migration_completed_v1');
    await prefs.remove('use_shared_preferences');
    
    try {
      final helper = DatabaseHelper();
      await helper.close();
    } catch (e) {
      debugPrint('[RepositoryFactory] Error closing database during reset: $e');
    }
    
    _useDatabase = false;
    _initialized = false;
    
    debugPrint('[RepositoryFactory] resetMigrationState: migration state cleared');
  }
}
