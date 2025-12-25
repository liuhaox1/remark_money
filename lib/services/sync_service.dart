import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

const String kApiBaseUrl = 'http://localhost:8080';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  factory SyncService() => instance;

  final AuthService _authService = const AuthService();
  final http.Client _client = http.Client();
  String? _deviceId;

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<String?> _getToken() async {
    return await _authService.loadToken();
  }

  Future<String> _getDeviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      // 生成设备ID（时间戳+随机数）
      deviceId = DateTime.now().millisecondsSinceEpoch.toString() +
          (100000 + (DateTime.now().microsecond % 900000)).toString();
      await prefs.setString('device_id', deviceId);
    }
    _deviceId = deviceId;
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
    final resp = await _client.post(
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
    final resp = await _client.get(
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
    List<Map<String, dynamic>>? deletedAccounts,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await _client.post(
      _uri('/api/sync/account/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'accounts': accounts,
        if (deletedAccounts != null && deletedAccounts.isNotEmpty)
          'deletedAccounts': deletedAccounts,
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
    final resp = await _client.get(
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

  Future<SyncResult> uploadCategories({
    required List<Map<String, dynamic>> categories,
    List<String>? deletedKeys,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await _client.post(
      _uri('/api/sync/category/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'categories': categories,
        if (deletedKeys != null && deletedKeys.isNotEmpty) 'deletedKeys': deletedKeys,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        categories: (data['categories'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            const [],
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  Future<SyncResult> downloadCategories() async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await _client.get(
      _uri('/api/sync/category/download?deviceId=$deviceId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        categories: (data['categories'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            const [],
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '下载失败');
    }
  }

  Future<SyncResult> uploadTags({
    required String bookId,
    required List<Map<String, dynamic>> tags,
    List<String>? deletedTagIds,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await _client.post(
      _uri('/api/sync/tag/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'bookId': bookId,
        'tags': tags,
        if (deletedTagIds != null && deletedTagIds.isNotEmpty) 'deletedTagIds': deletedTagIds,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        tags: (data['tags'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  Future<SyncResult> downloadTags({required String bookId}) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await _client.get(
      _uri('/api/sync/tag/download?deviceId=$deviceId&bookId=$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        tags: (data['tags'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '下载失败');
    }
  }

  Future<Map<String, dynamic>> v2Push({
    required String bookId,
    required List<Map<String, dynamic>> ops,
    String? reason,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'not logged in'};
    }

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final deviceId = await _getDeviceId();
    final resp = await _client.post(
      _uri('/api/sync/v2/push'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'X-Client-Request-Id': requestId,
        'X-Device-Id': deviceId,
        if (reason != null && reason.isNotEmpty) 'X-Sync-Reason': reason,
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
    String? reason,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'not logged in'};
    }

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final deviceId = await _getDeviceId();
    var url = '/api/sync/v2/pull?bookId=$bookId&limit=$limit';
    if (afterChangeId != null) {
      url += '&afterChangeId=$afterChangeId';
    }

    final resp = await _client.get(
      _uri(url),
      headers: {
        'Authorization': 'Bearer $token',
        'X-Client-Request-Id': requestId,
        'X-Device-Id': deviceId,
        if (reason != null && reason.isNotEmpty) 'X-Sync-Reason': reason,
      },
    );

    return (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> v2AllocateBillIds({
    required int count,
    String? reason,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'error': 'not logged in'};
    }

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final deviceId = await _getDeviceId();
    final resp = await _client.post(
      _uri('/api/sync/v2/ids/allocate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'X-Client-Request-Id': requestId,
        'X-Device-Id': deviceId,
        if (reason != null && reason.isNotEmpty) 'X-Sync-Reason': reason,
      },
      body: jsonEncode({
        'count': count,
      }),
    );

    return (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? budget;
  final List<Map<String, dynamic>>? accounts;
  final List<Map<String, dynamic>>? categories;
  final List<Map<String, dynamic>>? tags;

  SyncResult({
    required this.success,
    this.error,
    this.budget,
    this.accounts,
    this.categories,
    this.tags,
  });

  factory SyncResult.success({
    Map<String, dynamic>? budget,
    List<Map<String, dynamic>>? accounts,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? tags,
  }) {
    return SyncResult(
      success: true,
      budget: budget,
      accounts: accounts,
      categories: categories,
      tags: tags,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult(success: false, error: error);
  }
}
