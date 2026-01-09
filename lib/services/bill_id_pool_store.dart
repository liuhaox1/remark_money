import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BillIdPoolStore {
  BillIdPoolStore._();

  static final BillIdPoolStore instance = BillIdPoolStore._();

  static const String _keyPrefix = 'bill_id_pool_v1_';

  Future<void> setPool({
    required String bookId,
    required int nextId,
    required int endId,
  }) async {
    if (bookId.isEmpty) return;
    if (nextId <= 0 || endId <= 0 || endId < nextId) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$bookId';
    final payload = json.encode({'nextId': nextId, 'endId': endId});
    await prefs.setString(key, payload);
  }

  Future<List<int>> take({
    required String bookId,
    required int count,
  }) async {
    if (bookId.isEmpty) return const [];
    if (count <= 0) return const [];

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$bookId';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];

    final Map<String, dynamic> parsed;
    try {
      parsed = (json.decode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return const [];
    }

    final nextId = (parsed['nextId'] as num?)?.toInt();
    final endId = (parsed['endId'] as num?)?.toInt();
    if (nextId == null || endId == null || nextId <= 0 || endId < nextId) {
      return const [];
    }

    final available = endId - nextId + 1;
    final takeN = available < count ? available : count;
    final ids = List<int>.generate(takeN, (i) => nextId + i);

    final newNext = nextId + takeN;
    if (newNext > endId) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, json.encode({'nextId': newNext, 'endId': endId}));
    }

    return ids;
  }

  Future<void> clear(String bookId) async {
    if (bookId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$bookId');
  }
}

