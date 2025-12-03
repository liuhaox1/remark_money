import '../database/database_helper.dart';
import '../models/record_template.dart';
import '../models/record.dart';

/// 使用数据库的记录模板仓库（新版本）
class RecordTemplateRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const int _maxTemplates = 10;

  /// 加载所有模板
  Future<List<RecordTemplate>> loadTemplates() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Tables.recordTemplates,
      orderBy: 'last_used_at DESC, created_at DESC',
      limit: _maxTemplates,
    );

    return maps.map((map) => _mapToTemplate(map)).toList();
  }

  /// 保存模板列表
  Future<void> saveTemplates(List<RecordTemplate> templates) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // 先删除所有模板
    batch.delete(Tables.recordTemplates);

    // 插入新模板（限制数量）
    final limitedTemplates = templates.take(_maxTemplates).toList();
    for (final template in limitedTemplates) {
      batch.insert(
        Tables.recordTemplates,
        _templateToMap(template),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 插入或更新模板
  Future<List<RecordTemplate>> upsertTemplate(RecordTemplate template) async {
    final db = await _dbHelper.database;
    await db.insert(
      Tables.recordTemplates,
      _templateToMap(template),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 如果超过最大数量，删除最旧的
    final allTemplates = await loadTemplates();
    if (allTemplates.length > _maxTemplates) {
      final toDelete = allTemplates.skip(_maxTemplates).toList();
      for (final t in toDelete) {
        await db.delete(
          Tables.recordTemplates,
          where: 'id = ?',
          whereArgs: [t.id],
        );
      }
    }

    return await loadTemplates();
  }

  /// 标记模板为已使用
  Future<List<RecordTemplate>> markUsed(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      Tables.recordTemplates,
      {
        'last_used_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return await loadTemplates();
  }

  /// 将模板转换为数据库映射
  Map<String, dynamic> _templateToMap(RecordTemplate template) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': template.id,
      'category_key': template.categoryKey,
      'account_id': template.accountId,
      'remark': template.remark,
      'is_expense': template.direction == TransactionDirection.out ? 1 : 0,
      'last_used_at': template.lastUsedAt?.millisecondsSinceEpoch,
      'created_at': template.createdAt.millisecondsSinceEpoch,
      'updated_at': now,
    };
  }

  /// 将数据库映射转换为模板
  RecordTemplate _mapToTemplate(Map<String, dynamic> map) {
    return RecordTemplate(
      id: map['id'] as String,
      categoryKey: map['category_key'] as String,
      accountId: map['account_id'] as String? ?? '',
      direction: (map['is_expense'] as int) == 1
          ? TransactionDirection.out
          : TransactionDirection.income,
      includeInStats: true, // 模板默认计入统计
      remark: map['remark'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_used_at'] as int)
          : null,
    );
  }
}

