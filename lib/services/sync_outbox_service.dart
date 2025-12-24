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

    final now = DateTime.now().millisecondsSinceEpoch;
    // v2 语义：
    // - 新建（serverId 为空）：expectedVersion = null
    // - 已同步（serverId+serverVersion）：expectedVersion = serverVersion
    // - 预分配 serverId 但尚未落库（serverId != null 且仍是本地 id）：expectedVersion = 0（走批量新增）
    final expectedVersion = record.serverVersion ??
        ((record.serverId != null && !record.id.startsWith('server_')) ? 0 : null);
    final payload = {
      'opId': _newOpId(),
      'type': 'upsert',
      'expectedVersion': expectedVersion,
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

    // Delete for unsynced local records should not be uploaded, but we must remove any pending upsert,
    // otherwise a previously-enqueued create/update could be pushed after the local deletion.
    await _removePendingUpsertsForRecord(bookId: record.bookId, recordId: record.id);
    // 未同步过的本地记录，删除无需上报服务器
    if (record.serverId == null) return;

    // Keep only the latest delete for this serverId to reduce outbox bloat / conflicts.
    await _removePendingDeletesForServerId(
      bookId: record.bookId,
      serverId: record.serverId!,
    );

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
      // 只保留同一条记录最新的 upsert：避免本地多次编辑造成 outbox 膨胀
      if (op == SyncOutboxOp.upsert && recordId != null && recordId.isNotEmpty) {
        await db.delete(
          Tables.syncOutbox,
          where: 'book_id = ? AND op = ? AND record_id = ?',
          whereArgs: [bookId, op.name, recordId],
        );
      }
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
    if (op == SyncOutboxOp.upsert && recordId != null && recordId.isNotEmpty) {
      list.removeWhere((s) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          final item = SyncOutboxItem.fromJson(map);
          if (item.op != SyncOutboxOp.upsert) return false;
          final bill = (item.payload['bill'] as Map?)?.cast<String, dynamic>();
          return bill != null && bill['localId'] == recordId;
        } catch (_) {
          return false;
        }
      });
    }
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

  Future<void> updateItems(String bookId, List<SyncOutboxItem> items) async {
    if (items.isEmpty) return;
    final byOpId = <String, SyncOutboxItem>{};
    for (final it in items) {
      final opId = it.payload['opId'] as String?;
      if (opId != null) byOpId[opId] = it;
    }
    if (byOpId.isEmpty) return;

    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final it in items) {
          final id = it.id;
          if (id == null) continue;
          final bill = (it.payload['bill'] as Map?)?.cast<String, dynamic>();
          final serverId =
              it.payload['serverId'] as int? ?? (bill?['serverId'] as int?);
          batch.update(
            Tables.syncOutbox,
            {
              'payload': jsonEncode(it.payload),
              'server_id': serverId,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    final updated = <String>[];
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final item = SyncOutboxItem.fromJson(map);
        final opId = item.payload['opId'] as String?;
        final replacement = opId != null ? byOpId[opId] : null;
        if (replacement != null) {
          updated.add(jsonEncode(replacement.toJson()));
        } else {
          updated.add(s);
        }
      } catch (_) {
        updated.add(s);
      }
    }
    await prefs.setStringList(key, updated);
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

  Future<void> _removePendingUpsertsForRecord({
    required String bookId,
    required String recordId,
  }) async {
    if (bookId.isEmpty || recordId.isEmpty) return;

    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      await db.delete(
        Tables.syncOutbox,
        where: 'book_id = ? AND op = ? AND record_id = ?',
        whereArgs: [bookId, SyncOutboxOp.upsert.name, recordId],
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    if (list.isEmpty) return;

    list.removeWhere((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final item = SyncOutboxItem.fromJson(map);
        if (item.op != SyncOutboxOp.upsert) return false;
        final bill = (item.payload['bill'] as Map?)?.cast<String, dynamic>();
        return bill != null && bill['localId'] == recordId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(key, list);
  }

  Future<void> _removePendingDeletesForServerId({
    required String bookId,
    required int serverId,
  }) async {
    if (bookId.isEmpty) return;

    if (RepositoryFactory.isUsingDatabase) {
      final db = await DatabaseHelper().database;
      await db.delete(
        Tables.syncOutbox,
        where: 'book_id = ? AND op = ? AND server_id = ?',
        whereArgs: [bookId, SyncOutboxOp.delete.name, serverId],
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$bookId';
    final list = prefs.getStringList(key) ?? <String>[];
    if (list.isEmpty) return;

    list.removeWhere((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final item = SyncOutboxItem.fromJson(map);
        if (item.op != SyncOutboxOp.delete) return false;
        return (item.payload['serverId'] as int?) == serverId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(key, list);
  }
}
