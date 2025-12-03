import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database_helper.dart';
import '../models/budget.dart';

/// 使用数据库的预算仓库（新版本）
class BudgetRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载预算
  Future<Budget> loadBudget() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(Tables.budgets);

      if (maps.isEmpty) {
        return Budget.empty();
      }

      final entries = <String, BudgetEntry>{};
      for (final map in maps) {
        final bookId = map['book_id'] as String;
        final categoryBudgetsJson = map['category_budgets'] as String?;
        
        Map<String, double> categoryBudgets = {};
        if (categoryBudgetsJson != null && categoryBudgetsJson.isNotEmpty) {
          try {
            final decoded = json.decode(categoryBudgetsJson) as Map<String, dynamic>;
            categoryBudgets = decoded.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            );
          } catch (e) {
            debugPrint('[BudgetRepositoryDb] Failed to parse category budgets: $e');
            // 解析失败，使用空map
          }
        }

        entries[bookId] = BudgetEntry(
          total: (map['month_budget'] as num?)?.toDouble() ?? 0.0,
          categoryBudgets: categoryBudgets,
          annualTotal: (map['year_budget'] as num?)?.toDouble() ?? 0.0,
          annualCategoryBudgets: {}, // 年度分类预算可以扩展
        );
      }

      return Budget(entries: entries);
    } catch (e, stackTrace) {
      debugPrint('[BudgetRepositoryDb] loadBudget failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存预算
  Future<void> saveBudget(Budget budget) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 先删除所有预算
      batch.delete(Tables.budgets);

      // 插入新预算
      for (final entry in budget.entries.entries) {
        final bookId = entry.key;
        final budgetEntry = entry.value;

        batch.insert(
          Tables.budgets,
          {
            'book_id': bookId,
            'month_budget': budgetEntry.total,
            'year_budget': budgetEntry.annualTotal,
            'category_budgets': json.encode(budgetEntry.categoryBudgets),
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[BudgetRepositoryDb] saveBudget failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存单个账本的预算
  Future<void> saveBookBudget(String bookId, BudgetEntry entry) async {
    try {
      final budget = await loadBudget();
      final updatedBudget = budget.replaceEntry(bookId, entry);
      await saveBudget(updatedBudget);
    } catch (e, stackTrace) {
      debugPrint('[BudgetRepositoryDb] saveBookBudget failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

