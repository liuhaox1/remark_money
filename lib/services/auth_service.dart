import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBaseUrl = 'http://localhost:8080';

// Token 过期时间：30天（可根据需求调整）
const Duration kTokenExpirationDuration = Duration(days: 30);

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
    // 保存 token 的时间戳，用于检查过期
    await prefs.setInt('auth_token_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;
    
    // 检查 token 是否过期
    final timestamp = prefs.getInt('auth_token_timestamp');
    if (timestamp == null) {
      // 如果没有时间戳，清除旧 token（兼容旧数据）
      await clearToken();
      return null;
    }
    
    final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (now.difference(savedTime) > kTokenExpirationDuration) {
      // Token 已过期，清除
      await clearToken();
      return null;
    }
    
    return token;
  }

  /// 检查 token 是否有效（未过期）
  Future<bool> isTokenValid() async {
    final token = await loadToken();
    return token != null;
  }

  /// 获取 token 剩余有效时间
  Future<Duration?> getTokenRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('auth_token_timestamp');
    if (timestamp == null) return null;
    
    final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final elapsed = now.difference(savedTime);
    final remaining = kTokenExpirationDuration - elapsed;
    
    return remaining.isNegative ? null : remaining;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_token_timestamp');
  }
}

