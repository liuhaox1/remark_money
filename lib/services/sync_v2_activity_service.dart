import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SyncV2ActivityService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> fetchActivity({
    required String bookId,
    int? beforeChangeId,
    int limit = 50,
  }) async {
    final token = await _authService.loadToken();
    if (token == null || token.isEmpty) {
      throw Exception('未登录');
    }

    final q = <String, String>{
      'bookId': bookId,
      'limit': limit.toString(),
      if (beforeChangeId != null) 'beforeChangeId': beforeChangeId.toString(),
    };
    final uri = _uri('/api/sync/v2/activity').replace(queryParameters: q);

    final resp = await ApiClient.instance.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(resp.body);
    if (data is! Map) {
      throw Exception('服务返回异常');
    }
    final out = Map<String, dynamic>.from(data as Map);
    if (resp.statusCode >= 400 || out['success'] != true) {
      throw Exception(out['error']?.toString() ?? '请求失败');
    }
    return out;
  }
}

