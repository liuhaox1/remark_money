import 'package:shared_preferences/shared_preferences.dart';

/// 数据版本管理服务
/// 客户端修改数据时版本号+1，同步后与服务器版本统一
class DataVersionService {
  static const String _keyPrefix = 'data_version_';

  /// 获取指定账本的数据版本号
  static Future<int> getVersion(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix$bookId') ?? 0;
  }

  /// 设置指定账本的数据版本号
  static Future<void> setVersion(String bookId, int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix$bookId', version);
  }

  /// 版本号+1（客户端修改数据时调用）
  static Future<int> incrementVersion(String bookId) async {
    final current = await getVersion(bookId);
    final newVersion = current + 1;
    await setVersion(bookId, newVersion);
    return newVersion;
  }

  /// 同步后更新版本号（与服务器版本统一）
  static Future<void> syncVersion(String bookId, int serverVersion) async {
    await setVersion(bookId, serverVersion);
  }
}

