import 'package:http/http.dart' as http;

import 'auth_event_bus.dart';
import 'auth_store.dart';
import 'network_guard.dart';

/// Shared HTTP client wrapper:
/// - Reuses a single [http.Client] across the app.
/// - Centralizes 401 handling (clear token + notify UI).
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final resp = await guardedGet(
      _client,
      uri,
      headers: headers,
      timeout: timeout ?? kNetworkTimeout,
    );
    await _handleUnauthorized(resp);
    return resp;
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final resp = await guardedPost(
      _client,
      uri,
      headers: headers,
      body: body,
      timeout: timeout ?? kNetworkTimeout,
    );
    await _handleUnauthorized(resp);
    return resp;
  }

  Future<void> _handleUnauthorized(http.Response resp) async {
    if (resp.statusCode != 401) return;
    try {
      await clearAuthTokenAndLocalSyncState();
    } catch (_) {}
    AuthEventBus.instance.notifyUnauthorized();
    throw NetworkException('登录已失效，请重新登录');
  }
}
