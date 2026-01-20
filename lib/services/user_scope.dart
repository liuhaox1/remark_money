import 'package:shared_preferences/shared_preferences.dart';

/// In-device storage scope.
///
/// - `userId == 0`: guest (not logged in)
/// - `userId > 0`: logged-in user
class UserScope {
  static int _userId = 0;

  static int get userId => _userId;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('auth_user_id') ?? 0;
    if (_userId < 0) _userId = 0;
  }

  static void setUserId(int userId) {
    _userId = userId <= 0 ? 0 : userId;
  }

  static String get prefix => _userId <= 0 ? 'g_' : 'u${_userId}_';

  static String key(String baseKey) => '$prefix$baseKey';
}

