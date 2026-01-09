import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';

class AccountRepository {
  static const _accountsKeyPrefix = 'accounts_v1_';
  static const _legacyAccountsKey = 'accounts_v1';

  Future<List<Account>> loadAccounts({required String bookId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_accountsKeyPrefix$bookId';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      if (bookId == 'default-book') {
        final migrated = await _tryMigrateLegacyDefaultBookAccounts(prefs);
        if (migrated.isNotEmpty) return migrated;
      }
      return const [];
    }
    return _decodeAccounts(raw);
  }

  Future<void> saveAccounts({required String bookId, required List<Account> accounts}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.map((a) => a.toMap()).toList();
    final key = '$_accountsKeyPrefix$bookId';
    await prefs.setString(key, json.encode(list));
  }

  List<Account> _decodeAccounts(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(Account.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Account>> _tryMigrateLegacyDefaultBookAccounts(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_legacyAccountsKey);
    if (raw == null || raw.isEmpty) return const [];

    final accounts = _decodeAccounts(raw);
    if (accounts.isEmpty) return const [];

    final normalized = accounts
        .map((a) => a.bookId.isEmpty ? a.copyWith(bookId: 'default-book') : a)
        .toList();

    try {
      await saveAccounts(bookId: 'default-book', accounts: normalized);
      await prefs.remove(_legacyAccountsKey);
    } catch (_) {
      // ignore; return loaded accounts anyway
    }

    return normalized;
  }
}

