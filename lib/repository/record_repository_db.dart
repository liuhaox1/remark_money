import 'package:flutter/foundation.dart' show debugPrint;
import '../database/database_helper.dart';
import '../models/record.dart';

/// 使用数据库的记录仓库（新版本）
class RecordRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有记录
  Future<List<Record>> loadRecords({String? bookId}) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps;
      
      if (bookId != null) {
        maps = await db.query(
          Tables.records,
          where: 'book_id = ?',
          whereArgs: [bookId],
          orderBy: 'date DESC, created_at DESC',
        );
      } else {
        maps = await db.query(
          Tables.records,
          orderBy: 'date DESC, created_at DESC',
        );
      }

      return maps.map((map) => _mapToRecord(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] loadRecords failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 分页加载记录
  Future<List<Record>> loadRecordsPaginated({
    String? bookId,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryKey,
    String? accountId,
    bool? isExpense,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      final where = <String>[];
      final whereArgs = <dynamic>[];

      if (bookId != null) {
        where.add('book_id = ?');
        whereArgs.add(bookId);
      }

      if (startDate != null) {
        where.add('date >= ?');
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        where.add('date <= ?');
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      if (categoryKey != null) {
        where.add('category_key = ?');
        whereArgs.add(categoryKey);
      }

      if (accountId != null) {
        where.add('account_id = ?');
        whereArgs.add(accountId);
      }

      if (isExpense != null) {
        where.add('is_expense = ?');
        whereArgs.add(isExpense ? 1 : 0);
      }

      final maps = await db.query(
        Tables.records,
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC, created_at DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => _mapToRecord(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] loadRecordsPaginated failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 根据ID加载记录
  Future<Record?> loadRecordById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.records,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return _mapToRecord(maps.first);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] loadRecordById failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存记录（插入或更新）
  /// 根据 serverId 加载记录（用于云端去重/合并）
  Future<Record?> loadRecordByServerId(int serverId, {required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.records,
        where: 'server_id = ? AND book_id = ?',
        whereArgs: [serverId, bookId],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return _mapToRecord(maps.first);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] loadRecordByServerId failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 迁移账本ID（升级为多人账本时使用）
  Future<void> migrateBookId(String oldBookId, String newBookId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        Tables.records,
        {'book_id': newBookId},
        where: 'book_id = ?',
        whereArgs: [oldBookId],
      );
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] migrateBookId failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Record> saveRecord(Record record) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final map = {
        'id': record.id,
        'server_id': record.serverId,
        'server_version': record.serverVersion,
        'book_id': record.bookId,
        'category_key': record.categoryKey,
        'account_id': record.accountId,
        'amount': record.amount,
        'is_expense':
            record.direction == TransactionDirection.out ? 1 : 0,
        'date': record.date.millisecondsSinceEpoch,
        'remark': record.remark,
        'include_in_stats': record.includeInStats ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      };

      await db.insert(
        Tables.records,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return record;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] saveRecord failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 插入记录
  Future<List<Record>> insert(Record record) async {
    try {
      await saveRecord(record);
      return await loadRecords(bookId: record.bookId);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] insert failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新记录
  Future<List<Record>> update(Record record) async {
    try {
      await saveRecord(record);
      return await loadRecords(bookId: record.bookId);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] update failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新 serverId（用于同步回填服务器自增ID）
  Future<void> updateServerId(String billId, int serverId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        Tables.records,
        {
          'server_id': serverId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] updateServerId failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 删除记录
  Future<void> updateServerSyncState(
    String billId, {
    int? serverId,
    int? serverVersion,
  }) async {
    try {
      final db = await _dbHelper.database;
      final values = <String, Object?>{
        if (serverId != null) 'server_id': serverId,
        if (serverVersion != null) 'server_version': serverVersion,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      if (values.length <= 1) return;
      await db.update(
        Tables.records,
        values,
        where: 'id = ?',
        whereArgs: [billId],
      );
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] updateServerSyncState failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Record>> remove(String id, {String? bookId}) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.records,
        where: 'id = ?',
        whereArgs: [id],
      );
      return await loadRecords(bookId: bookId);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] remove failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 批量插入记录（增量写入）
  Future<void> batchInsert(List<Record> records) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final record in records) {
        batch.insert(
          Tables.records,
          {
            'id': record.id,
            'book_id': record.bookId,
            'category_key': record.categoryKey,
            'account_id': record.accountId,
            'amount': record.amount,
            'is_expense': record.direction == TransactionDirection.out ? 1 : 0,
            'date': record.date.millisecondsSinceEpoch,
            'remark': record.remark,
            'include_in_stats': record.includeInStats ? 1 : 0,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] batchInsert failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存所有记录（用于导入等场景）
  /// 先删除所有记录，再批量插入新记录
  Future<void> saveRecords(List<Record> records) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 删除所有记录
        await txn.delete(Tables.records);
        
        // 批量插入新记录
        final batch = txn.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final record in records) {
          batch.insert(
            Tables.records,
            {
              'id': record.id,
              'book_id': record.bookId,
              'category_key': record.categoryKey,
              'account_id': record.accountId,
              'amount': record.amount,
              'is_expense': record.direction == TransactionDirection.out ? 1 : 0,
              'date': record.date.millisecondsSinceEpoch,
              'remark': record.remark,
              'include_in_stats': record.includeInStats ? 1 : 0,
              'created_at': record.date.millisecondsSinceEpoch, // 使用原始日期
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        await batch.commit(noResult: true);
      });
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] saveRecords failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 统计记录数量
  Future<int> countRecords({
    String? bookId,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryKey,
    bool? isExpense,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      final where = <String>[];
      final whereArgs = <dynamic>[];

      if (bookId != null) {
        where.add('book_id = ?');
        whereArgs.add(bookId);
      }

      if (startDate != null) {
        where.add('date >= ?');
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        where.add('date <= ?');
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      if (categoryKey != null) {
        where.add('category_key = ?');
        whereArgs.add(categoryKey);
      }

      if (isExpense != null) {
        where.add('is_expense = ?');
        whereArgs.add(isExpense ? 1 : 0);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${Tables.records}'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
        whereArgs.isEmpty ? null : whereArgs,
      );

      return result.first['count'] as int;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] countRecords failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 查询指定日期范围的记录（用于按需查询）
  Future<List<Record>> queryRecordsForPeriod({
    required String bookId,
    required DateTime start,
    required DateTime end,
    String? categoryKey,
    String? accountId,
    bool? isExpense,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      final where = <String>['book_id = ?', 'date >= ?', 'date <= ?'];
      final whereArgs = <dynamic>[
        bookId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ];

      if (categoryKey != null) {
        where.add('category_key = ?');
        whereArgs.add(categoryKey);
      }

      if (accountId != null) {
        where.add('account_id = ?');
        whereArgs.add(accountId);
      }

      if (isExpense != null) {
        where.add('is_expense = ?');
        whereArgs.add(isExpense ? 1 : 0);
      }

      final maps = await db.query(
        Tables.records,
        where: where.join(' AND '),
        whereArgs: whereArgs,
        orderBy: 'date DESC, created_at DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => _mapToRecord(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] queryRecordsForPeriod failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 查询指定月份的记录
  Future<List<Record>> queryRecordsForMonth({
    required String bookId,
    required int year,
    required int month,
    int? limit,
    int? offset,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return queryRecordsForPeriod(
      bookId: bookId,
      start: start,
      end: end,
      limit: limit,
      offset: offset,
    );
  }

  /// 查询指定日期的记录
  Future<List<Record>> queryRecordsForDay({
    required String bookId,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return queryRecordsForPeriod(
      bookId: bookId,
      start: start,
      end: end,
    );
  }

  /// 账户余额聚合（跨账本）：按 account_id 汇总所有流水的增量，用于修复“余额对不上”。
  ///
  /// - 支出：-amount
  /// - 收入：+amount
  Future<Map<String, double>> getAllAccountDeltas() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT account_id, '
        'COALESCE(SUM(CASE WHEN is_expense = 1 THEN -amount ELSE amount END), 0) AS delta '
        'FROM ${Tables.records} '
        'GROUP BY account_id',
      );

      final result = <String, double>{};
      for (final row in rows) {
        final accountId = row['account_id'] as String?;
        if (accountId == null || accountId.isEmpty) continue;
        final delta = (row['delta'] as num?)?.toDouble() ?? 0.0;
        result[accountId] = delta;
      }
      return result;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] getAllAccountDeltas failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return const {};
    }
  }

  /// 使用SQL聚合查询获取月份统计（高效）
  Future<Map<String, double>> getMonthStats({
    required String bookId,
    required int year,
    required int month,
  }) async {
    try {
      final db = await _dbHelper.database;
      final start = DateTime(year, month, 1).millisecondsSinceEpoch;
      final end = DateTime(year, month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;

      final result = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN is_expense = 0 AND include_in_stats = 1 THEN amount ELSE 0 END) as income,
          SUM(CASE WHEN is_expense = 1 AND include_in_stats = 1 THEN amount ELSE 0 END) as expense
        FROM ${Tables.records}
        WHERE book_id = ? AND date >= ? AND date <= ?
          AND category_key NOT LIKE 'transfer%'
      ''', [bookId, start, end]);

      if (result.isEmpty) {
        return {'income': 0.0, 'expense': 0.0};
      }

      final row = result.first;
      return {
        'income': (row['income'] as num?)?.toDouble() ?? 0.0,
        'expense': (row['expense'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] getMonthStats failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 使用SQL聚合查询获取日期统计（高效）
  Future<Map<String, double>> getDayStats({
    required String bookId,
    required DateTime day,
  }) async {
    try {
      final db = await _dbHelper.database;
      final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

      final result = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN is_expense = 0 AND include_in_stats = 1 THEN amount ELSE 0 END) as income,
          SUM(CASE WHEN is_expense = 1 AND include_in_stats = 1 THEN amount ELSE 0 END) as expense
        FROM ${Tables.records}
        WHERE book_id = ? AND date >= ? AND date <= ?
          AND category_key NOT LIKE 'transfer%'
      ''', [bookId, start, end]);

      if (result.isEmpty) {
        return {'income': 0.0, 'expense': 0.0};
      }

      final row = result.first;
      return {
        'income': (row['income'] as num?)?.toDouble() ?? 0.0,
        'expense': (row['expense'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] getDayStats failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 使用SQL聚合查询获取时间段支出统计（高效）
  Future<double> getPeriodExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total
        FROM ${Tables.records}
        WHERE book_id = ? 
          AND date >= ? 
          AND date <= ?
          AND is_expense = 1 
          AND include_in_stats = 1
          AND category_key NOT LIKE 'transfer%'
      ''', [
        bookId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ]);

      if (result.isEmpty || result.first['total'] == null) {
        return 0.0;
      }

      return (result.first['total'] as num).toDouble();
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] getPeriodExpense failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 使用SQL聚合查询获取时间段分类支出统计（高效）
  Future<Map<String, double>> getPeriodCategoryExpense({
    required String bookId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT category_key, SUM(amount) as total
        FROM ${Tables.records}
        WHERE book_id = ? 
          AND date >= ? 
          AND date <= ?
          AND is_expense = 1 
          AND include_in_stats = 1
          AND category_key NOT LIKE 'transfer%'
        GROUP BY category_key
      ''', [
        bookId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ]);

      final categoryExpense = <String, double>{};
      for (final row in result) {
        final categoryKey = row['category_key'] as String;
        final total = (row['total'] as num).toDouble();
        categoryExpense[categoryKey] = total;
      }

      return categoryExpense;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] getPeriodCategoryExpense failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 将数据库映射转换为 Record 对象
  Record _mapToRecord(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as String,
      serverId: map['server_id'] as int?,
      serverVersion: map['server_version'] as int?,
      bookId: map['book_id'] as String,
      categoryKey: map['category_key'] as String,
      accountId: map['account_id'] as String,
      amount: map['amount'] as double,
      direction: (map['is_expense'] as int) == 1 
          ? TransactionDirection.out 
          : TransactionDirection.income,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      remark: map['remark'] as String? ?? '',
      includeInStats: (map['include_in_stats'] as int) == 1,
      pairId: null, // 数据库中没有存储 pairId
    );
  }
}
