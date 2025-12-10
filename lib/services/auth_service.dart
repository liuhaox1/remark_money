import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBaseUrl = 'http://localhost:8080';

class AuthResult {
  AuthResult({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      user: (json['user'] as Map).cast<String, dynamic>(),
    );
  }
}

class AuthService {
  const AuthService();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<void> sendSmsCode(String phone) async {
    final resp = await http.post(
      _uri('/api/auth/send-sms-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('发送验证码失败: ${resp.body}');
    }
  }

  Future<AuthResult> loginWithSms({
    required String phone,
    required String code,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/login/sms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (resp.statusCode >= 400) {
      throw Exception(resp.body);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await _saveToken(result.token);
    return result;
  }

  Future<AuthResult> loginWithWeChat({required String code}) async {
    final resp = await http.post(
      _uri('/api/auth/login/wechat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (resp.statusCode >= 400) {
      throw Exception(resp.body);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await _saveToken(result.token);
    return result;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// 检查 token 是否有效（永不过期，只要存在即有效）
  Future<bool> isTokenValid() async {
    final token = await loadToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// 注册：使用账号和密码注册
  Future<void> register({
    required String username,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    if (resp.statusCode >= 400) {
      final errorBody = resp.body;
      throw Exception(errorBody.isNotEmpty ? errorBody : '注册失败');
    }
  }

  /// 登录：使用账号和密码登录
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    if (resp.statusCode >= 400) {
      final errorBody = resp.body;
      throw Exception(errorBody.isNotEmpty ? errorBody : '登录失败');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await _saveToken(result.token);
    return result;
  }

  /// 假登录：用于开发测试，无需后端验证
  Future<void> mockLogin() async {
    // 直接保存一个假的 token，用于绕过登录验证
    const fakeToken = 'mock_token_for_development';
    await _saveToken(fakeToken);
  }
}

