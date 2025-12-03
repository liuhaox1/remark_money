import '../database/database_helper.dart';
import '../models/account.dart';

/// 使用数据库的账户仓库（新版本）
class AccountRepositoryDb {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 加载所有账户
  Future<List<Account>> loadAccounts() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Tables.accounts,
      orderBy: 'sort_order ASC, created_at ASC',
    );

    return maps.map((map) => _mapToAccount(map)).toList();
  }

  /// 保存账户列表
  Future<void> saveAccounts(List<Account> accounts) async {
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
  }

  /// 添加账户
  Future<List<Account>> add(Account account) async {
    final db = await _dbHelper.database;
    await db.insert(
      Tables.accounts,
      _accountToMap(account),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return await loadAccounts();
  }

  /// 更新账户
  Future<List<Account>> update(Account account) async {
    final db = await _dbHelper.database;
    await db.update(
      Tables.accounts,
      _accountToMap(account),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    return await loadAccounts();
  }

  /// 删除账户
  Future<List<Account>> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      Tables.accounts,
      where: 'id = ?',
      whereArgs: [id],
    );
    return await loadAccounts();
  }

  /// 将 Account 转换为数据库映射
  Map<String, dynamic> _accountToMap(Account account) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': account.id,
      'name': account.name,
      'type': account.kind.name, // 使用 kind 作为 type
      'current_balance': account.currentBalance,
      'is_debt': account.isDebt ? 1 : 0,
      'include_in_total': account.includeInTotal ? 1 : 0,
      'sort_order': account.sortOrder,
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
      name: map['name'] as String,
      kind: kind,
      currentBalance: (map['current_balance'] as num).toDouble(),
      includeInTotal: (map['include_in_total'] as int) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

