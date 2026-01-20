import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../services/user_scope.dart';

class AccountRepository {
  static const _accountsKeyPrefix = 'accounts_v1_';
  static const _legacyAccountsKey = 'accounts_v1';

  Future<bool> _canAdoptLegacy(SharedPreferences prefs) async {
    final uid = UserScope.userId;
    if (uid <= 0) return true; // guest scope; safe enough
    return (prefs.getInt('sync_owner_user_id') ?? 0) == uid;
  }

  String _scopedKeyForBook(String bookId) => UserScope.key('$_accountsKeyPrefix$bookId');

  Future<List<Account>> loadAccounts({required String bookId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _scopedKeyForBook(bookId);
    var raw = prefs.getString(scopedKey);
    if (raw == null || raw.isEmpty) {
      final migratedPerBook = await _tryMigrateLegacyPerBookAccounts(prefs, bookId);
      if (migratedPerBook.isNotEmpty) return migratedPerBook;
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
    await prefs.setString(_scopedKeyForBook(bookId), json.encode(list));
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

  Future<List<Account>> _tryMigrateLegacyPerBookAccounts(
    SharedPreferences prefs,
    String bookId,
  ) async {
    final legacyKey = '$_accountsKeyPrefix$bookId';
    final raw = prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return const [];

    final accounts = _decodeAccounts(raw);
    if (accounts.isEmpty) return const [];

    if (!await _canAdoptLegacy(prefs)) {
      return const [];
    }

    try {
      await prefs.setString(_scopedKeyForBook(bookId), raw);
      await prefs.remove(legacyKey);
    } catch (_) {
      // ignore; return loaded accounts anyway
    }

    return accounts;
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
      if (await _canAdoptLegacy(prefs)) {
        await saveAccounts(bookId: 'default-book', accounts: normalized);
        await prefs.remove(_legacyAccountsKey);
      }
    } catch (_) {
      // ignore; return loaded accounts anyway
    }

    return normalized;
  }
}

