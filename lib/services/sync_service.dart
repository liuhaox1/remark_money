import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

const String kApiBaseUrl = 'http://localhost:8080';

class SyncService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      // 生成设备ID（时间戳+随机数）
      deviceId = DateTime.now().millisecondsSinceEpoch.toString() +
          (100000 + (DateTime.now().microsecond % 900000)).toString();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// 上传预算数据
  Future<SyncResult> uploadBudget({
    required String bookId,
    required Map<String, dynamic> budgetData,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.post(
      _uri('/api/sync/budget/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'bookId': bookId,
        'budget': budgetData,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success();
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  /// 下载预算数据
  Future<SyncResult> downloadBudget({required String bookId}) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.get(
      _uri('/api/sync/budget/download?deviceId=$deviceId&bookId=$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        budget: data['budget'] as Map<String, dynamic>?,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '下载失败');
    }
  }

  /// 上传账户数据
  Future<SyncResult> uploadAccounts({
    required List<Map<String, dynamic>> accounts,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.post(
      _uri('/api/sync/account/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'accounts': accounts,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      // 返回处理后的账户列表（包含服务器ID）
      final processedAccounts = (data['accounts'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];
      return SyncResult.success(accounts: processedAccounts);
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  /// 下载账户数据
  Future<SyncResult> downloadAccounts() async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.get(
      _uri('/api/sync/account/download?deviceId=$deviceId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        accounts: (data['accounts'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ?? [],
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '下载失败');
    }
  }

  Future<Map<String, dynamic>> v2Push({
    required String bookId,
    required List<Map<String, dynamic>> ops,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'not logged in'};
    }

    final resp = await http.post(
      _uri('/api/sync/v2/push'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bookId': bookId,
        'ops': ops,
      }),
    );

    return (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> v2Pull({
    required String bookId,
    int? afterChangeId,
    int limit = 200,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'not logged in'};
    }

    var url = '/api/sync/v2/pull?bookId=$bookId&limit=$limit';
    if (afterChangeId != null) {
      url += '&afterChangeId=$afterChangeId';
    }

    final resp = await http.get(
      _uri(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? budget;
  final List<Map<String, dynamic>>? accounts;

  SyncResult({
    required this.success,
    this.error,
    this.budget,
    this.accounts,
  });

  factory SyncResult.success({
    Map<String, dynamic>? budget,
    List<Map<String, dynamic>>? accounts,
  }) {
    return SyncResult(
      success: true,
      budget: budget,
      accounts: accounts,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult(success: false, error: error);
  }
}
