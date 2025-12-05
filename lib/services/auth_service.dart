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

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}

