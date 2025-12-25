import 'package:shared_preferences/shared_preferences.dart';

class BudgetUpdateTimeStore {
  static String _key(String bookId) => 'budget_update_time_$bookId';

  static Future<int> getMs(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(bookId)) ?? 0;
  }

  static Future<void> setMs(String bookId, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(bookId), ms);
  }
}

