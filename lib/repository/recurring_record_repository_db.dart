import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database_helper.dart';
import '../models/recurring_record.dart';
import '../models/record.dart';

/// 使用数据库的循环记账仓库（新版本）
class RecurringRecordRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有循环记账计划
  Future<List<RecurringRecordPlan>> loadPlans() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.recurringRecords,
        orderBy: 'next_due_date ASC',
      );

      return maps.map((map) => _mapToPlan(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[RecurringRecordRepositoryDb] loadPlans failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存计划列表
  Future<void> savePlans(List<RecurringRecordPlan> plans) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      // 先删除所有计划
      batch.delete(Tables.recurringRecords);

      // 插入新计划
      for (final plan in plans) {
        batch.insert(
          Tables.recurringRecords,
          _planToMap(plan),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[RecurringRecordRepositoryDb] savePlans failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 插入或更新计划
  Future<List<RecurringRecordPlan>> upsert(RecurringRecordPlan plan) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        Tables.recurringRecords,
        _planToMap(plan),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return await loadPlans();
    } catch (e, stackTrace) {
      debugPrint('[RecurringRecordRepositoryDb] upsert failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 删除计划
  Future<List<RecurringRecordPlan>> remove(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.recurringRecords,
        where: 'id = ?',
        whereArgs: [id],
      );
      return await loadPlans();
    } catch (e, stackTrace) {
      debugPrint('[RecurringRecordRepositoryDb] remove failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 将计划转换为数据库映射
  Map<String, dynamic> _planToMap(RecurringRecordPlan plan) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': plan.id,
      'category_key': plan.categoryKey,
      'account_id': plan.accountId,
      'amount': plan.amount,
      'is_expense': plan.direction == TransactionDirection.out ? 1 : 0,
      'period_type': plan.periodType == RecurringPeriodType.weekly ? 'weekly' : 'monthly',
      'start_date': plan.nextDate.millisecondsSinceEpoch, // 使用 nextDate 作为开始日期
      'next_due_date': plan.nextDate.millisecondsSinceEpoch,
      'remark': plan.remark,
      'created_at': now,
      'updated_at': now,
    };
  }

  /// 将数据库映射转换为计划
  RecurringRecordPlan _mapToPlan(Map<String, dynamic> map) {
    final periodTypeStr = map['period_type'] as String? ?? 'monthly';
    final periodType = periodTypeStr == 'weekly'
        ? RecurringPeriodType.weekly
        : RecurringPeriodType.monthly;

    return RecurringRecordPlan(
      id: map['id'] as String,
      bookId: 'default-book', // 默认账本，可以从记录中获取
      categoryKey: map['category_key'] as String,
      accountId: map['account_id'] as String,
      direction: (map['is_expense'] as int) == 1
          ? TransactionDirection.out
          : TransactionDirection.income,
      includeInStats: true,
      amount: (map['amount'] as num).toDouble(),
      remark: map['remark'] as String? ?? '',
      periodType: periodType,
      nextDate: DateTime.fromMillisecondsSinceEpoch(
        map['next_due_date'] as int? ?? map['start_date'] as int,
      ),
    );
  }
}

