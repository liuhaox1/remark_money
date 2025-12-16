import 'dart:math';

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../repository/repository_factory.dart';
import '../utils/error_handler.dart';
import '../services/data_version_service.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider();

  // 两种实现方法签名一致，使用 dynamic
  final dynamic _repository = RepositoryFactory.createAccountRepository();
  final Random _random = Random();

  final List<Account> _accounts = [];
  List<Account> get accounts => List.unmodifiable(
        _accounts..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );

  bool _loaded = false;
  bool get loaded => _loaded;

  /// 确保至少存在一个“默认钱包/现金”账户，并返回它。
  ///
  /// 设计目标：记一笔不打断用户流程（无须先手动创建账户）。
  Future<Account> ensureDefaultWallet({String? bookId}) async {
    if (!_loaded) {
      await load();
    }

    Account? preferred;
    if (_accounts.isNotEmpty) {
      preferred = _accounts.firstWhere(
        (a) => a.kind == AccountKind.asset && a.subtype == AccountSubtype.cash.code,
        orElse: () => _accounts.first,
      );
      return preferred;
    }

    // 没有任何账户：静默创建一个默认钱包（现金）
    await addAccount(
      Account(
        id: 'default_wallet',
        name: '默认钱包',
        kind: AccountKind.asset,
        subtype: AccountSubtype.cash.code,
        type: AccountType.cash,
        icon: 'wallet',
        includeInTotal: true,
        includeInOverview: true,
        currency: 'CNY',
        sortOrder: 0,
        initialBalance: 0,
        currentBalance: 0,
      ),
      bookId: bookId,
    );

    // addAccount 内部会生成 id 并写入列表，这里取刚创建的那条
    preferred = _accounts.firstWhere(
      (a) => a.kind == AccountKind.asset && a.subtype == AccountSubtype.cash.code,
      orElse: () => _accounts.first,
    );
    return preferred;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final list = await _repository.loadAccounts();
      _accounts
        ..clear()
        ..addAll(list);
      _loaded = true;
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('AccountProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  Future<void> _persist() async {
    try {
      await _repository.saveAccounts(_accounts);
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('AccountProvider._persist', e, stackTrace);
      rethrow;
    }
  }

  Account? byId(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Account> byKind(AccountKind kind) {
    return _accounts.where((a) => a.kind == kind).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  double get totalAssets => _accounts
      .where((a) => a.includeInOverview && a.kind != AccountKind.liability)
      .fold(0, (sum, a) => sum + a.currentBalance);

  double get totalDebts => _accounts
      .where((a) => a.includeInOverview && a.kind == AccountKind.liability)
      .fold(0, (sum, a) => sum + a.currentBalance.abs());

  double get netWorth => totalAssets - totalDebts;

  Future<void> addAccount(Account account, {String? bookId}) async {
    final nextSort =
        _accounts.isEmpty ? 0 : (_accounts.map((a) => a.sortOrder).reduce(max) + 1);
    final now = DateTime.now();
    _accounts.add(
      account.copyWith(
        sortOrder: nextSort,
        id: _generateId(),
        currentBalance: account.currentBalance,
        initialBalance: account.initialBalance,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _persist();
    // 数据修改时版本号+1（账户数据是全局的，使用默认账本ID）
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
  }

  Future<void> updateAccount(Account updated, {String? bookId}) async {
    final index = _accounts.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;
    _accounts[index] = updated.copyWith(updatedAt: DateTime.now());
    await _persist();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
  }

  Future<void> adjustBalance(String accountId, double delta, {String? bookId}) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    final account = _accounts[index];
    _accounts[index] = account.copyWith(
      currentBalance: account.currentBalance + delta,
      updatedAt: DateTime.now(),
    );
    await _persist();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
  }

  /// 调整初始余额（用于修正历史偏差）
  /// 会同时更新 currentBalance，保持余额一致性
  Future<void> adjustInitialBalance(String accountId, double newInitialBalance, {String? bookId}) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    final account = _accounts[index];
    // 计算差额，用于同步更新 currentBalance
    final delta = newInitialBalance - account.initialBalance;
    _accounts[index] = account.copyWith(
      initialBalance: newInitialBalance,
      currentBalance: account.currentBalance + delta,
      updatedAt: DateTime.now(),
    );
    await _persist();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
  }

  Future<void> deleteAccount(String id, {String? bookId}) async {
    _accounts.removeWhere((a) => a.id == id);
    await _persist();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
  }

  /// 云端覆盖本地账户列表（用于透明同步）。
  /// 不递增版本号，避免同步回环。
  Future<void> replaceFromCloud(List<Map<String, dynamic>> cloudAccounts) async {
    _accounts
      ..clear()
      ..addAll(cloudAccounts.map(Account.fromMap));
    await _repository.saveAccounts(_accounts);
    notifyListeners();
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
