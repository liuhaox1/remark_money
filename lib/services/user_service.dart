import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> updateMyNickname(String nickname) async {
    final token = await _authService.loadToken();
    if (token == null) {
      throw Exception('未登录');
    }
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      throw Exception('昵称不能为空');
    }
    if (trimmed.length > 20) {
      throw Exception('昵称最多20个字符');
    }

    final resp = await ApiClient.instance.post(
      _uri('/api/users/me/nickname'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nickname': trimmed}),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final error = (data is Map<String, dynamic>)
          ? (data['error'] as String? ?? '更新失败')
          : '更新失败';
      throw Exception(error);
    }
    if (data is Map<String, dynamic>) return data;
    return const {'success': true};
  }
}

