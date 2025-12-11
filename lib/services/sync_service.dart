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

  /// 全量上传
  Future<SyncResult> fullUpload({
    required String bookId,
    required List<Map<String, dynamic>> bills,
    required int batchNum,
    required int totalBatches,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.post(
      _uri('/api/sync/full/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'bookId': bookId,
        'batchNum': batchNum,
        'totalBatches': totalBatches,
        'bills': bills,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        successCount: data['successCount'] as int? ?? 0,
        skipCount: data['skipCount'] as int? ?? 0,
        bills: (data['bills'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList(),
        syncRecord: data['syncRecord'] != null
            ? SyncRecord.fromJson(data['syncRecord'] as Map<String, dynamic>)
            : null,
        quotaWarning: data['quotaWarning'] as String?,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  /// 全量拉取
  Future<SyncResult> fullDownload({
    required String bookId,
    int offset = 0,
    int limit = 100,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.get(
      _uri('/api/sync/full/download?deviceId=$deviceId&bookId=$bookId&offset=$offset&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        bills: (data['bills'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        syncRecord: data['syncRecord'] != null
            ? SyncRecord.fromJson(data['syncRecord'] as Map<String, dynamic>)
            : null,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '拉取失败');
    }
  }

  /// 增量上传
  Future<SyncResult> incrementalUpload({
    required String bookId,
    required List<Map<String, dynamic>> bills,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.post(
      _uri('/api/sync/increment/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'bookId': bookId,
        'bills': bills,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        successCount: data['successCount'] as int? ?? 0,
        skipCount: data['skipCount'] as int? ?? 0,
        bills: (data['bills'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList(),
        syncRecord: data['syncRecord'] != null
            ? SyncRecord.fromJson(data['syncRecord'] as Map<String, dynamic>)
            : null,
        quotaWarning: data['quotaWarning'] as String?,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '上传失败');
    }
  }

  /// 增量拉取
  Future<SyncResult> incrementalDownload({
    required String bookId,
    String? lastSyncTime,
    String? lastSyncBillId,
    int offset = 0,
    int limit = 100,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    var url = '/api/sync/increment/download?deviceId=$deviceId&bookId=$bookId&offset=$offset&limit=$limit';
    if (lastSyncTime != null) {
      url += '&lastSyncTime=$lastSyncTime';
    }
    if (lastSyncBillId != null) {
      url += '&lastSyncBillId=$lastSyncBillId';
    }

    final resp = await http.get(
      _uri(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        bills: (data['bills'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        syncRecord: data['syncRecord'] != null
            ? SyncRecord.fromJson(data['syncRecord'] as Map<String, dynamic>)
            : null,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '拉取失败');
    }
  }

  /// 查询同步状态
  Future<SyncResult> queryStatus({required String bookId}) async {
    final token = await _getToken();
    if (token == null) {
      return SyncResult.error('未登录');
    }

    final deviceId = await _getDeviceId();
    final resp = await http.get(
      _uri('/api/sync/status/query?deviceId=$deviceId&bookId=$bookId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return SyncResult.success(
        syncRecord: data['syncRecord'] != null
            ? SyncRecord.fromJson(data['syncRecord'] as Map<String, dynamic>)
            : null,
        userInfo: data['user'] as Map<String, dynamic>?,
      );
    } else {
      return SyncResult.error(data['error'] as String? ?? '查询失败');
    }
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
      return SyncResult.success();
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
}

class SyncRecord {
  final int? userId;
  final String? bookId;
  final String? deviceId;
  final String? lastSyncBillId;
  final String? lastSyncTime;
  final int? cloudBillCount;
  final String? syncDeviceId;
  final int? dataVersion;

  SyncRecord({
    this.userId,
    this.bookId,
    this.deviceId,
    this.lastSyncBillId,
    this.lastSyncTime,
    this.cloudBillCount,
    this.syncDeviceId,
    this.dataVersion,
  });

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    return SyncRecord(
      userId: json['userId'] as int?,
      bookId: json['bookId'] as String?,
      deviceId: json['deviceId'] as String?,
      lastSyncBillId: json['lastSyncBillId'] as String?,
      lastSyncTime: json['lastSyncTime'] as String?,
      cloudBillCount: json['cloudBillCount'] as int?,
      syncDeviceId: json['syncDeviceId'] as String?,
      dataVersion: json['dataVersion'] as int?,
    );
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final List<Map<String, dynamic>>? bills;
  final SyncRecord? syncRecord;
  final Map<String, dynamic>? userInfo;
  final int? successCount;
  final int? skipCount;
  final bool? hasMore;
  final String? quotaWarning;
  final Map<String, dynamic>? budget;
  final List<Map<String, dynamic>>? accounts;

  SyncResult({
    required this.success,
    this.error,
    this.bills,
    this.syncRecord,
    this.userInfo,
    this.successCount,
    this.skipCount,
    this.hasMore,
    this.quotaWarning,
    this.budget,
    this.accounts,
  });

  factory SyncResult.success({
    List<Map<String, dynamic>>? bills,
    SyncRecord? syncRecord,
    Map<String, dynamic>? userInfo,
    int? successCount,
    int? skipCount,
    bool? hasMore,
    String? quotaWarning,
    Map<String, dynamic>? budget,
    List<Map<String, dynamic>>? accounts,
  }) {
    return SyncResult(
      success: true,
      bills: bills,
      syncRecord: syncRecord,
      userInfo: userInfo,
      successCount: successCount,
      skipCount: skipCount,
      hasMore: hasMore,
      quotaWarning: quotaWarning,
      budget: budget,
      accounts: accounts,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult(success: false, error: error);
  }
}

