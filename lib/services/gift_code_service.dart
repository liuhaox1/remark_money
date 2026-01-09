import 'dart:convert';
import 'auth_service.dart';

import '../config/api_config.dart';
import 'api_client.dart';

class GiftCodeService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  /// 兑换礼包码
  /// 
  /// [code] 8位礼包码
  /// 返回兑换结果，包含新的付费到期时间
  Future<GiftCodeRedeemResult> redeem(String code) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录，请先登录');
    }

    // 验证礼包码格式
    if (code.length != 8 || !RegExp(r'^[0-9]{8}$').hasMatch(code)) {
      throw Exception('礼包码格式不正确，请输入8位数字');
    }

    final resp = await ApiClient.instance.post(
      _uri('/api/gift/redeem'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '兑换失败';
      throw Exception(error);
    }

    if (data['success'] == true) {
      return GiftCodeRedeemResult(
        success: true,
        message: data['message'] as String? ?? '兑换成功',
        payExpire: data['payExpire'] != null 
            ? DateTime.parse(data['payExpire'] as String)
            : null,
        payType: data['payType'] as int? ?? 1,
      );
    } else {
      final error = data['error'] as String? ?? '兑换失败';
      throw Exception(error);
    }
  }
}

/// 礼包码兑换结果
class GiftCodeRedeemResult {
  final bool success;
  final String message;
  final DateTime? payExpire;
  final int payType;

  GiftCodeRedeemResult({
    required this.success,
    required this.message,
    this.payExpire,
    this.payType = 1,
  });
}

