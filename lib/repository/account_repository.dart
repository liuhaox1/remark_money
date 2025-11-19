import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';

class AccountRepository {
  static const _accountsKey = 'accounts_v1';

  Future<List<Account>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(Account.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.map((a) => a.toMap()).toList();
    await prefs.setString(_accountsKey, json.encode(list));
  }
}

