import 'package:flutter/foundation.dart' show debugPrint;

import '../database/database_helper.dart';
import '../models/account.dart';

/// 使用数据库的账户仓库（新版本）
class AccountRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有账户
  Future<List<Account>> loadAccounts() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        Tables.accounts,
        orderBy: 'sort_order ASC, created_at ASC',
      );

      return maps.map((map) => _mapToAccount(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('[AccountRepositoryDb] loadAccounts failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 保存账户列表
  Future<void> saveAccounts(List<Account> accounts) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();

      // 先删除所有账户
      batch.delete(Tables.accounts);

      // 插入新账户
      for (final account in accounts) {
        batch.insert(
          Tables.accounts,
          _accountToMap(account),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e, stackTrace) {
      debugPrint('[AccountRepositoryDb] saveAccounts failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 添加账户
  Future<List<Account>> add(Account account) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        Tables.accounts,
        _accountToMap(account),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return await loadAccounts();
    } catch (e, stackTrace) {
      debugPrint('[AccountRepositoryDb] add failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新账户
  Future<List<Account>> update(Account account) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        Tables.accounts,
        _accountToMap(account),
        where: 'id = ?',
        whereArgs: [account.id],
      );
      return await loadAccounts();
    } catch (e, stackTrace) {
      debugPrint('[AccountRepositoryDb] update failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 删除账户
  Future<List<Account>> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        Tables.accounts,
        where: 'id = ?',
        whereArgs: [id],
      );
      return await loadAccounts();
    } catch (e, stackTrace) {
      debugPrint('[AccountRepositoryDb] delete failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 将 Account 转换为数据库映射
  Map<String, dynamic> _accountToMap(Account account) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': account.id,
      'server_id': account.serverId,
      'sync_version': account.syncVersion ?? 0,
      'name': account.name,
      'type': account.kind.name, // 使用 kind 作为 type
      'subtype': account.subtype,
      'account_type': account.type.name,
      'icon': account.icon,
      'currency': account.currency,
      'initial_balance': account.initialBalance,
      'current_balance': account.currentBalance,
      'is_debt': account.isDebt ? 1 : 0,
      'include_in_total': account.includeInTotal ? 1 : 0,
      'include_in_overview': account.includeInOverview ? 1 : 0,
      'sort_order': account.sortOrder,
      'counterparty': account.counterparty,
      'interest_rate': account.interestRate,
      'due_date': account.dueDate?.millisecondsSinceEpoch,
      'note': account.note,
      'brand_key': account.brandKey,
      'is_delete': 0,
      'created_at': account.createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': account.updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  /// 将数据库映射转换为 Account 对象
  Account _mapToAccount(Map<String, dynamic> map) {
    final kindStr = map['type'] as String? ?? 'asset';
    final kind = AccountKind.values.firstWhere(
      (k) => k.name == kindStr,
      orElse: () => AccountKind.asset,
    );

    final createdAt = map['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
        : null;
    final updatedAt = map['updated_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
        : null;

    return Account(
      id: map['id'] as String,
      serverId: map['server_id'] as int?,
      syncVersion: map['sync_version'] as int?,
      name: map['name'] as String,
      kind: kind,
      subtype: map['subtype'] as String? ?? 'cash',
      type: AccountType.values.firstWhere(
        (t) => t.name == (map['account_type'] as String? ?? 'cash'),
        orElse: () => AccountType.cash,
      ),
      icon: map['icon'] as String? ?? 'wallet',
      includeInTotal: (map['include_in_total'] as int? ?? 1) == 1,
      includeInOverview: (map['include_in_overview'] as int? ?? 1) == 1,
      currency: map['currency'] as String? ?? 'CNY',
      sortOrder: map['sort_order'] as int? ?? 0,
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      counterparty: map['counterparty'] as String?,
      interestRate: (map['interest_rate'] as num?)?.toDouble(),
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      note: map['note'] as String?,
      brandKey: map['brand_key'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

