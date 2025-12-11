import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String kApiBaseUrl = 'http://localhost:8080';

class BookService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  /// 升级为多人账本
  Future<Map<String, dynamic>> createMultiBook(String bookId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await http.post(
      _uri('/api/book/create-multi'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bookId': bookId,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }

    return data;
  }

  /// 刷新邀请码
  Future<Map<String, dynamic>> refreshInviteCode(String bookId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await http.post(
      _uri('/api/book/refresh-invite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bookId': bookId,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }

    return data;
  }

  /// 加入账本
  Future<Map<String, dynamic>> joinBook(String inviteCode) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await http.post(
      _uri('/api/book/join'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inviteCode': inviteCode,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }

    return data;
  }
}

