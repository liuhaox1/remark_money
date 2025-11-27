import 'dart:math';

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../repository/account_repository.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider();

  final AccountRepository _repository = AccountRepository();
  final Random _random = Random();

  final List<Account> _accounts = [];
  List<Account> get accounts => List.unmodifiable(
        _accounts..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final list = await _repository.loadAccounts();
    _accounts
      ..clear()
      ..addAll(list);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _repository.saveAccounts(_accounts);
    notifyListeners();
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

  Future<void> addAccount(Account account) async {
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
  }

  Future<void> updateAccount(Account updated) async {
    final index = _accounts.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;
    _accounts[index] = updated.copyWith(updatedAt: DateTime.now());
    await _persist();
  }

  Future<void> adjustBalance(String accountId, double delta) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    final account = _accounts[index];
    _accounts[index] = account.copyWith(
      currentBalance: account.currentBalance + delta,
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  /// 调整初始余额（用于修正历史偏差）
  /// 会同时更新 currentBalance，保持余额一致性
  Future<void> adjustInitialBalance(String accountId, double newInitialBalance) async {
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
  }

  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _persist();
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}

