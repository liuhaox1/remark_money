import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database_helper.dart';
import '../models/book.dart';
import '../l10n/app_strings.dart';

/// 使用数据库的账本仓库（新版本）
class BookRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有账本
  Future<List<Book>> loadBooks() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.books,
        orderBy: 'created_at ASC',
      );

      if (maps.isEmpty) {
        // 如果没有数据，初始化默认账本
        await _initializeDefaultBooks(db);
        return await loadBooks();
      }

      return maps.map((map) => _mapToBook(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] loadBooks failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存账本列表
  Future<void> saveBooks(List<Book> books) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 先删除所有账本
      batch.delete(Tables.books);

      // 插入新账本
      for (final book in books) {
        batch.insert(
          Tables.books,
          {
            'id': book.id,
            'name': book.name,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] saveBooks failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 添加账本
  Future<List<Book>> add(Book book) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        Tables.books,
        {
          'id': book.id,
          'name': book.name,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return await loadBooks();
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] add failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新账本
  Future<List<Book>> update(Book book) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        Tables.books,
        {
          'name': book.name,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [book.id],
      );

      return await loadBooks();
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] update failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 删除账本
  Future<List<Book>> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.books,
        where: 'id = ?',
        whereArgs: [id],
      );
      return await loadBooks();
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] delete failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 加载当前激活的账本ID
  Future<String> loadActiveBookId() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.appSettings,
        where: 'key = ?',
        whereArgs: ['active_book_id'],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first['value'] as String;
      }

      // 如果没有设置，返回第一个账本
      final books = await loadBooks();
      if (books.isNotEmpty) {
        final firstBookId = books.first.id;
        await saveActiveBookId(firstBookId);
        return firstBookId;
      }

      // 如果连账本都没有，返回默认值
      return 'default-book';
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] loadActiveBookId failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存当前激活的账本ID
  Future<void> saveActiveBookId(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        Tables.appSettings,
        {
          'key': 'active_book_id',
          'value': id,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('[BookRepositoryDb] saveActiveBookId failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 初始化默认账本
  Future<void> _initializeDefaultBooks(Database db) async {
    const defaultBook = Book(
      id: 'default-book',
      name: AppStrings.defaultBook,
    );
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      Tables.books,
      {
        'id': defaultBook.id,
        'name': defaultBook.name,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 将数据库映射转换为 Book 对象
  Book _mapToBook(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

