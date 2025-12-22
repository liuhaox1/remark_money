import 'package:shared_preferences/shared_preferences.dart';

/// 数据版本管理服务
/// 客户端修改数据时版本号+1，同步后与服务器版本统一
class DataVersionService {
  static const String _keyPrefix = 'data_version_';
  static bool _suppressIncrement = false;
  static final Map<String, int> _cache = <String, int>{};

  /// 获取指定账本的数据版本号
  static Future<int> getVersion(String bookId) async {
    final cached = _cache[bookId];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('$_keyPrefix$bookId') ?? 0;
    _cache[bookId] = v;
    return v;
  }

  /// 设置指定账本的数据版本号
  static Future<void> setVersion(String bookId, int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix$bookId', version);
    _cache[bookId] = version;
  }

  /// 版本号+1（客户端修改数据时调用）
  static Future<int> incrementVersion(String bookId) async {
    if (_suppressIncrement) {
      // suppress 下避免频繁读 prefs：直接返回缓存值即可
      return _cache[bookId] ?? 0;
    }
    final current = await getVersion(bookId);
    final newVersion = current + 1;
    await setVersion(bookId, newVersion);
    return newVersion;
  }

  /// 同步后更新版本号（与服务器版本统一）
  static Future<void> syncVersion(String bookId, int serverVersion) async {
    await setVersion(bookId, serverVersion);
  }

  static Future<T> runWithoutIncrement<T>(Future<T> Function() action) async {
    final prev = _suppressIncrement;
    _suppressIncrement = true;
    try {
      return await action();
    } finally {
      _suppressIncrement = prev;
    }
  }
}
