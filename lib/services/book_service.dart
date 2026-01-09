import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_client.dart';
import 'auth_service.dart';

class BookService {
  final AuthService _authService = const AuthService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<String?> _getToken() async => _authService.loadToken();

  static const int _membersCacheTtlMs = 2 * 60 * 1000; // 2 min
  static final Map<String, ({int tsMs, List<Map<String, dynamic>> data})>
      _membersCache = <String, ({int tsMs, List<Map<String, dynamic>> data})>{};
  static final Map<String, Future<List<Map<String, dynamic>>>> _membersInFlight =
      <String, Future<List<Map<String, dynamic>>>>{};

  Future<String> _membersCacheKey(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id') ?? prefs.getInt('sync_owner_user_id') ?? 0;
    return 'u$uid:$bookId';
  }

  Future<void> invalidateMembersCache({String? bookId}) async {
    if (bookId == null) {
      _membersCache.clear();
      return;
    }
    _membersCache.remove(await _membersCacheKey(bookId));
  }

  Future<Map<String, dynamic>> createMultiBook(String name) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await ApiClient.instance.post(
      _uri('/api/book/create-multi'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name}),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    final bookId = data['bookId']?.toString() ?? data['id']?.toString();
    if (bookId != null && bookId.isNotEmpty) {
      // Create succeeds => creator is definitely the first member (owner).
      // Pre-fill cache to avoid an immediate members fetch right after creation.
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('auth_user_id') ?? prefs.getInt('sync_owner_user_id');
      if (uid != null && uid > 0) {
        final key = await _membersCacheKey(bookId);
        _membersCache[key] = (
          tsMs: DateTime.now().millisecondsSinceEpoch,
          data: <Map<String, dynamic>>[
            {
              'userId': uid,
              'role': 'owner',
              'status': 1,
              'joinedAt': DateTime.now().toIso8601String(),
              'nickname': null,
              'username': null,
            }
          ],
        );
      } else {
        await invalidateMembersCache(bookId: bookId);
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> refreshInviteCode(String bookId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await ApiClient.instance.post(
      _uri('/api/book/refresh-invite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'bookId': int.parse(bookId)}),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    return data;
  }

  Future<Map<String, dynamic>> joinBook(String inviteCode) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await ApiClient.instance.post(
      _uri('/api/book/join'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': inviteCode}),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = data['error'] as String? ?? '操作失败';
      throw Exception(error);
    }
    final bookId = data['bookId']?.toString() ?? data['id']?.toString();
    if (bookId != null && bookId.isNotEmpty) {
      await invalidateMembersCache(bookId: bookId);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> listBooks() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final resp = await ApiClient.instance.get(
      _uri('/api/book/list'),
      headers: {'Authorization': 'Bearer $token'},
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

  Future<List<Map<String, dynamic>>> listMembers(
    String bookId, {
    bool forceRefresh = false,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('未登录');
    }

    final bid = int.tryParse(bookId);
    if (bid == null) {
      // Local books (e.g. "default-book") don't have server-side members.
      return const [];
    }

    final key = await _membersCacheKey(bookId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh) {
      final cached = _membersCache[key];
      if (cached != null && now - cached.tsMs <= _membersCacheTtlMs) {
        return cached.data;
      }
      final inflight = _membersInFlight[key];
      if (inflight != null) return inflight;
    }

    final future = () async {
      final resp = await ApiClient.instance.get(
        _uri('/api/book/members?bookId=$bid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(resp.body);
      if (resp.statusCode >= 400) {
        final error = (data is Map<String, dynamic>)
            ? (data['error'] as String? ?? '操作失败')
            : '操作失败';
        throw Exception(error);
      }

      final out = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      _membersCache[key] = (tsMs: DateTime.now().millisecondsSinceEpoch, data: out);
      return out;
    }();

    _membersInFlight[key] = future;
    try {
      return await future;
    } finally {
      _membersInFlight.remove(key);
    }
  }

  Future<bool> isCurrentUserOwner(String bookId) async {
    final bid = int.tryParse(bookId);
    if (bid == null) return true; // local/personal books

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_user_id') ?? prefs.getInt('sync_owner_user_id') ?? 0;
    if (uid <= 0) return false;

    final members = await listMembers(bookId, forceRefresh: false);
    for (final m in members) {
      final mid = (m['userId'] as num?)?.toInt() ?? int.tryParse('${m['userId']}') ?? 0;
      final role = (m['role'] ?? '').toString();
      if (mid == uid && role == 'owner') return true;
    }
    return false;
  }
}
