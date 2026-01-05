import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// API base URL.
  ///
  /// Priority:
  /// 1) `--dart-define=API_BASE_URL=...`
  /// 2) Default:
  ///    - Release: production
  ///    - Debug/Profile: production on iOS/Android (phone can't reach localhost),
  ///      localhost on desktop
  static String get baseUrl {
    final env = _envBaseUrl.trim();
    if (env.isNotEmpty) {
      // Allow localhost override on desktop/web dev, but prevent accidental
      // localhost on real devices (where localhost points to the phone).
      if (_isLocalhost(env) && _isMobile) {
        return _defaultBaseUrl;
      }
      return env;
    }
    return _defaultBaseUrl;
  }

  static bool _isLocalhost(String url) {
    final u = url.toLowerCase();
    return u.contains('://localhost') || u.contains('://127.0.0.1');
  }

  static String get _defaultBaseUrl {
    const devLocal = 'http://localhost:8080';
    const prod = 'http://115.190.162.10:8080';

    if (kReleaseMode) return prod;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        // On real devices, `localhost` points to the phone itself, so it will
        // always fail unless you're running a server on-device. Default to prod.
        return prod;
      default:
        // Desktop dev defaults to localhost.
        return devLocal;
    }
  }

  static bool get _isMobile {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      default:
        return false;
    }
  }
}
