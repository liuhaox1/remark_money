import '../database/database_helper.dart';
import '../models/record.dart';

/// 使用数据库的记录仓库（新版本）
class RecordRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有记录
  Future<List<Record>> loadRecords({String? bookId}) async {
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
  }

  /// 根据ID加载记录
  Future<Record?> loadRecordById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Tables.records,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _mapToRecord(maps.first);
  }

  /// 保存记录（插入或更新）
  Future<Record> saveRecord(Record record) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final map = {
      'id': record.id,
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
  }

  /// 插入记录
  Future<List<Record>> insert(Record record) async {
    await saveRecord(record);
    return await loadRecords(bookId: record.bookId);
  }

  /// 更新记录
  Future<List<Record>> update(Record record) async {
    await saveRecord(record);
    return await loadRecords(bookId: record.bookId);
  }

  /// 删除记录
  Future<List<Record>> remove(String id, {String? bookId}) async {
    final db = await _dbHelper.database;
    await db.delete(
      Tables.records,
      where: 'id = ?',
      whereArgs: [id],
    );
    return await loadRecords(bookId: bookId);
  }

  /// 批量插入记录（增量写入）
  Future<void> batchInsert(List<Record> records) async {
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
  }

  /// 统计记录数量
  Future<int> countRecords({
    String? bookId,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryKey,
    bool? isExpense,
  }) async {
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
  }

  /// 将数据库映射转换为 Record 对象
  Record _mapToRecord(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as String,
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

