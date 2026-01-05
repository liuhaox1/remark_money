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

  Future<int> countRecordsByAccountIds({
    required String bookId,
    required List<String> accountIds,
  }) async {
    if (accountIds.isEmpty) return 0;
    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(accountIds.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM ${Tables.records} WHERE book_id = ? AND account_id IN ($placeholders)',
        <Object?>[bookId, ...accountIds],
      );
      final first = rows.isEmpty ? null : rows.first['cnt'];
      if (first is int) return first;
      if (first is num) return first.toInt();
      return int.tryParse('$first') ?? 0;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] countRecordsByAccountIds failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Set<String>> loadUsedAccountIds({required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT account_id AS aid FROM ${Tables.records} WHERE book_id = ?',
        <Object?>[bookId],
      );
      return rows
          .map((e) => e['aid']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] loadUsedAccountIds failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> deleteRecordsByAccountIds({
    required String bookId,
    required List<String> accountIds,
  }) async {
    if (accountIds.isEmpty) return 0;
    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(accountIds.length, '?').join(',');
      return await db.transaction<int>((txn) async {
        // Find affected record ids first (for record_tags cleanup)
        final rows = await txn.rawQuery(
          'SELECT id FROM ${Tables.records} WHERE book_id = ? AND account_id IN ($placeholders)',
          <Object?>[bookId, ...accountIds],
        );
        final recordIds = rows
            .map((e) => e['id']?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
        if (recordIds.isNotEmpty) {
          final ridPlaceholders = List.filled(recordIds.length, '?').join(',');
          await txn.delete(
            Tables.recordTags,
            where: 'record_id IN ($ridPlaceholders)',
            whereArgs: recordIds,
          );
        }

        final deleted = await txn.delete(
          Tables.records,
          where: 'book_id = ? AND account_id IN ($placeholders)',
          whereArgs: <Object?>[bookId, ...accountIds],
        );
        return deleted;
      });
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] deleteRecordsByAccountIds failed: $e');
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
        'pair_id': record.pairId,
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

  Future<void> updateServerSyncStatesBulk(
    List<({String billId, int? serverId, int? serverVersion})> updates,
  ) async {
    if (updates.isEmpty) return;

    final db = await _dbHelper.database;
    final updatedAt = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final u in updates) {
        final values = <String, Object?>{
          if (u.serverId != null) 'server_id': u.serverId,
          if (u.serverVersion != null) 'server_version': u.serverVersion,
          'updated_at': updatedAt,
        };
        if (values.length <= 1) continue;
        batch.update(
          Tables.records,
          values,
          where: 'id = ?',
          whereArgs: [u.billId],
        );
      }
      await batch.commit(noResult: true);
    });
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

  /// 批量应用云端账单变更（v2 pull 的 hot path）
  /// - 在单个事务中完成 upsert/delete
  /// - 按 server_version 去重，避免重复写
  /// - delete 会清理 record_tags
  Future<void> applyCloudBillsV2({
    required String bookId,
    required List<Map<String, dynamic>> bills,
  }) async {
    if (bills.isEmpty) return;
    final db = await _dbHelper.database;

    // 仅处理带 serverId 的账单（v2 必须有）
    final serverIds = bills
        .map((b) => (b['id'] as int?) ?? (b['serverId'] as int?))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    if (serverIds.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const maxSqlVars = 900; // sqlite 默认 999，预留 bookId 等参数

    await db.transaction((txn) async {
      // 1) 预加载已有记录映射：server_id -> (local id, server_version)
      final localIdByServerId = <int, String>{};
      final localVersionByServerId = <int, int?>{};
      for (var i = 0; i < serverIds.length; i += maxSqlVars) {
        final chunk = serverIds.sublist(
          i,
          (i + maxSqlVars) > serverIds.length ? serverIds.length : (i + maxSqlVars),
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.rawQuery(
          'SELECT id, server_id, server_version FROM ${Tables.records} WHERE book_id = ? AND server_id IN ($placeholders)',
          <Object?>[bookId, ...chunk],
        );
        for (final r in rows) {
          final sid = r['server_id'];
          final lid = r['id'];
          if (sid == null || lid == null) continue;
          final sidInt = sid is int ? sid : int.tryParse('$sid');
          if (sidInt == null) continue;
          localIdByServerId[sidInt] = lid.toString();
          final v = r['server_version'];
          localVersionByServerId[sidInt] = v is int ? v : int.tryParse('$v');
        }
      }

      // 2) 批处理：先 delete（避免 upsert 后立刻被删）
      final deleteLocalIds = <String>[];
      for (final bill in bills) {
        final serverId = (bill['id'] as int?) ?? (bill['serverId'] as int?);
        if (serverId == null) continue;
        final isDelete = (bill['isDelete'] as int? ?? 0) == 1;
        if (!isDelete) continue;

        final serverVersion =
            bill['version'] as int? ?? bill['serverVersion'] as int?;
        final localVersion = localVersionByServerId[serverId];
        if (serverVersion != null && localVersion != null && serverVersion <= localVersion) {
          continue;
        }

        final localId = localIdByServerId[serverId];
        if (localId != null) deleteLocalIds.add(localId);
      }

      if (deleteLocalIds.isNotEmpty) {
        for (var i = 0; i < deleteLocalIds.length; i += maxSqlVars) {
          final chunk = deleteLocalIds.sublist(
            i,
            (i + maxSqlVars) > deleteLocalIds.length
                ? deleteLocalIds.length
                : (i + maxSqlVars),
          );
          final ridPlaceholders = List.filled(chunk.length, '?').join(',');
          await txn.delete(
            Tables.recordTags,
            where: 'record_id IN ($ridPlaceholders)',
            whereArgs: chunk,
          );
          await txn.delete(
            Tables.records,
            where: 'id IN ($ridPlaceholders) AND book_id = ?',
            whereArgs: <Object?>[...chunk, bookId],
          );
        }
      }

      // 3) upsert
      final batch = txn.batch();
      final tagIdsByLocalId = <String, List<String>>{};

      double parseAmount(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }
      for (final bill in bills) {
        final serverId = (bill['id'] as int?) ?? (bill['serverId'] as int?);
        if (serverId == null) continue;
        final isDelete = (bill['isDelete'] as int? ?? 0) == 1;
        if (isDelete) continue;

        final serverVersion =
            bill['version'] as int? ?? bill['serverVersion'] as int?;
        final localVersion = localVersionByServerId[serverId];
        if (serverVersion != null && localVersion != null && serverVersion <= localVersion) {
          continue;
        }

        final direction = (bill['direction'] as int? ?? 0) == 1
            ? TransactionDirection.income
            : TransactionDirection.out;
        final date = DateTime.tryParse(bill['billDate'] as String? ?? '');
        if (date == null) continue;

        final values = <String, Object?>{
          'server_id': serverId,
          if (serverVersion != null) 'server_version': serverVersion,
          'book_id': bookId,
          'category_key': bill['categoryKey']?.toString() ?? '',
          'account_id': bill['accountId']?.toString() ?? '',
          'amount': parseAmount(bill['amount']),
          'is_expense': direction == TransactionDirection.out ? 1 : 0,
          'date': date.millisecondsSinceEpoch,
          'remark': bill['remark']?.toString() ?? '',
          'include_in_stats': (bill['includeInStats'] as int? ?? 1),
          'pair_id': bill['pairId']?.toString(),
          'updated_at': now,
        };

        final localId = localIdByServerId[serverId];
        if (localId != null) {
          batch.update(
            Tables.records,
            values,
            where: 'id = ? AND book_id = ?',
            whereArgs: [localId, bookId],
          );
          final rawTagIds = bill['tagIds'];
          if (rawTagIds is List) {
            tagIdsByLocalId[localId] =
                rawTagIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        } else {
          final id = 'server_$serverId';
          localIdByServerId[serverId] = id;
          batch.insert(
            Tables.records,
            {
              'id': id,
              ...values,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final rawTagIds = bill['tagIds'];
          if (rawTagIds is List) {
            tagIdsByLocalId[id] =
                rawTagIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        }
      }
      await batch.commit(noResult: true);

      if (tagIdsByLocalId.isNotEmpty) {
        final allTagIds = tagIdsByLocalId.values
            .expand((e) => e)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList(growable: false);

        final existingTagIds = <String>{};
        for (var i = 0; i < allTagIds.length; i += maxSqlVars) {
          final chunk = allTagIds.sublist(
            i,
            (i + maxSqlVars) > allTagIds.length ? allTagIds.length : (i + maxSqlVars),
          );
          if (chunk.isEmpty) continue;
          final placeholders = List.filled(chunk.length, '?').join(',');
          final rows = await txn.rawQuery(
            'SELECT id FROM ${Tables.tags} WHERE id IN ($placeholders)',
            chunk,
          );
          for (final r in rows) {
            final id = r['id'];
            if (id != null) existingTagIds.add(id.toString());
          }
        }

        final tagBatch = txn.batch();
        for (final entry in tagIdsByLocalId.entries) {
          final rid = entry.key;
          final filtered = entry.value
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty && existingTagIds.contains(e))
              .toSet()
              .toList();
          tagBatch.delete(
            Tables.recordTags,
            where: 'record_id = ?',
            whereArgs: [rid],
          );
          for (final tid in filtered) {
            tagBatch.insert(
              Tables.recordTags,
              {
                'record_id': rid,
                'tag_id': tid,
                'created_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await tagBatch.commit(noResult: true);
      }
    });
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
            'pair_id': record.pairId,
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
              'pair_id': record.pairId,
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

  /// Count records that have been synced to server (server_id is not null).
  Future<int> countSyncedRecords({required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${Tables.records} WHERE book_id = ? AND server_id IS NOT NULL',
        <Object?>[bookId],
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] countSyncedRecords failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Aggregate synced records for v2 summary cross-check.
  Future<({int sumIds, int sumVersions})> sumSyncedAgg({required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(server_id), 0) as sumIds, COALESCE(SUM(server_version), 0) as sumVersions '
        'FROM ${Tables.records} WHERE book_id = ? AND server_id IS NOT NULL',
        <Object?>[bookId],
      );
      final row = result.isNotEmpty ? result.first : const <String, Object?>{};
      final sumIds = (row['sumIds'] as int?) ?? int.tryParse('${row['sumIds']}') ?? 0;
      final sumVersions = (row['sumVersions'] as int?) ?? int.tryParse('${row['sumVersions']}') ?? 0;
      return (sumIds: sumIds, sumVersions: sumVersions);
    } catch (e, stackTrace) {
      debugPrint('[RecordRepositoryDb] sumSyncedAgg failed: $e');
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
      final end =
          DateTime(year, month + 1, 0, 23, 59, 59, 999).millisecondsSinceEpoch;

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
      final end =
          DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;

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
      pairId: map['pair_id'] as String?,
    );
  }
}
