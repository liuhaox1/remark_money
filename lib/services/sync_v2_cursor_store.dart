import 'package:shared_preferences/shared_preferences.dart';

class SyncV2CursorStore {
  static const String _legacyPrefix = 'sync_v2_last_change_id_';

  static Future<int?> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('auth_user_id');
  }

  static String _key(String bookId, {required int? userId}) {
    if (userId == null) return '$_legacyPrefix$bookId';
    return '${_legacyPrefix}u${userId}_$bookId';
  }

  static Future<int> getLastChangeId(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    final v = prefs.getInt(_key(bookId, userId: uid));
    if (v != null) return v;
    if (uid != null) {
      // Legacy fallback (pre per-user keying).
      return prefs.getInt(_key(bookId, userId: null)) ?? 0;
    }
    return 0;
  }

  static Future<void> setLastChangeId(String bookId, int lastChangeId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = await _userId();
    await prefs.setInt(_key(bookId, userId: uid), lastChangeId);
    if (uid != null) {
      // Best-effort: remove legacy key to avoid cross-account collisions.
      await prefs.remove(_key(bookId, userId: null));
    }
  }
}
