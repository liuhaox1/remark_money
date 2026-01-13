import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/tag_provider.dart';
import 'account_delete_queue.dart';
import 'budget_sync_state_store.dart';
import 'category_delete_queue.dart';
import 'meta_sync_state_store.dart';
import 'savings_plan_delete_queue.dart';
import 'tag_delete_queue.dart';
import 'meta_sync_notifier.dart';
import 'sync_engine.dart';
import 'sync_outbox_service.dart';
import 'auth_service.dart';

class BackgroundSyncManager with WidgetsBindingObserver {
  BackgroundSyncManager._();

  static final BackgroundSyncManager instance = BackgroundSyncManager._();

  BuildContext? _context;
  BookProvider? _bookProvider;
  StreamSubscription<String>? _outboxSub;
  StreamSubscription<String>? _accountsSub;
  StreamSubscription<String>? _budgetSub;
  StreamSubscription<void>? _categoriesSub;
  StreamSubscription<String>? _tagsSub;
  StreamSubscription<String>? _savingsPlansSub;
  Timer? _debounce;
  Timer? _metaDebounce;
  Timer? _periodicPullTimer;
  final Set<String> _pendingBooks = <String>{};
  final Map<String, String> _pendingReasonsByBook = <String, String>{};
  final Set<String> _pendingMetaBooks = <String>{};
  final Map<String, String> _pendingMetaReasonsByBook = <String, String>{};
  bool _syncing = false;
  bool _started = false;
  bool _skipNextAppStartSync = false;
  int _lastMetaSyncMs = 0;
  final Map<String, int> _lastAccountsSyncMsByBook = <String, int>{};
  final Map<String, int> _lastUserMetaSyncMsByBook = <String, int>{};
  final Map<String, int> _lastSyncMsByBook = <String, int>{};
  int _lastPausedAtMs = 0;
  final Map<String, int> _pullBackoffExpByBook = <String, int>{};

  // 关键：减少无意义的同步触发（尤其是桌面端/部分机型会频繁触发 resumed）。
  // 多人账本的“实时性”后续用 SSE/WebSocket 来做；当前版本优先保证性能与稳定。
  static const int _resumeMinIntervalMs = 5 * 60 * 1000; // 5min
  static const int _resumeMinBackgroundMs = 30 * 1000; // 30s
  static const int _periodicPullIntervalMs = 3 * 60 * 1000; // 3min
  // Foreground "freshness" cap: ensure other-device changes become visible within a bounded window.
  // Actual network pull is further reduced by SyncEngine's no-change cooldown.
  static const int _periodicPullMaxIntervalMs = 5 * 60 * 1000; // 5min
  static const int _metaPeriodicIntervalMs = 60 * 60 * 1000; // 60min

  void start(BuildContext context, {bool triggerInitialSync = true}) {
    if (_started) {
      // Rebind to the latest context (e.g., after login navigation) to avoid
      // holding a disposed context that lacks providers.
      _context = context;
      _bookProvider = context.read<BookProvider>();
      return;
    }
    _started = true;
    _context = context;
    _bookProvider = context.read<BookProvider>();
    WidgetsBinding.instance.addObserver(this);

    _outboxSub = SyncOutboxService.instance.onBookChanged.listen((bookId) {
      requestSync(bookId, reason: 'local_outbox_changed');
    });

    _accountsSub = MetaSyncNotifier.instance.onAccountsChanged.listen((bookId) {
      requestMetaSync(bookId, reason: 'accounts_changed');
    });

    _budgetSub = MetaSyncNotifier.instance.onBudgetChanged.listen((bookId) {
      requestMetaSync(bookId, reason: 'budget_changed');
    });

    _categoriesSub =
        MetaSyncNotifier.instance.onCategoriesChanged.listen((bookId) {
      if (bookId.isEmpty) return;
      requestMetaSync(bookId, reason: 'categories_changed');
    });

    _tagsSub = MetaSyncNotifier.instance.onTagsChanged.listen((bookId) {
      requestMetaSync(bookId, reason: 'tags_changed');
    });

    _savingsPlansSub =
        MetaSyncNotifier.instance.onSavingsPlansChanged.listen((bookId) {
      requestMetaSync(bookId, reason: 'savings_plans_changed');
    });

    if (triggerInitialSync) {
      // 启动后先对当前账本做一次静默同步（拉取多设备变更）
      final activeBookId = context.read<BookProvider>().activeBookId;
      if (activeBookId.isNotEmpty) {
        // Guest mode (no token) should not keep retrying network sync on startup.
        // Login flows will explicitly trigger a sync/meta sync once the token is persisted.
        () async {
          // If login just happened, skip the pending app_start sync to avoid duplicate SQL.
          if (_skipNextAppStartSync) {
            _skipNextAppStartSync = false;
            return;
          }
          final ok = await const AuthService().isTokenValid();
          if (!ok) return;
          requestSync(activeBookId, reason: 'app_start');
          // Also sync meta (budget/accounts/categories/tags/etc.) so pages won't show empty data after login,
          // but skip when local meta is warm and no pending local changes.
          if (await _shouldAppStartMetaSync(activeBookId, context)) {
            requestMetaSync(activeBookId, reason: 'app_start');
          }
        }();
      }
    }
    _startPeriodicPullTimer();
  }

  /// Called after a successful login to suppress an in-flight app_start sync that may still be pending.
  void markLoggedIn() {
    _skipNextAppStartSync = true;
  }

  void _startPeriodicPullTimer() {
    _periodicPullTimer?.cancel();
    _scheduleNextPeriodicPull(delayMs: _periodicPullIntervalMs);
  }

  void _scheduleNextPeriodicPull({required int delayMs}) {
    _periodicPullTimer?.cancel();
    _periodicPullTimer = Timer(Duration(milliseconds: delayMs), () {
      final ctx = _context;
      if (ctx == null) {
        _scheduleNextPeriodicPull(delayMs: _periodicPullIntervalMs);
        return;
      }
      final bookId = ctx.read<BookProvider>().activeBookId;
      if (bookId.isNotEmpty) {
        requestSync(bookId, reason: 'periodic_pull');

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastMetaSyncMs > _metaPeriodicIntervalMs) {
          requestMetaSync(bookId, reason: 'meta_periodic');
        }
      }

      final nextDelay = _nextPeriodicPullDelayMs(bookId);
      _scheduleNextPeriodicPull(delayMs: nextDelay);
    });
  }

  int _nextPeriodicPullDelayMs(String bookId) {
    if (bookId.isEmpty) return _periodicPullIntervalMs;

    final lastPullMs = SyncEngine.lastPullMsForBook(bookId);
    final advanced = SyncEngine.lastPullAdvancedForBook(bookId);
    var exp = _pullBackoffExpByBook[bookId] ?? 0;

    if (advanced) {
      exp = 0;
    } else if (lastPullMs > 0) {
      exp = (exp + 1).clamp(0, 10);
    }
    _pullBackoffExpByBook[bookId] = exp;

    final scaled = _periodicPullIntervalMs * (1 << exp);
    if (scaled <= _periodicPullIntervalMs) return _periodicPullIntervalMs;
    if (scaled >= _periodicPullMaxIntervalMs) return _periodicPullMaxIntervalMs;
    return scaled;
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _metaDebounce?.cancel();
    _metaDebounce = null;
    _periodicPullTimer?.cancel();
    _periodicPullTimer = null;
    _pendingBooks.clear();
    _pendingReasonsByBook.clear();
    _pendingMetaBooks.clear();
    _pendingMetaReasonsByBook.clear();
    _bookProvider = null;
    _pullBackoffExpByBook.clear();
    _outboxSub?.cancel();
    _outboxSub = null;
    _accountsSub?.cancel();
    _accountsSub = null;
    _budgetSub?.cancel();
    _budgetSub = null;
    _categoriesSub?.cancel();
    _categoriesSub = null;
    _tagsSub?.cancel();
    _tagsSub = null;
    _savingsPlansSub?.cancel();
    _savingsPlansSub = null;
    WidgetsBinding.instance.removeObserver(this);
    _context = null;
    _started = false;
  }

  void requestSync(String bookId, {String reason = 'unknown'}) {
    if (bookId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSyncMsByBook[bookId] ?? 0;
    // 防抖后还需要兜底限频：避免短时间多处触发重复同步
    if (reason == 'app_resumed' && now - last < _resumeMinIntervalMs) {
      return;
    }
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
    // 元数据同步限频：
    // - accounts_changed：用户在资产页修改后希望尽快上云，但要做节流/防抖
    // - 其他原因：至少间隔 10 分钟，避免频繁 SQL
    if (reason == 'login' || reason == 'force_bootstrap') {
      // Always allow an immediate meta sync after login/bootstrap.
    } else if (reason == 'accounts_changed') {
      final last = _lastAccountsSyncMsByBook[bookId] ?? 0;
      if (now - last < 8 * 1000) return;
    } else if (reason == 'budget_changed' ||
        reason == 'categories_changed' ||
        reason == 'tags_changed' ||
        reason == 'savings_plans_changed') {
      final last = _lastUserMetaSyncMsByBook[bookId] ?? 0;
      if (now - last < 8 * 1000) return;
    } else {
      if (now - _lastMetaSyncMs < 10 * 60 * 1000) return;
    }
    _pendingMetaBooks.add(bookId);
    _pendingMetaReasonsByBook[bookId] = reason;
    _scheduleMetaFlush();
  }

  void _scheduleMetaFlush() {
    _metaDebounce?.cancel();
    _metaDebounce = Timer(const Duration(seconds: 2), _flushMeta);
  }

  Future<bool> _shouldAppStartMetaSync(String bookId, BuildContext context) async {
    if (bookId.isEmpty) return false;
    if (!_isMetaWarm(bookId, context)) return true;
    if (await _hasLocalMetaChanges(bookId, context)) return true;
    final last = await MetaSyncStateStore.getLastMetaSyncMs(bookId);
    if (last <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - last > _metaPeriodicIntervalMs;
  }

  bool _isMetaWarm(String bookId, BuildContext context) {
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();
    final hasCategories = categoryProvider.hasCategoriesForBook(bookId);
    final hasAccounts = accountProvider.hasAccountsForBook(bookId);
    return hasCategories && hasAccounts;
  }

  Future<bool> _hasLocalMetaChanges(String bookId, BuildContext context) async {
    final categoryProvider = context.read<CategoryProvider>();
    final tagProvider = context.read<TagProvider>();
    final accountProvider = context.read<AccountProvider>();

    final categoryDeletes = await CategoryDeleteQueue.instance.loadForBook(bookId);
    if (categoryDeletes.isNotEmpty) return true;
    final tagDeletes = await TagDeleteQueue.instance.load();
    if ((tagDeletes[bookId] ?? const <String>[]).isNotEmpty) return true;
    final accountDeletes = await AccountDeleteQueue.instance.loadForBook(bookId);
    if (accountDeletes.isNotEmpty) return true;
    final savingsDeletes = await SavingsPlanDeleteQueue.instance.loadForBook(bookId);
    if (savingsDeletes.isNotEmpty) return true;

    final localEditMs = await BudgetSyncStateStore.getLocalEditMs(bookId);
    if (localEditMs > 0) return true;

    final hasUnsyncedCategories = categoryProvider.isLoadedForBook(bookId) &&
        categoryProvider.categories.any((c) => c.syncVersion == null);
    if (hasUnsyncedCategories) return true;
    final hasUnsyncedTags = tagProvider.isLoadedForBook(bookId) &&
        tagProvider.tags.any((t) => t.bookId == bookId && t.syncVersion == null);
    if (hasUnsyncedTags) return true;
    final hasUnsyncedAccounts = accountProvider.isLoadedForBook(bookId) &&
        accountProvider.accounts
            .any((a) => a.bookId == bookId && a.syncVersion == null);
    if (hasUnsyncedAccounts) return true;

    return false;
  }

  Future<void> _flushMeta() async {
    final ctx = _context;
    if (ctx == null) return;
    if (_pendingMetaBooks.isEmpty) return;
    if (_syncing) {
      // A normal sync is running; don't drop meta requests, retry shortly.
      _scheduleMetaFlush();
      return;
    }

    _syncing = true;
    try {
      final engine = SyncEngine();
      final books = _pendingMetaBooks.toList(growable: false);
      _pendingMetaBooks.clear();
      for (final bookId in books) {
        final reason = _pendingMetaReasonsByBook.remove(bookId) ?? 'unknown';
        debugPrint('[BackgroundSyncManager] meta sync book=$bookId reason=$reason');
        final ok = await engine.syncMeta(ctx, bookId, reason: reason);
        if (!ok) {
          // Not logged in yet: don't spin retry loops; login flow will trigger sync explicitly.
          continue;
        }
        final doneAt = DateTime.now().millisecondsSinceEpoch;
        _lastMetaSyncMs = doneAt;
        await MetaSyncStateStore.setLastMetaSyncMs(bookId, doneAt);
        if (reason == 'accounts_changed') {
          _lastAccountsSyncMsByBook[bookId] = doneAt;
        } else if (reason == 'budget_changed' ||
            reason == 'categories_changed' ||
            reason == 'tags_changed' ||
            reason == 'savings_plans_changed') {
          _lastUserMetaSyncMsByBook[bookId] = doneAt;
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSyncManager] meta sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _flush() async {
    final ctx = _context;
    if (ctx == null) return;
    if (_syncing) {
      // Avoid dropping pending syncs while a run is in-flight.
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), _flush);
      return;
    }
    if (_pendingBooks.isEmpty) return;
    _syncing = true;

    try {
      final engine = SyncEngine();
      final books = _pendingBooks.toList(growable: false);
      _pendingBooks.clear();
      for (final bookId in books) {
        final reason = _pendingReasonsByBook.remove(bookId) ?? 'unknown';
        debugPrint('[BackgroundSyncManager] sync book=$bookId reason=$reason');
        final ok = await engine.syncBookV2(ctx, bookId, reason: reason);
        if (ok) {
          _lastSyncMsByBook[bookId] = DateTime.now().millisecondsSinceEpoch;
          debugPrint('[BackgroundSyncManager] sync ok book=$bookId reason=$reason');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSyncManager] sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAtMs = DateTime.now().millisecondsSinceEpoch;
      _periodicPullTimer?.cancel();
      _periodicPullTimer = null;
    }
    if (state == AppLifecycleState.resumed) {
      // 前台唤醒时对当前账本做一次静默同步（拉取多设备变更）
      final ctx = _context;
      if (ctx != null) {
        final activeBookId = ctx.read<BookProvider>().activeBookId;
          if (activeBookId.isNotEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch;
          // 部分平台会频繁触发 resumed（如窗口焦点变化），这里只接受“确实 paused 过”的恢复。
          final pausedAt = _lastPausedAtMs;
          _lastPausedAtMs = 0;
          final backgroundFor = pausedAt == 0 ? 0 : now - pausedAt;
          if (backgroundFor >= _resumeMinBackgroundMs) {
            requestSync(activeBookId, reason: 'app_resumed');
            () async {
              if (await _shouldAppStartMetaSync(activeBookId, ctx)) {
                requestMetaSync(activeBookId, reason: 'app_resumed');
              }
            }();
          }
          _startPeriodicPullTimer();
        }
      }
    }
  }
}
