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
    if (env.isNotEmpty && !_isLocalhost(env)) {
      return env;
    }
    // If someone accidentally passes `localhost` via `--dart-define` on a
    // phone build, ignore it to avoid "no response" UX.
    return _defaultBaseUrl;
  }

  static bool _isLocalhost(String url) {
    final u = url.toLowerCase();
    return u.contains('://localhost') || u.contains('://127.0.0.1');
  }

  static String get _defaultBaseUrl {
    const prod = 'http://115.190.162.10:8080';

    if (kReleaseMode) return prod;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        // On real devices, `localhost` points to the phone itself, so it will
        // always fail unless you're running a server on-device. Default to prod.
        return prod;
      default:
        return prod;
    }
  }
}
