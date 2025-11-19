import 'dart:math';

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../repository/account_repository.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider();

  final AccountRepository _repository = AccountRepository();
  final Random _random = Random();

  final List<Account> _accounts = [];
  List<Account> get accounts =>
      List.unmodifiable(_accounts..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

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

  double get totalAssets => _accounts
      .where((a) => !a.isDebt && a.includeInTotal)
      .fold(0, (sum, a) => sum + a.balance);

  double get totalDebts => _accounts
      .where((a) => a.isDebt && a.includeInTotal)
      .fold(0, (sum, a) => sum + a.balance.abs());

  double get netWorth => totalAssets - totalDebts;

  Future<void> addAccount(Account account) async {
    final nextSort =
        _accounts.isEmpty ? 0 : (_accounts.map((a) => a.sortOrder).reduce(max) + 1);
    _accounts.add(account.copyWith(sortOrder: nextSort, id: _generateId()));
    await _persist();
  }

  Future<void> updateAccount(Account updated) async {
    final index = _accounts.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;
    _accounts[index] = updated;
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

