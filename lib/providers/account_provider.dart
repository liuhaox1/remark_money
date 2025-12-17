import 'dart:math';

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/record.dart';
import '../repository/repository_factory.dart';
import '../utils/error_handler.dart';
import '../services/data_version_service.dart';
import '../services/meta_sync_notifier.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider();

  // 两种实现方法签名一致，使用 dynamic
  final dynamic _repository = RepositoryFactory.createAccountRepository();
  final Random _random = Random();

  final List<Account> _accounts = [];
  final Map<String, String> _idAliases = {};

  String _resolveId(String id) => _idAliases[id] ?? id;

  List<Account> get accounts {
    final deduped = _accounts.where((a) => !_idAliases.containsKey(a.id)).toList();
    deduped.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(deduped);
  }

  bool _loaded = false;
  bool get loaded => _loaded;

  /// 确保至少存在一个“默认钱包/现金”账户，并返回它。
  ///
  /// 设计目标：记一笔不打断用户流程（无须先手动创建账户）。
  Future<Account> ensureDefaultWallet({String? bookId}) async {
    if (!_loaded) {
      await load();
    }

    _rebuildDefaultWalletAliases();

    if (_accounts.isNotEmpty) {
      // 优先：显式默认钱包（brandKey / id）
      final explicit = _accounts.where((a) =>
          a.kind == AccountKind.asset &&
          a.subtype == AccountSubtype.cash.code &&
          (a.brandKey == 'default_wallet' || a.id == 'default_wallet'));
      if (explicit.isNotEmpty) return explicit.first;

      // 其次：名称为“默认钱包”的现金账户
      final byName = _accounts.where((a) =>
          a.kind == AccountKind.asset &&
          a.subtype == AccountSubtype.cash.code &&
          a.name.trim() == '默认钱包');
      if (byName.isNotEmpty) return byName.first;

      // 最后：任意现金账户兜底
      return _accounts.firstWhere(
        (a) => a.kind == AccountKind.asset && a.subtype == AccountSubtype.cash.code,
        orElse: () => _accounts.first,
      );
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
        brandKey: 'default_wallet',
      ),
      // 兜底钱包不应在“记一笔”链路里额外触发云同步（避免性能劣化）；
      // 后续在 app_start/app_resumed 或资产页触发的 meta sync 再上云即可。
      bookId: bookId,
      triggerSync: false,
    );

    _rebuildDefaultWalletAliases();
    return _accounts.firstWhere(
      (a) => a.id == 'default_wallet',
      orElse: () => _accounts.first,
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final list = await _repository.loadAccounts();
      _accounts
        ..clear()
        ..addAll(list);
      _loaded = true;
      _rebuildDefaultWalletAliases();
      await _rebuildBalancesFromRecordsIfPossible();
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorHandler.logError('AccountProvider.load', e, stackTrace);
      _loaded = false;
      rethrow;
    }
  }

  Future<void> _rebuildBalancesFromRecordsIfPossible() async {
    if (_accounts.isEmpty) return;

    try {
      final recordRepo = RepositoryFactory.createRecordRepository();

      Map<String, double> rawDeltas = {};
      if (RepositoryFactory.isUsingDatabase) {
        final result = await (recordRepo as dynamic).getAllAccountDeltas();
        if (result is Map) {
          rawDeltas = result.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          );
        }
      } else {
        final records = await (recordRepo as dynamic).loadRecords() as List<Record>;
        for (final r in records) {
          final baseDelta = r.isIncome ? r.amount : -r.amount;
          rawDeltas[r.accountId] = (rawDeltas[r.accountId] ?? 0) + baseDelta;
        }
      }

      if (rawDeltas.isEmpty) return;

      // 将“历史默认钱包”等别名账户的流水合并到 canonical 账户，避免余额对不上。
      final canonicalDeltas = <String, double>{};
      for (final entry in rawDeltas.entries) {
        final canonicalId = _resolveId(entry.key);
        canonicalDeltas[canonicalId] =
            (canonicalDeltas[canonicalId] ?? 0) + entry.value;
      }

      var changed = false;
      for (var i = 0; i < _accounts.length; i++) {
        final a = _accounts[i];
        // 不更新 alias（隐藏账户），只维护 canonical 的余额
        if (_idAliases.containsKey(a.id)) continue;
        final delta = canonicalDeltas[a.id] ?? 0;
        final expected = a.initialBalance + delta;
        if ((a.currentBalance - expected).abs() <= 0.01) continue;
        _accounts[i] = a.copyWith(
          currentBalance: expected,
          updatedAt: DateTime.now(),
        );
        changed = true;
      }

      if (!changed) return;

      // 余额是“由流水推导”的派生数据：修正后直接落库，但不触发云端元数据同步/版本号递增。
      await _repository.saveAccounts(_accounts);
      _rebuildDefaultWalletAliases();
    } catch (_) {
      // 忽略：不影响主流程，最多导致余额无法自动修复。
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
    final resolved = _resolveId(id);
    try {
      return _accounts.firstWhere((a) => a.id == resolved);
    } catch (_) {
      return null;
    }
  }

  List<Account> byKind(AccountKind kind) {
    return _accounts.where((a) => a.kind == kind).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  double get totalAssets => accounts
      .where((a) => a.includeInOverview && a.kind != AccountKind.liability)
      .fold(0, (sum, a) => sum + a.currentBalance);

  double get totalDebts => accounts
      .where((a) => a.includeInOverview && a.kind == AccountKind.liability)
      .fold(0, (sum, a) => sum + a.currentBalance.abs());

  double get netWorth => totalAssets - totalDebts;

  Future<void> addAccount(
    Account account, {
    String? bookId,
    bool triggerSync = true,
  }) async {
    final nextSort =
        _accounts.isEmpty ? 0 : (_accounts.map((a) => a.sortOrder).reduce(max) + 1);
    final now = DateTime.now();
    final providedId = account.id.trim();
    final newId = providedId.isNotEmpty ? providedId : _generateId();
    _accounts.add(
      account.copyWith(
        sortOrder: nextSort,
        id: newId,
        currentBalance: account.currentBalance,
        initialBalance: account.initialBalance,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _persist();
    _rebuildDefaultWalletAliases();
    // 数据修改时版本号+1（账户数据是全局的，使用默认账本ID）
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
    if (triggerSync) {
      MetaSyncNotifier.instance.notifyAccountsChanged(bookId ?? 'default-book');
    }
  }

  Future<void> updateAccount(
    Account updated, {
    String? bookId,
    bool triggerSync = true,
  }) async {
    final resolved = _resolveId(updated.id);
    final index = _accounts.indexWhere((a) => a.id == resolved);
    if (index == -1) return;
    _accounts[index] = updated.copyWith(updatedAt: DateTime.now());
    await _persist();
    _rebuildDefaultWalletAliases();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
    if (triggerSync) {
      MetaSyncNotifier.instance.notifyAccountsChanged(bookId ?? 'default-book');
    }
  }

  Future<void> adjustBalance(
    String accountId,
    double delta, {
    String? bookId,
    bool triggerSync = true,
  }) async {
    final resolved = _resolveId(accountId);
    final index = _accounts.indexWhere((a) => a.id == resolved);
    if (index == -1) return;
    final account = _accounts[index];
    _accounts[index] = account.copyWith(
      currentBalance: account.currentBalance + delta,
      updatedAt: DateTime.now(),
    );
    await _persist();
    _rebuildDefaultWalletAliases();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
    if (triggerSync) {
      MetaSyncNotifier.instance.notifyAccountsChanged(bookId ?? 'default-book');
    }
  }

  /// 调整初始余额（用于修正历史偏差）
  /// 会同时更新 currentBalance，保持余额一致性
  Future<void> adjustInitialBalance(
    String accountId,
    double newInitialBalance, {
    String? bookId,
    bool triggerSync = true,
  }) async {
    final resolved = _resolveId(accountId);
    final index = _accounts.indexWhere((a) => a.id == resolved);
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
    _rebuildDefaultWalletAliases();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
    if (triggerSync) {
      MetaSyncNotifier.instance.notifyAccountsChanged(bookId ?? 'default-book');
    }
  }

  Future<void> deleteAccount(
    String id, {
    String? bookId,
    bool triggerSync = true,
  }) async {
    final resolved = _resolveId(id);
    _accounts.removeWhere((a) => a.id == resolved);
    await _persist();
    _rebuildDefaultWalletAliases();
    // 数据修改时版本号+1
    if (bookId != null) {
      await DataVersionService.incrementVersion(bookId);
    }
    if (triggerSync) {
      MetaSyncNotifier.instance.notifyAccountsChanged(bookId ?? 'default-book');
    }
  }

  /// 云端覆盖本地账户列表（用于透明同步）。
  /// 不递增版本号，避免同步回环。
  Future<void> replaceFromCloud(List<Map<String, dynamic>> cloudAccounts) async {
    final localById = <String, Account>{};
    for (final a in _accounts) {
      localById[a.id] = a;
    }

    final next = <Account>[];
    final seen = <String>{};

    // 云端为“元数据来源”，但余额来自本地记账记录/手动调整：避免每次拉云端把余额覆盖回旧值。
    for (final raw in cloudAccounts) {
      final cloud = Account.fromMap(raw);
      final local = localById[cloud.id];
      final merged = local == null
          ? cloud
          : cloud.copyWith(
              initialBalance: local.initialBalance,
              currentBalance: local.currentBalance,
              createdAt: local.createdAt ?? cloud.createdAt,
              updatedAt: local.updatedAt ?? cloud.updatedAt,
            );
      next.add(merged);
      seen.add(merged.id);
    }

    // 保留云端暂未返回的本地账户（避免丢失记录引用，导致资产统计对不上）
    for (final local in _accounts) {
      if (seen.contains(local.id)) continue;
      next.add(local);
    }

    _accounts
      ..clear()
      ..addAll(next);

    _rebuildDefaultWalletAliases();
    await _repository.saveAccounts(_accounts);
    notifyListeners();
  }

  void _rebuildDefaultWalletAliases() {
    _idAliases.clear();

    // 仅对“默认钱包”做别名合并：避免因为历史 bug / 云端重复导致资产页出现多条“默认钱包”
    final candidates = _accounts
        .where((a) =>
            a.kind == AccountKind.asset &&
            a.subtype == AccountSubtype.cash.code &&
            (a.name.trim() == '默认钱包' ||
                a.brandKey == 'default_wallet' ||
                a.id == 'default_wallet'))
        .toList();
    if (candidates.length <= 1) return;

    Account canonical = candidates.first;
    for (final a in candidates) {
      if (a.id == 'default_wallet' || a.brandKey == 'default_wallet') {
        canonical = a;
        break;
      }
    }

    for (final a in candidates) {
      if (a.id == canonical.id) continue;
      _idAliases[a.id] = canonical.id;
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = _random.nextInt(1 << 20).toRadixString(16);
    return '$timestamp-$random';
  }
}
