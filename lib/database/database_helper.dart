import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences/shared_preferences.dart';

// 平台检测：Windows 使用普通 sqflite，移动平台使用加密版本
import 'sqflite_platform_stub.dart' if (dart.library.io) 'sqflite_platform_io.dart' as sqflite_platform;

export 'package:sqflite/sqflite.dart';

/// 数据库版本号
const int _databaseVersion = 13;

/// 数据库名称
const String _databaseName = 'remark_money.db';

/// 数据库加密密码（实际应用中应该从安全存储中获取）
/// TODO: 在生产环境中，应该使用设备密钥或用户密码派生
const String _databasePassword = 'remark_money_encrypted_key_v1';

/// 数据库表名
class Tables {
  static const String records = 'records';
  static const String categories = 'categories';
  static const String accounts = 'accounts';
  static const String books = 'books';
  static const String budgets = 'budgets';
  static const String recordTemplates = 'record_templates';
  static const String recurringRecords = 'recurring_records';
  static const String appSettings = 'app_settings';
  static const String migrationLog = 'migration_log';
  static const String syncOutbox = 'sync_outbox';
  static const String tags = 'tags';
  static const String recordTags = 'record_tags';
}

/// 数据库管理类
/// 提供加密数据库、索引、分页等功能
/// Windows 平台使用普通 sqflite（不加密），移动平台使用 sqflite_sqlcipher（加密）
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static sqflite.Database? _database;
  static const String _migrationCompletedKey = 'db_migration_completed';

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// 获取数据库实例
  Future<sqflite.Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<sqflite.Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = '${documentsDirectory.path}/$_databaseName';

    // 检查是否需要从 SharedPreferences 迁移数据
    final needsMigration = await _checkMigrationNeeded();

    // 打开数据库（Windows 使用普通 sqflite，移动平台使用加密版本）
    final db = await sqflite_platform.openDatabaseWithPlatform(
      dbPath,
      password: _databasePassword,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // 如果需要迁移，执行迁移
    if (needsMigration) {
      await _migrateFromSharedPreferences(db);
    }

    return db;
  }

  /// 检查是否需要从 SharedPreferences 迁移
  Future<bool> _checkMigrationNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    // Migration should run at most once per install, not per DB schema version.
    if (prefs.getBool(_migrationCompletedKey) == true) return false;

    // Backward-compat: older builds used versioned keys; treat any prior completion as final.
    for (var v = 1; v <= _databaseVersion; v++) {
      final legacyKey = 'db_migration_completed_v$v';
      if (prefs.getBool(legacyKey) == true) {
        await prefs.setBool(_migrationCompletedKey, true);
        return false;
      }
    }
    return true;
  }

  /// 标记迁移完成
  Future<void> _markMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationCompletedKey, true);
    await prefs.setBool('db_migration_completed_v$_databaseVersion', true);
  }

  /// 创建数据库表
  Future<void> _onCreate(sqflite.Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
  }

  /// 升级数据库
  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    // 未来版本升级逻辑
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _upgradeToVersion(db, version);
    }
  }

  /// 升级到指定版本
  Future<void> _upgradeToVersion(sqflite.Database db, int version) async {
    switch (version) {
      case 1:
        // 初始版本，已在 _onCreate 中处理
        break;
      case 2:
        // 为 records 表增加 server_id 字段（用于存储服务器自增ID）
        await db.execute('ALTER TABLE ${Tables.records} ADD COLUMN server_id INTEGER');
        break;
      case 3:
        // 增加同步发件箱表：用于透明后台同步
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${Tables.syncOutbox} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_user_id INTEGER NOT NULL DEFAULT 0,
            book_id TEXT NOT NULL,
            op TEXT NOT NULL,
            record_id TEXT,
            server_id INTEGER,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_created ON ${Tables.syncOutbox}(owner_user_id, book_id, created_at)',
        );
        break;
      // 未来版本升级逻辑
      case 4:
        // records: add server_version (v2 sync optimistic lock)
        await db.execute('ALTER TABLE ${Tables.records} ADD COLUMN server_version INTEGER');
        break;
      case 5:
        // tags + record_tags (many-to-many)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${Tables.tags} (
            id TEXT PRIMARY KEY,
            book_id TEXT NOT NULL,
            name TEXT NOT NULL,
            color INTEGER,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE(book_id, name)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${Tables.recordTags} (
            record_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY(record_id, tag_id),
            FOREIGN KEY (record_id) REFERENCES ${Tables.records}(id),
            FOREIGN KEY (tag_id) REFERENCES ${Tables.tags}(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tags_book_sort ON ${Tables.tags}(book_id, sort_order, created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_record_tags_record ON ${Tables.recordTags}(record_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_record_tags_tag ON ${Tables.recordTags}(tag_id)',
        );
        break;
      case 6:
        // recurring_records: add enabled/book_id/include_in_stats/tag_ids/last_run_at
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN book_id TEXT',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN include_in_stats INTEGER NOT NULL DEFAULT 1',
          );
        } catch (_) {}
        try {
          await db.execute(
            "ALTER TABLE ${Tables.recurringRecords} ADD COLUMN tag_ids TEXT NOT NULL DEFAULT '[]'",
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN last_run_at INTEGER',
          );
        } catch (_) {}
        // Backfill legacy rows (book_id was newly introduced and could be NULL).
        try {
          await db.execute(
            "UPDATE ${Tables.recurringRecords} SET book_id = 'default-book' WHERE book_id IS NULL OR book_id = ''",
          );
        } catch (_) {}
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_recurring_enabled_next ON ${Tables.recurringRecords}(enabled, next_due_date)',
        );
        break;
      case 7:
        // recurring_records: add weekday/month_day (for "每周几/每月几号")
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN weekday INTEGER',
          );
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE ${Tables.recurringRecords} ADD COLUMN month_day INTEGER',
          );
        } catch (_) {}
        break;
      case 8:
        // sync/perf indexes
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_records_book_server_id ON ${Tables.records}(book_id, server_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_op_record ON ${Tables.syncOutbox}(owner_user_id, book_id, op, record_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_server ON ${Tables.syncOutbox}(owner_user_id, book_id, server_id)',
        );
        break;
      case 9:
        // records: add pair_id (transfer pairing)
        try {
          await db.execute('ALTER TABLE ${Tables.records} ADD COLUMN pair_id TEXT');
        } catch (_) {}
        break;
      case 10:
        // Remove reminders feature & drop table.
        try {
          await db.execute('DROP TABLE IF EXISTS reminders');
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('reminder_settings_v1');
          await prefs.remove('reminder_enabled');
          await prefs.remove('reminder_time');
          await prefs.remove('last_reminder_date');
        } catch (_) {}
        break;
      case 11:
        // v1 meta sync: add server sync_version support (accounts/categories/tags)
        try {
          await db.execute('ALTER TABLE ${Tables.categories} ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.tags} ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN subtype TEXT NOT NULL DEFAULT \"cash\"');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN account_type TEXT NOT NULL DEFAULT \"cash\"');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN icon TEXT NOT NULL DEFAULT \"wallet\"');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN server_id INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN include_in_overview INTEGER NOT NULL DEFAULT 1');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN currency TEXT NOT NULL DEFAULT \"CNY\"');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN initial_balance REAL NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN counterparty TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN interest_rate REAL');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN due_date INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN note TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN brand_key TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE ${Tables.accounts} ADD COLUMN is_delete INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        // Ensure idx remains available.
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_type ON ${Tables.accounts}(type)');
        } catch (_) {}
      case 12:
        // sync_outbox: isolate queued ops by owner_user_id so cross-account login won't push stale deletes/updates.
        try {
          await db.execute(
            'ALTER TABLE ${Tables.syncOutbox} ADD COLUMN owner_user_id INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_created ON ${Tables.syncOutbox}(owner_user_id, book_id, created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_op_record ON ${Tables.syncOutbox}(owner_user_id, book_id, op, record_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_server ON ${Tables.syncOutbox}(owner_user_id, book_id, server_id)',
        );
        break;
      case 13:
        // records: add created_by (used for multi-book member stats)
        try {
          await db.execute(
            'ALTER TABLE ${Tables.records} ADD COLUMN created_by INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_records_created_by ON ${Tables.records}(created_by)',
          );
        } catch (_) {}
        break;
      default:
        break;
    }
  }

  /// 创建所有表
  Future<void> _createTables(sqflite.Database db) async {
    // 记录表
	    await db.execute('''
	      CREATE TABLE IF NOT EXISTS ${Tables.records} (
	        id TEXT PRIMARY KEY,
	        server_id INTEGER,
	        server_version INTEGER,
	        created_by INTEGER NOT NULL DEFAULT 0,
	        book_id TEXT NOT NULL,
	        category_key TEXT NOT NULL,
	        account_id TEXT NOT NULL,
	        amount REAL NOT NULL,
        is_expense INTEGER NOT NULL,
        date INTEGER NOT NULL,
        remark TEXT,
        include_in_stats INTEGER NOT NULL DEFAULT 1,
        pair_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES ${Tables.books}(id),
        FOREIGN KEY (category_key) REFERENCES ${Tables.categories}(key),
        FOREIGN KEY (account_id) REFERENCES ${Tables.accounts}(id)
      )
    ''');

    // 同步发件箱（本地修改队列）：用于透明后台同步
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.syncOutbox} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_user_id INTEGER NOT NULL DEFAULT 0,
        book_id TEXT NOT NULL,
        op TEXT NOT NULL,
        record_id TEXT,
        server_id INTEGER,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 分类表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.categories} (
        key TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code_point INTEGER NOT NULL,
        icon_font_family TEXT,
        icon_font_package TEXT,
        is_expense INTEGER NOT NULL,
        parent_key TEXT,
        sync_version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (parent_key) REFERENCES ${Tables.categories}(key)
      )
    ''');

    // 账户表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.accounts} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        subtype TEXT NOT NULL DEFAULT 'cash',
        account_type TEXT NOT NULL DEFAULT 'cash',
        icon TEXT NOT NULL DEFAULT 'wallet',
        server_id INTEGER,
        sync_version INTEGER NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        is_debt INTEGER NOT NULL DEFAULT 0,
        include_in_total INTEGER NOT NULL DEFAULT 1,
        include_in_overview INTEGER NOT NULL DEFAULT 1,
        currency TEXT NOT NULL DEFAULT 'CNY',
        sort_order INTEGER NOT NULL DEFAULT 0,
        initial_balance REAL NOT NULL DEFAULT 0,
        counterparty TEXT,
        interest_rate REAL,
        due_date INTEGER,
        note TEXT,
        brand_key TEXT,
        is_delete INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 账本表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.books} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 预算表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.budgets} (
        book_id TEXT PRIMARY KEY,
        month_budget REAL,
        year_budget REAL,
        category_budgets TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES ${Tables.books}(id)
      )
    ''');

    // 记录模板表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.recordTemplates} (
        id TEXT PRIMARY KEY,
        category_key TEXT NOT NULL,
        account_id TEXT,
        amount REAL,
        remark TEXT,
        is_expense INTEGER NOT NULL,
        last_used_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 循环记账表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.recurringRecords} (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        category_key TEXT NOT NULL,
        account_id TEXT NOT NULL,
        amount REAL NOT NULL,
        is_expense INTEGER NOT NULL,
        include_in_stats INTEGER NOT NULL DEFAULT 1,
        enabled INTEGER NOT NULL DEFAULT 1,
        period_type TEXT NOT NULL,
        weekday INTEGER,
        month_day INTEGER,
        start_date INTEGER NOT NULL,
        next_due_date INTEGER NOT NULL,
        remark TEXT,
        tag_ids TEXT NOT NULL DEFAULT '[]',
        last_run_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 应用设置表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.appSettings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 迁移日志表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.migrationLog} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        target TEXT NOT NULL,
        migrated_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT
      )
    ''');

    // 标签表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.tags} (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        sync_version INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(book_id, name)
      )
    ''');

    // 记录-标签关联表（多对多）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.recordTags} (
        record_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(record_id, tag_id),
        FOREIGN KEY (record_id) REFERENCES ${Tables.records}(id),
        FOREIGN KEY (tag_id) REFERENCES ${Tables.tags}(id)
      )
    ''');
  }

  /// 创建索引
  Future<void> _createIndexes(sqflite.Database db) async {
    // 记录表索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_book_id ON ${Tables.records}(book_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_date ON ${Tables.records}(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_category ON ${Tables.records}(category_key)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_account ON ${Tables.records}(account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_date_book ON ${Tables.records}(book_id, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_expense ON ${Tables.records}(is_expense, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_book_server_id ON ${Tables.records}(book_id, server_id)');

    // 分类表索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_parent ON ${Tables.categories}(parent_key)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_expense ON ${Tables.categories}(is_expense)');

    // 账户表索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_type ON ${Tables.accounts}(type)');

    // 记录模板表索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_templates_last_used ON ${Tables.recordTemplates}(last_used_at)');

    // 同步发件箱索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_created ON ${Tables.syncOutbox}(owner_user_id, book_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_op_record ON ${Tables.syncOutbox}(owner_user_id, book_id, op, record_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_owner_book_server ON ${Tables.syncOutbox}(owner_user_id, book_id, server_id)',
    );

    // 标签索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tags_book_sort ON ${Tables.tags}(book_id, sort_order, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_record_tags_record ON ${Tables.recordTags}(record_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_record_tags_tag ON ${Tables.recordTags}(tag_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recurring_enabled_next ON ${Tables.recurringRecords}(enabled, next_due_date)',
    );
  }

  /// 从 SharedPreferences 迁移数据
  Future<void> _migrateFromSharedPreferences(sqflite.Database db) async {
    try {
      await db.transaction((txn) async {
        // 记录迁移开始
        await _logMigration(txn, 'shared_preferences', 'database', 'started');

        // 迁移各个表的数据
        await _migrateBooks(txn);
        await _migrateCategories(txn);
        await _migrateAccounts(txn);
        await _migrateRecords(txn);
        await _migrateBudgets(txn);
        await _migrateRecordTemplates(txn);
        await _migrateRecurringRecords(txn);
        await _migrateAppSettings(txn);

        // 记录迁移完成
        await _logMigration(txn, 'shared_preferences', 'database', 'completed');
      });

      // 标记迁移完成
      await _markMigrationCompleted();
    } catch (e) {
      // 记录迁移错误
      final db = await database;
      await db.transaction((txn) async {
        await _logMigration(txn, 'shared_preferences', 'database', 'failed', errorMessage: e.toString());
      });
      rethrow;
    }
  }

  /// 记录迁移日志
  Future<void> _logMigration(
    sqflite.Transaction txn,
    String source,
    String target,
    String status, {
    String? errorMessage,
  }) async {
    await txn.insert(Tables.migrationLog, {
      'source': source,
      'target': target,
      'migrated_at': DateTime.now().millisecondsSinceEpoch,
      'status': status,
      'error_message': errorMessage,
    });
  }

  /// 迁移账本数据
  Future<void> _migrateBooks(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('books_v1');
    if (raw == null || raw.isEmpty) return;

    for (final jsonStr in raw) {
      try {
        final map = Map<String, dynamic>.from(
          (await _parseJson(jsonStr)) as Map,
        );
        await txn.insert(Tables.books, {
          'id': map['id'],
          'name': map['name'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        // 跳过错误的数据
        continue;
      }
    }
  }

  /// 迁移分类数据
  Future<void> _migrateCategories(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('categories_v1');
    if (raw == null || raw.isEmpty) return;

    for (final jsonStr in raw) {
      try {
        final map = Map<String, dynamic>.from(
          (await _parseJson(jsonStr)) as Map,
        );
        await txn.insert(Tables.categories, {
          'key': map['key'],
          'name': map['name'],
          'icon_code_point': map['icon'],
          'icon_font_family': map['fontFamily'],
          'icon_font_package': map['fontPackage'],
          'is_expense': map['isExpense'] ? 1 : 0,
          'parent_key': map['parentKey'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        continue;
      }
    }
  }

  /// 迁移账户数据
  Future<void> _migrateAccounts(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('accounts_v1');
    if (raw == null || raw.isEmpty) return;

    try {
      final list = (await _parseJson(raw)) as List;
      for (final map in list) {
        final accountMap = Map<String, dynamic>.from(map as Map);
        await txn.insert(Tables.accounts, {
          'id': accountMap['id'],
          'name': accountMap['name'],
          'type': accountMap['type'] ?? accountMap['kind'] ?? 'asset',
          'current_balance': accountMap['currentBalance'] ?? accountMap['balance'] ?? 0.0,
          'is_debt': accountMap['isDebt'] == true ? 1 : 0,
          'include_in_total': accountMap['includeInTotal'] == true ? 1 : 0,
          'sort_order': accountMap['sortOrder'] ?? 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }
    } catch (e) {
      // 跳过错误
    }
  }

  /// 迁移记录数据
  Future<void> _migrateRecords(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('records_v1');
    if (raw == null || raw.isEmpty) return;

    for (final jsonStr in raw) {
      try {
        final map = Map<String, dynamic>.from(
          (await _parseJson(jsonStr)) as Map,
        );
        
        // 处理 direction 字段：兼容旧数据和新数据
        int isExpense;
        if (map['direction'] != null) {
          // 新数据格式
          final direction = map['direction'] as String;
          isExpense = (direction == 'out') ? 1 : 0;
        } else if (map['isExpense'] != null) {
          // 兼容字段
          isExpense = map['isExpense'] == true ? 1 : 0;
        } else {
          // 兼容旧数据：正为支出，负为收入
          final amount = (map['amount'] as num).toDouble();
          isExpense = amount >= 0 ? 1 : 0;
        }
        
        await txn.insert(Tables.records, {
          'id': map['id'],
          'book_id': map['bookId'] ?? 'default-book',
          'category_key': map['categoryKey'],
          'account_id': map['accountId'] ?? '',
          'amount': (map['amount'] as num).abs().toDouble(),
          'is_expense': isExpense,
          'date': (map['date'] as String).isNotEmpty
              ? DateTime.parse(map['date']).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          'remark': map['remark'] ?? '',
          'include_in_stats': map['includeInStats'] == true ? 1 : 0,
          'pair_id': map['pairId'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        continue;
      }
    }
  }

  /// 迁移预算数据
  Future<void> _migrateBudgets(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('budget_v1');
    if (raw == null || raw.isEmpty) return;

    try {
      final map = Map<String, dynamic>.from(
        (await _parseJson(raw)) as Map,
      );
      await txn.insert(Tables.budgets, {
        'book_id': map['bookId'] ?? 'default-book',
        'month_budget': map['monthBudget'],
        'year_budget': map['yearBudget'],
        'category_budgets': map['categoryBudgets'] != null
            ? await _encodeJson(map['categoryBudgets'])
            : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    } catch (e) {
      // 跳过错误
    }
  }

  /// 迁移记录模板数据
  Future<void> _migrateRecordTemplates(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('record_templates_v1');
    if (raw == null || raw.isEmpty) return;

    for (final jsonStr in raw) {
      try {
        final map = Map<String, dynamic>.from(
          (await _parseJson(jsonStr)) as Map,
        );
        final direction = map['direction'] as String? ?? 'out';
        final isExpense = direction == 'in' ? 0 : 1;
        await txn.insert(Tables.recordTemplates, {
          'id': map['id'],
          'category_key': map['categoryKey'],
          'account_id': map['accountId'] ?? '',
          'remark': map['remark'] ?? '',
          'is_expense': isExpense,
          'last_used_at': map['lastUsedAt'] != null
              ? DateTime.parse(map['lastUsedAt'] as String).millisecondsSinceEpoch
              : null,
          'created_at': map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        continue;
      }
    }
  }

  /// 迁移循环记账数据
  Future<void> _migrateRecurringRecords(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recurring_records_v1');
    if (raw == null || raw.isEmpty) return;
    final fallbackBookId = prefs.getString('active_book_v1') ?? 'default-book';

    for (final jsonStr in raw) {
      try {
        final map = Map<String, dynamic>.from(
          (await _parseJson(jsonStr)) as Map,
        );
        final direction = map['direction'] as String? ?? 'out';
        final isExpense = direction == 'in' ? 0 : 1;
        final periodType = map['periodType'] as String? ?? 'monthly';
        final includeInStats = map['includeInStats'] as bool? ?? true;
        final enabled = map['enabled'] as bool? ?? true;
        final bookId = (map['bookId'] as String?)?.trim();
        final weekday = map['weekday'] as int?;
        final monthDay = map['monthDay'] as int?;
        final rawTags = map['tagIds'];
        final tagIds = rawTags is List ? rawTags.map((e) => e.toString()).toList() : const <String>[];
        final rawLastRunAt = map['lastRunAt'] as String?;
        final nextDate = map['nextDate'] != null
            ? DateTime.parse(map['nextDate'] as String).millisecondsSinceEpoch
            : (map['nextDueDate'] != null
                ? DateTime.parse(map['nextDueDate'] as String).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch);
        await txn.insert(Tables.recurringRecords, {
          'id': map['id'],
          'book_id': (bookId == null || bookId.isEmpty) ? fallbackBookId : bookId,
          'category_key': map['categoryKey'],
          'account_id': map['accountId'] ?? '',
          'amount': (map['amount'] as num).toDouble(),
          'is_expense': isExpense,
          'include_in_stats': includeInStats ? 1 : 0,
          'enabled': enabled ? 1 : 0,
          'period_type': periodType == 'weekly' ? 'weekly' : 'monthly',
          'weekday': weekday,
          'month_day': monthDay,
          'start_date': nextDate,
          'next_due_date': nextDate,
          'remark': map['remark'],
          'tag_ids': await _encodeJson(tagIds),
          'last_run_at': rawLastRunAt == null
              ? null
              : DateTime.tryParse(rawLastRunAt)?.millisecondsSinceEpoch,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        continue;
      }
    }
  }

  /// 迁移提醒设置数据
  /// 迁移应用设置数据
  Future<void> _migrateAppSettings(sqflite.Transaction txn) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 迁移主题设置
    final themeMode = prefs.getString('theme_mode');
    if (themeMode != null) {
      await txn.insert(Tables.appSettings, {
        'key': 'theme_mode',
        'value': themeMode,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    }

    // 迁移当前账本ID
    final activeBookId = prefs.getString('active_book_v1');
    if (activeBookId != null) {
      await txn.insert(Tables.appSettings, {
        'key': 'active_book_id',
        'value': activeBookId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    }
  }

  /// 解析 JSON（异步处理，避免阻塞）
  Future<dynamic> _parseJson(String jsonStr) async {
    return await Future.microtask(() => 
      json.decode(jsonStr) as dynamic
    );
  }

  /// 编码 JSON
  Future<String> _encodeJson(dynamic value) async {
    return await Future.microtask(() => json.encode(value));
  }

  /// 分页查询辅助方法
  Future<List<Map<String, dynamic>>> queryWithPagination({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    List<String>? columns,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      columns: columns,
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// 回退到 SharedPreferences（紧急回退功能）
  Future<void> rollbackToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('db_migration_completed_v$_databaseVersion', false);
    await prefs.setBool('use_shared_preferences', true);
  }
}
