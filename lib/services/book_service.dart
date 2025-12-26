import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

import '../config/api_config.dart';

class BookService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  /// 创建多人账本（服务器端自增ID）
  Future<Map<String, dynamic>> createMultiBook(String name) async {
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
        'name': name,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    return data;
  }

  /// 刷新邀请码（仅多人账本）
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
        'bookId': int.parse(bookId),
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    return data;
  }

  /// 加入多人账本
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
        'code': inviteCode,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    return data;
  }

  /// 拉取服务器端多人账本列表
  Future<List<Map<String, dynamic>>> listBooks() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await http.get(
      _uri('/api/book/list'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final error = (data is Map<String, dynamic>)
          ? (data['error'] as String? ?? '操作失败')
          : '操作失败';
      throw Exception(error);
    }

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
}
