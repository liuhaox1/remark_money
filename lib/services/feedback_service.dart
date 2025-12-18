import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

const String kApiBaseUrl = 'http://localhost:8080';

class FeedbackService {
  FeedbackService();

  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  Future<void> submit({
    required String content,
    String? contact,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('反馈内容不能为空');
    }

    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await http.post(
      _uri('/api/feedback/submit'),
      headers: headers,
      body: jsonEncode({
        'content': trimmed,
        if (contact != null && contact.trim().isNotEmpty) 'contact': contact.trim(),
      }),
    );

    final data = jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final error = (data is Map<String, dynamic>)
          ? (data['error'] as String? ?? '提交失败')
          : '提交失败';
      throw Exception(error);
    }

    if (data is Map<String, dynamic>) {
      final success = data['success'];
      if (success is bool && !success) {
        throw Exception(data['error'] as String? ?? '提交失败');
      }
    }
  }
}

