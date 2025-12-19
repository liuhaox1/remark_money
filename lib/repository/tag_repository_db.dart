import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database_helper.dart';
import '../models/tag.dart';

class TagRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Tag>> loadTags({required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.tags,
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'sort_order ASC, created_at ASC',
      );
      return maps.map(_mapToTag).toList();
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] loadTags failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Tag>> addTag(Tag tag) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        Tables.tags,
        {
          'id': tag.id,
          'book_id': tag.bookId,
          'name': tag.name,
          'color': tag.colorValue,
          'sort_order': tag.sortOrder,
          'created_at': tag.createdAt?.millisecondsSinceEpoch ?? now,
          'updated_at': tag.updatedAt?.millisecondsSinceEpoch ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return await loadTags(bookId: tag.bookId);
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] addTag failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Tag>> updateTag(Tag tag) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        Tables.tags,
        {
          'name': tag.name,
          'color': tag.colorValue,
          'sort_order': tag.sortOrder,
          'updated_at': tag.updatedAt?.millisecondsSinceEpoch ?? now,
        },
        where: 'id = ?',
        whereArgs: [tag.id],
      );
      return await loadTags(bookId: tag.bookId);
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] updateTag failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Tag>> deleteTag(String id, {required String bookId}) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(
          Tables.recordTags,
          where: 'tag_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          Tables.tags,
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return await loadTags(bookId: bookId);
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] deleteTag failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<String>> getTagIdsForRecord(String recordId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.recordTags,
        columns: const ['tag_id'],
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'created_at ASC',
      );
      return maps.map((m) => m['tag_id'] as String).toList();
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] getTagIdsForRecord failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> setTagsForRecord(String recordId, List<String> tagIds) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final unique = tagIds.toSet().toList();

      await db.transaction((txn) async {
        await txn.delete(
          Tables.recordTags,
          where: 'record_id = ?',
          whereArgs: [recordId],
        );
        for (final tagId in unique) {
          await txn.insert(
            Tables.recordTags,
            {
              'record_id': recordId,
              'tag_id': tagId,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] setTagsForRecord failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteLinksForRecord(String recordId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.recordTags,
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] deleteLinksForRecord failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, List<Tag>>> loadTagsForRecords(List<String> recordIds) async {
    if (recordIds.isEmpty) return <String, List<Tag>>{};
    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(recordIds.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT rt.record_id as record_id,
               t.id as id,
               t.book_id as book_id,
               t.name as name,
               t.color as color,
               t.sort_order as sort_order,
               t.created_at as created_at,
               t.updated_at as updated_at
        FROM ${Tables.recordTags} rt
        JOIN ${Tables.tags} t ON t.id = rt.tag_id
        WHERE rt.record_id IN ($placeholders)
        ORDER BY rt.created_at ASC
      ''', recordIds);

      final map = <String, List<Tag>>{};
      for (final row in rows) {
        final recordId = row['record_id'] as String;
        map.putIfAbsent(recordId, () => <Tag>[]);
        map[recordId]!.add(_mapToTag(row));
      }
      return map;
    } catch (e, stackTrace) {
      debugPrint('[TagRepositoryDb] loadTagsForRecords failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Tag _mapToTag(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      bookId: map['book_id'] as String? ?? 'default-book',
      name: map['name'] as String? ?? '',
      colorValue: map['color'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

