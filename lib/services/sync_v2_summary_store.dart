import 'package:shared_preferences/shared_preferences.dart';

class SyncV2SummaryStore {
  static const Duration _minInterval = Duration(hours: 6);

  static const String _legacyPrefix = 'sync_v2_summary_checked_at_';

  static String _key(String bookId, {required int? userId}) {
    if (userId == null) return '$_legacyPrefix$bookId';
    return '${_legacyPrefix}u${userId}_$bookId';
  }

  static Future<bool> shouldCheck(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    final last = prefs.getInt(_key(bookId, userId: uid)) ?? 0;
    if (last <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - last >= _minInterval.inMilliseconds;
  }

  static Future<void> markChecked(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    await prefs.setInt(
      _key(bookId, userId: uid),
      DateTime.now().millisecondsSinceEpoch,
    );
    if (uid != null) {
      await prefs.remove(_key(bookId, userId: null));
    }
  }

  static Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id');
    await prefs.remove(_key(bookId, userId: uid));
    if (uid != null) {
      await prefs.remove(_key(bookId, userId: null));
    }
  }
}
