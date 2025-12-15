import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/book_provider.dart';
import 'sync_engine.dart';
import 'sync_outbox_service.dart';

class BackgroundSyncManager with WidgetsBindingObserver {
  BackgroundSyncManager._();

  static final BackgroundSyncManager instance = BackgroundSyncManager._();

  BuildContext? _context;
  StreamSubscription<String>? _outboxSub;
  Timer? _debounce;
  Timer? _metaDebounce;
  Timer? _pollTimer;
  final Set<String> _pendingBooks = <String>{};
  final Map<String, String> _pendingReasonsByBook = <String, String>{};
  bool _syncing = false;
  bool _started = false;
  int _lastMetaSyncMs = 0;
  final Map<String, int> _lastSyncMsByBook = <String, int>{};

  // 关键：默认关闭前台轮询，避免无意义的频繁 SQL/HTTP；多人实时性后续可用 SSE/WebSocket 替代。
  static const bool _enableForegroundPolling = false;

  void start(BuildContext context) {
    if (_started) return;
    _started = true;
    _context = context;
    WidgetsBinding.instance.addObserver(this);

    _outboxSub = SyncOutboxService.instance.onBookChanged.listen((bookId) {
      requestSync(bookId, reason: 'local_outbox_changed');
    });

    // 启动后先对当前账本做一次静默同步（拉取多设备变更）
    final activeBookId = context.read<BookProvider>().activeBookId;
    if (activeBookId.isNotEmpty) {
      requestSync(activeBookId, reason: 'app_start');
      requestMetaSync(activeBookId, reason: 'app_start');
    }

    if (_enableForegroundPolling) {
      _startPollTimer();
    }
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _metaDebounce?.cancel();
    _metaDebounce = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingBooks.clear();
    _pendingReasonsByBook.clear();
    _outboxSub?.cancel();
    _outboxSub = null;
    WidgetsBinding.instance.removeObserver(this);
    _context = null;
    _started = false;
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final ctx = _context;
      if (ctx == null) return;
      final activeBookId = ctx.read<BookProvider>().activeBookId;
      if (activeBookId.isNotEmpty) {
        requestSync(activeBookId, reason: 'poll_20s');
      }
    });
  }

  void requestSync(String bookId, {String reason = 'unknown'}) {
    if (bookId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSyncMsByBook[bookId] ?? 0;
    // 防抖后还需要兜底限频：避免短时间多处触发重复同步
    if (reason != 'local_outbox_changed' && now - last < 15 * 1000) {
      return;
    }
    _pendingBooks.add(bookId);
    _pendingReasonsByBook[bookId] = reason;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _flush);
  }

  void requestMetaSync(String bookId, {String reason = 'unknown'}) {
    if (bookId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 元数据同步限频：至少间隔 10 分钟，避免账户同步造成大量 SQL
    if (now - _lastMetaSyncMs < 10 * 60 * 1000) return;
    _metaDebounce?.cancel();
    _metaDebounce = Timer(const Duration(seconds: 2), () async {
      final ctx = _context;
      if (ctx == null || _syncing) return;
      _syncing = true;
      try {
        debugPrint('[BackgroundSyncManager] meta sync book=$bookId reason=$reason');
        await SyncEngine().syncMeta(ctx, bookId, reason: reason);
        _lastMetaSyncMs = DateTime.now().millisecondsSinceEpoch;
      } catch (e) {
        debugPrint('[BackgroundSyncManager] meta sync failed: $e');
      } finally {
        _syncing = false;
      }
    });
  }

  Future<void> _flush() async {
    final ctx = _context;
    if (ctx == null) return;
    if (_syncing) return;
    if (_pendingBooks.isEmpty) return;
    _syncing = true;

    try {
      final engine = SyncEngine();
      final books = _pendingBooks.toList(growable: false);
      _pendingBooks.clear();
      for (final bookId in books) {
        final reason = _pendingReasonsByBook.remove(bookId) ?? 'unknown';
        debugPrint('[BackgroundSyncManager] sync book=$bookId reason=$reason');
        await engine.syncBookV2(ctx, bookId, reason: reason);
        _lastSyncMsByBook[bookId] = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('[BackgroundSyncManager] sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 前台唤醒时对当前账本做一次静默同步（拉取多设备变更）
      final ctx = _context;
      if (ctx != null) {
        final activeBookId = ctx.read<BookProvider>().activeBookId;
        if (activeBookId.isNotEmpty) {
          requestSync(activeBookId, reason: 'app_resumed');
          requestMetaSync(activeBookId, reason: 'app_resumed');
        }
      }
      if (_enableForegroundPolling) {
        _startPollTimer();
      }
    }
  }
}
