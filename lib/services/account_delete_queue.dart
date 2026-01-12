import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AccountDeleteQueue {
  AccountDeleteQueue._();

  static final AccountDeleteQueue instance = AccountDeleteQueue._();

  static const _key = 'account_delete_queue_v1';

  Future<Map<String, List<Map<String, dynamic>>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded.cast<Map>();
        final cleaned = list
            .map((e) => e.cast<String, dynamic>())
            .where((e) => (e['id'] as String?)?.trim().isNotEmpty == true)
            .toList(growable: false);
        return {
          'default-book': cleaned,
        };
      }
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final out = <String, List<Map<String, dynamic>>>{};
        map.forEach((bookId, v) {
          if (v is List) {
            final list = v
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .where((e) => (e['id'] as String?)?.trim().isNotEmpty == true)
                .toList(growable: false);
            if (list.isNotEmpty) {
              out[bookId] = list;
            }
          }
        });
        return out;
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> loadForBook(String bookId) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final all = await loadAll();
    return all[bid] ?? const <Map<String, dynamic>>[];
  }

  Future<void> enqueue({
    required String bookId,
    required String accountId,
    int? serverId,
  }) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final id = accountId.trim();
    if (id.isEmpty) return;

    final current = await loadAll();
    final list = (current[bid] ?? const <Map<String, dynamic>>[]).toList();
    final nextList = <Map<String, dynamic>>[];

    var exists = false;
    for (final e in list) {
      final eid = (e['id'] as String?)?.trim();
      final esid = e['serverId'];
      if (eid == id) {
        exists = true;
        // merge missing serverId if we have it now
        if (serverId != null &&
            (esid == null || (esid is num && esid.toInt() <= 0))) {
          nextList.add({
            ...e,
            'serverId': serverId,
          });
        } else {
          nextList.add(e);
        }
        continue;
      }
      // also dedupe by serverId if present
      if (serverId != null &&
          esid is num &&
          esid.toInt() > 0 &&
          esid.toInt() == serverId) {
        exists = true;
        nextList.add({
          ...e,
          'id': eid ?? id,
          'serverId': serverId,
        });
        continue;
      }
      nextList.add(e);
    }

    if (!exists) {
      nextList.add({
        'id': id,
        if (serverId != null) 'serverId': serverId,
        'deletedAt': DateTime.now().toIso8601String(),
      });
    }

    final next = <String, List<Map<String, dynamic>>>{
      ...current,
      bid: nextList,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clearBook(String bookId) async {
    final bid = bookId.trim().isEmpty ? 'default-book' : bookId.trim();
    final current = await loadAll();
    if (!current.containsKey(bid)) return;
    final next = <String, List<Map<String, dynamic>>>{...current}..remove(bid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
