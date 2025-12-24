import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AccountDeleteQueue {
  AccountDeleteQueue._();

  static final AccountDeleteQueue instance = AccountDeleteQueue._();

  static const _key = 'account_delete_queue_v1';

  Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map>();
      return list
          .map((e) => e.cast<String, dynamic>())
          .where((e) => (e['id'] as String?)?.trim().isNotEmpty == true)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> enqueue({
    required String accountId,
    int? serverId,
  }) async {
    final id = accountId.trim();
    if (id.isEmpty) return;

    final current = await load();
    final next = <Map<String, dynamic>>[];

    var exists = false;
    for (final e in current) {
      final eid = (e['id'] as String?)?.trim();
      final esid = e['serverId'];
      if (eid == id) {
        exists = true;
        // merge missing serverId if we have it now
        if (serverId != null &&
            (esid == null || (esid is num && esid.toInt() <= 0))) {
          next.add({
            ...e,
            'serverId': serverId,
          });
        } else {
          next.add(e);
        }
        continue;
      }
      // also dedupe by serverId if present
      if (serverId != null &&
          esid is num &&
          esid.toInt() > 0 &&
          esid.toInt() == serverId) {
        exists = true;
        next.add({
          ...e,
          'id': eid ?? id,
          'serverId': serverId,
        });
        continue;
      }
      next.add(e);
    }

    if (!exists) {
      next.add({
        'id': id,
        if (serverId != null) 'serverId': serverId,
        'deletedAt': DateTime.now().toIso8601String(),
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

