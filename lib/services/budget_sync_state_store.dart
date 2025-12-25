import 'package:shared_preferences/shared_preferences.dart';

class BudgetSyncStateStore {
  static String _localEditKey(String bookId) => 'budget_local_edit_ms_$bookId';
  static String _serverKey(String bookId) => 'budget_server_update_ms_$bookId';
  static String _serverSyncVersionKey(String bookId) =>
      'budget_server_sync_version_$bookId';
  static String _localBaseSyncVersionKey(String bookId) =>
      'budget_local_base_sync_version_$bookId';

  static Future<int> getLocalEditMs(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_localEditKey(bookId)) ?? 0;
  }

  static Future<void> setLocalEditMs(String bookId, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localEditKey(bookId), ms);
  }

  static Future<int> getServerUpdateMs(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_serverKey(bookId)) ?? 0;
  }

  static Future<void> setServerUpdateMs(String bookId, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serverKey(bookId), ms);
  }

  static Future<int> getServerSyncVersion(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_serverSyncVersionKey(bookId));
    return int.tryParse(s ?? '') ?? 0;
  }

  static Future<void> setServerSyncVersion(String bookId, int version) async {
    final prefs = await SharedPreferences.getInstance();
    if (version <= 0) {
      await prefs.remove(_serverSyncVersionKey(bookId));
      return;
    }
    await prefs.setString(_serverSyncVersionKey(bookId), version.toString());
  }

  static Future<int> getLocalBaseSyncVersion(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_localBaseSyncVersionKey(bookId));
    return int.tryParse(s ?? '') ?? 0;
  }

  static Future<void> setLocalBaseSyncVersion(String bookId, int version) async {
    final prefs = await SharedPreferences.getInstance();
    if (version <= 0) {
      await prefs.remove(_localBaseSyncVersionKey(bookId));
      return;
    }
    await prefs.setString(_localBaseSyncVersionKey(bookId), version.toString());
  }
}
