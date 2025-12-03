import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import 'category_repository.dart';

/// 使用数据库的分类仓库（新版本）
class CategoryRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有分类
  Future<List<Category>> loadCategories() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.categories,
        orderBy: 'parent_key IS NULL DESC, key ASC',
      );

      if (maps.isEmpty) {
        // 如果没有数据，初始化默认分类
        await _initializeDefaultCategories(db);
        return await loadCategories();
      }

      return maps.map((map) => _mapToCategory(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[CategoryRepositoryDb] loadCategories failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存分类列表
  Future<void> saveCategories(List<Category> categories) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 先删除所有分类
      batch.delete(Tables.categories);

      // 插入新分类
      for (final category in categories) {
        batch.insert(
          Tables.categories,
          {
            'key': category.key,
            'name': category.name,
            'icon_code_point': category.icon.codePoint,
            'icon_font_family': category.icon.fontFamily,
            'icon_font_package': category.icon.fontPackage,
            'is_expense': category.isExpense ? 1 : 0,
            'parent_key': category.parentKey,
            'created_at': now,
            'updated_at': now,
          },
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[CategoryRepositoryDb] saveCategories failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 添加分类
  Future<List<Category>> add(Category category) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        Tables.categories,
        {
          'key': category.key,
          'name': category.name,
          'icon_code_point': category.icon.codePoint,
          'icon_font_family': category.icon.fontFamily,
          'icon_font_package': category.icon.fontPackage,
          'is_expense': category.isExpense ? 1 : 0,
          'parent_key': category.parentKey,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return await loadCategories();
    } catch (e, stackTrace) {
      debugPrint('[CategoryRepositoryDb] add failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 删除分类
  Future<List<Category>> delete(String key) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.categories,
        where: 'key = ?',
        whereArgs: [key],
      );
      return await loadCategories();
    } catch (e, stackTrace) {
      debugPrint('[CategoryRepositoryDb] delete failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新分类
  Future<List<Category>> update(Category category) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        Tables.categories,
        {
          'name': category.name,
          'icon_code_point': category.icon.codePoint,
          'icon_font_family': category.icon.fontFamily,
          'icon_font_package': category.icon.fontPackage,
          'is_expense': category.isExpense ? 1 : 0,
          'parent_key': category.parentKey,
          'updated_at': now,
        },
        where: 'key = ?',
        whereArgs: [category.key],
      );

      return await loadCategories();
    } catch (e, stackTrace) {
      debugPrint('[CategoryRepositoryDb] update failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 初始化默认分类
  Future<void> _initializeDefaultCategories(Database db) async {
    final defaultCategories = CategoryRepository.defaultCategories;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final category in defaultCategories) {
      batch.insert(
        Tables.categories,
        {
          'key': category.key,
          'name': category.name,
          'icon_code_point': category.icon.codePoint,
          'icon_font_family': category.icon.fontFamily,
          'icon_font_package': category.icon.fontPackage,
          'is_expense': category.isExpense ? 1 : 0,
          'parent_key': category.parentKey,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 将数据库映射转换为 Category 对象
  Category _mapToCategory(Map<String, dynamic> map) {
    return Category(
      key: map['key'] as String,
      name: map['name'] as String,
      icon: IconData(
        map['icon_code_point'] as int,
        fontFamily: map['icon_font_family'] as String?,
        fontPackage: map['icon_font_package'] as String?,
      ),
      isExpense: (map['is_expense'] as int) == 1,
      parentKey: map['parent_key'] as String?,
    );
  }
}

