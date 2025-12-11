import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';

/// 同步版本号缓存服务
/// 在登录时拉取并缓存服务器版本号，避免每次打开"我的"页面都请求服务器
class SyncVersionCacheService {
  static const String _keyPrefix = 'sync_version_cache_';
  static const String _keyTimestamp = 'sync_version_cache_timestamp';
  static const int _cacheExpireHours = 24; // 缓存24小时过期

  final SyncService _syncService = SyncService();

  /// 获取缓存的版本号
  Future<int?> getCachedVersion(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${_keyTimestamp}_$bookId');
      if (timestamp == null) return null;

      // 检查缓存是否过期
      final now = DateTime.now().millisecondsSinceEpoch;
      final expireTime = timestamp + (_cacheExpireHours * 60 * 60 * 1000);
      if (now > expireTime) {
        // 缓存已过期，清除
        await prefs.remove('${_keyPrefix}$bookId');
        await prefs.remove('${_keyTimestamp}_$bookId');
        return null;
      }

      return prefs.getInt('${_keyPrefix}$bookId');
    } catch (e) {
      return null;
    }
  }

  /// 缓存版本号
  Future<void> cacheVersion(String bookId, int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_keyPrefix}$bookId', version);
      await prefs.setInt('${_keyTimestamp}_$bookId', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 忽略缓存失败
    }
  }

  /// 从服务器拉取版本号并缓存（登录时调用）
  Future<int?> fetchAndCacheVersion(String bookId) async {
    try {
      final result = await _syncService.queryStatus(bookId: bookId);
      if (result.success && result.syncRecord != null) {
        final version = result.syncRecord!.dataVersion ?? 0;
        await cacheVersion(bookId, version);
        return version;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 清除缓存（退出登录时调用）
  Future<void> clearCache(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyPrefix}$bookId');
      await prefs.remove('${_keyTimestamp}_$bookId');
    } catch (e) {
      // 忽略清除失败
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix) || key.startsWith(_keyTimestamp)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // 忽略清除失败
    }
  }
}

