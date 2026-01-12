import 'package:shared_preferences/shared_preferences.dart';

class MetaSyncStateStore {
  static const String _prefix = 'meta_sync_last_ms_';

  static String _key(String bookId, {required int? userId}) {
    if (userId == null) return '$_prefix$bookId';
    return '${_prefix}u${userId}_$bookId';
  }

  static Future<int> getLastMetaSyncMs(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    return prefs.getInt(_key(bookId, userId: uid)) ?? 0;
  }

  static Future<void> setLastMetaSyncMs(String bookId, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    await prefs.setInt(_key(bookId, userId: uid), ms);
    if (uid != null) {
      await prefs.remove(_key(bookId, userId: null));
    }
  }
}
