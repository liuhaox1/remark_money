import 'package:shared_preferences/shared_preferences.dart';

class SyncV2CursorStore {
  static String _key(String bookId) => 'sync_v2_last_change_id_$bookId';

  static Future<int> getLastChangeId(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(bookId)) ?? 0;
  }

  static Future<void> setLastChangeId(String bookId, int lastChangeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(bookId), lastChangeId);
  }
}

