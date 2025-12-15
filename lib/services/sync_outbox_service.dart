import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/record.dart';
import '../repository/repository_factory.dart';

enum SyncOutboxOp { upsert, delete }

class SyncOutboxItem {
  const SyncOutboxItem({
    required this.id,
    required this.bookId,
    required this.op,
    required this.payload,
    required this.createdAtMs,
  });

  final int? id; // DB 模式下有值，SharedPreferences 模式下为 null
  final String bookId;
  final SyncOutboxOp op;
  final Map<String, dynamic> payload;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'op': op.name,
        'payload': payload,
        'createdAtMs': createdAtMs,
      };

  factory SyncOutboxItem.fromJson(Map<String, dynamic> map) {
    return SyncOutboxItem(
      id: map['id'] as int?,
      bookId: map['bookId'] as String,
      op: SyncOutboxOp.values.firstWhere(
        (e) => e.name == (map['op'] as String),
        orElse: () => SyncOutboxOp.upsert,
      ),
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      createdAtMs: map['createdAtMs'] as int,
    );
  }
}

class SyncOutboxService {
  SyncOutboxService._();

  static final SyncOutboxService instance = SyncOutboxService._();

  static const String _prefsKeyPrefix = 'sync_outbox_';
  static bool _suppressed = false;
  final Random _random = Random();

  final StreamController<String> _bookChanges =
      StreamController<String>.broadcast();

  Stream<String> get onBookChanged => _bookChanges.stream;

  bool get isSuppressed => _suppressed;

  Future<T> runSuppressed<T>(Future<T> Function() action) async {
    final prev = _suppressed;
    _suppressed = true;
    try {
      return await action();
    } finally {
      _suppressed = prev;
    }
  }

  void _notifyBook(String bookId) {
    if (_bookChanges.hasListener) {
      _bookChanges.add(bookId);
    }
  }

  String _newOpId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = _random.nextInt(1 << 32);
    return '$ts-$r';
  }

  Map<String, dynamic> _recordToBillPayload(Record record, {required int updateAtMs}) {
    return {
      'localId': record.id,
      'serverId': record.serverId,
      'bookId': record.bookId,
      'accountId': record.accountId,
      'categoryKey': record.categoryKey,
      'amount': record.amount,
      'direction': record.direction == TransactionDirection.income ? 1 : 0,
      'remark': record.remark,
      'billDate': record.date.toIso8601String(),
      'includeInStats': record.includeInStats ? 1 : 0,
      'pairId': record.pairId,
      'isDelete': 0,
      // 使用本地修改时间作为 updateTime，避免“改了历史数据不同步”
      'updateTime': DateTime.fromMillisecondsSinceEpoch(updateAtMs)
          .toIso8601String(),
    };
  }

  Future<void> enqueueUpsert(Record record) async {
    if (_suppressed) return;
    if (!record.includeInStats) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'opId': _newOpId(),
      'type': 'upsert',
      'expectedVersion': record.serverVersion,
      'bill': _recordToBillPayload(record, updateAtMs: now),
    };
    await _enqueue(
      bookId: record.bookId,
      op: SyncOutboxOp.upsert,
      recordId: record.id,
      serverId: record.serverId,
      payload: payload,
      createdAtMs: now,
    );
    _notifyBook(record.bookId);
  }

  Future<void> enqueueDelete(Record record) async {
    if (_suppressed) return;
    // 未同步过的本地记录，删除无需上报服务器
    if (record.serverId == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'opId': _newOpId(),
      'type': 'delete',
      'serverId': record.serverId,
      'expectedVersion': record.serverVersion,
    };
    await _enqueue(
      bookId: record.bookId,
      op: SyncOutboxOp.delete,
      recordId: record.id,
      serverId: record.serverId,
      payload: payload,
      createdAtMs: now,
    );
    _notifyBook(record.bookId);
  }

  Future<void> _enqueue({
    required String bookId,
    required SyncOutboxOp op,
    required String? recordId,
    required int? serverId,
    required Map<String, dynamic> payload,
    required int createdAtMs,
  }) async {
    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      await db.insert(
        Tables.syncOutbox,
        {
          'book_id': bookId,
          'op': op.name,
          'record_id': recordId,
          'server_id': serverId,
          'payload': jsonEncode(payload),
          'created_at': createdAtMs,
        },
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    list.add(
      jsonEncode(
        SyncOutboxItem(
          id: null,
          bookId: bookId,
          op: op,
          payload: payload,
          createdAtMs: createdAtMs,
        ).toJson(),
      ),
    );
    await prefs.setStringList(key, list);
  }

  Future<List<SyncOutboxItem>> loadPending(String bookId, {int limit = 200}) async {
    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      final maps = await db.query(
        Tables.syncOutbox,
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      final items = <SyncOutboxItem>[];
      for (final m in maps) {
        final op = SyncOutboxOp.values.firstWhere(
          (e) => e.name == (m['op'] as String),
          orElse: () => SyncOutboxOp.upsert,
        );
        var payload =
            (jsonDecode(m['payload'] as String) as Map).cast<String, dynamic>();
        if (!payload.containsKey('opId')) {
          payload = _normalizeLegacyPayload(payload, op: op);
          final id = m['id'] as int?;
          if (id != null) {
            await db.update(
              Tables.syncOutbox,
              {'payload': jsonEncode(payload)},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
        items.add(
          SyncOutboxItem(
            id: m['id'] as int?,
            bookId: m['book_id'] as String,
            op: op,
            payload: payload,
            createdAtMs: m['created_at'] as int,
          ),
        );
      }
      return items;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    final items = <SyncOutboxItem>[];
    for (final s in list.take(limit)) {
      try {
        items.add(SyncOutboxItem.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return items;
  }

  Map<String, dynamic> _normalizeLegacyPayload(
    Map<String, dynamic> legacy, {
    required SyncOutboxOp op,
  }) {
    if (op == SyncOutboxOp.delete) {
      return {
        'opId': _newOpId(),
        'type': 'delete',
        'serverId': legacy['serverId'],
        'expectedVersion': null,
      };
    }
    return {
      'opId': _newOpId(),
      'type': 'upsert',
      'expectedVersion': null,
      'bill': legacy,
    };
  }

  Future<void> deleteItems(String bookId, List<SyncOutboxItem> items) async {
    if (items.isEmpty) return;
    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      final ids = items.map((e) => e.id).whereType<int>().toList();
      if (ids.isEmpty) return;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        Tables.syncOutbox,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    if (list.isEmpty) return;
    final removeSet = items
        .map((e) => jsonEncode(e.toJson()))
        .toSet();
    final remaining =
        list.where((s) => !removeSet.contains(s)).toList(growable: false);
    await prefs.setStringList(key, remaining);
  }
}
