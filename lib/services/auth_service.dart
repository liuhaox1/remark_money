import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

const String kApiBaseUrl = 'http://localhost:8080';

/// 注册异常，用于提供友好的错误提示
class RegisterException implements Exception {
  RegisterException(this.message);
  final String message;
  @override
  String toString() => message;
}

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

  Future<void> _clearSyncV2LocalState(SharedPreferences prefs) async {
    final keys = prefs.getKeys().toList(growable: false);
    for (final k in keys) {
      if (k.startsWith('sync_v2_last_change_id_') ||
          k.startsWith('sync_v2_conflicts_') ||
          k.startsWith('sync_v2_summary_checked_at_') ||
          k.startsWith('sync_outbox_') ||
          k.startsWith('data_version_') ||
          k.startsWith('budget_update_time_') ||
          k.startsWith('budget_local_edit_ms_') ||
          k.startsWith('budget_server_update_ms_') ||
          k.startsWith('budget_server_sync_version_') ||
          k.startsWith('budget_local_base_sync_version_') ||
          k.startsWith('budget_conflict_backup_')) {
        await prefs.remove(k);
      }
    }

    // Best-effort: clear DB outbox to avoid cross-account pushes.
    try {
      final db = await DatabaseHelper().database;
      await db.delete(Tables.syncOutbox);
    } catch (_) {}
  }

  Future<void> _saveAuth({required String token, int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final prevUserId = prefs.getInt('auth_user_id');

    // 仅在“账号变化”时清理 v2 游标/冲突，避免同账号重新登录（token 变化）导致全量重拉。
    if (prevUserId != null && userId != null && prevUserId != userId) {
      await _clearSyncV2LocalState(prefs);
    }

    await prefs.setString('auth_token', token);
    if (userId != null) {
      await prefs.setInt('auth_user_id', userId);
    }
  }

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
    await _saveAuth(
      token: result.token,
      userId: (result.user['id'] as num?)?.toInt(),
    );
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
    await _saveAuth(
      token: result.token,
      userId: (result.user['id'] as num?)?.toInt(),
    );
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
  /// 注意：假登录的 token 不被认为是有效的
  Future<bool> isTokenValid() async {
    final token = await loadToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    // 假登录的 token 不被认为是有效的
    if (token == 'mock_token_for_development') {
      return false;
    }
    return true;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user_id');
    await _clearSyncV2LocalState(prefs);
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
      final errorBody = resp.body.trim();
      // 解析错误消息，提供友好的提示
      if (errorBody.contains('账号已存在') || 
          errorBody.contains('用户名已存在') ||
          errorBody.contains('username already exists')) {
        throw RegisterException('该账号已被注册，请使用其他账号或直接登录');
      }
      throw RegisterException(errorBody.isNotEmpty ? errorBody : '注册失败，请稍后再试');
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
    await _saveAuth(
      token: result.token,
      userId: (result.user['id'] as num?)?.toInt(),
    );
    return result;
  }

  /// 假登录：用于开发测试，无需后端验证
  Future<void> mockLogin() async {
    // 直接保存一个假的 token，用于绕过登录验证
    const fakeToken = 'mock_token_for_development';
    await _saveToken(fakeToken);
  }
}
