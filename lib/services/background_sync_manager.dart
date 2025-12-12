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
  final Set<String> _pendingBooks = <String>{};
  bool _syncing = false;
  bool _started = false;

  void start(BuildContext context) {
    if (_started) return;
    _started = true;
    _context = context;
    WidgetsBinding.instance.addObserver(this);

    _outboxSub = SyncOutboxService.instance.onBookChanged.listen((bookId) {
      requestSync(bookId);
    });

    // 启动后先对当前账本做一次静默同步（拉取多设备变更）
    final activeBookId = context.read<BookProvider>().activeBookId;
    if (activeBookId.isNotEmpty) {
      requestSync(activeBookId);
    }
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _pendingBooks.clear();
    _outboxSub?.cancel();
    _outboxSub = null;
    WidgetsBinding.instance.removeObserver(this);
    _context = null;
    _started = false;
  }

  void requestSync(String bookId) {
    if (bookId.isEmpty) return;
    _pendingBooks.add(bookId);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _flush);
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
        await engine.syncBook(ctx, bookId);
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
          requestSync(activeBookId);
        }
      }
    }
  }
}
