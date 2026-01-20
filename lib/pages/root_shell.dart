import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_record_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../services/auth_service.dart';
import '../services/auth_event_bus.dart';
import '../services/background_sync_manager.dart';
import '../services/app_settings_service.dart';
import '../services/recurring_record_runner.dart';
import '../services/savings_plan_auto_executor.dart';
import '../services/book_service.dart';
import '../services/sync_engine.dart';
import '../theme/app_tokens.dart';
import '../widgets/brand_logo_avatar.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../widgets/slidable_icon_label.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';
import 'dart:async';
import 'account_detail_page.dart';
import 'add_account_type_page.dart';
import 'add_record_page.dart';
import 'analysis_page.dart';
import 'home_page.dart';
import 'login_landing_page.dart';
import 'profile_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _index = 0;
  final AuthService _authService = const AuthService();
  StreamSubscription<void>? _unauthorizedSub;
  StreamSubscription<void>? _authChangedSub;
  bool _handlingUnauthorized = false;
  String? _lastBookId;
  bool _reloadingBook = false;
  bool _reloadingAuth = false;
  bool _runningSavingsAuto = false;

  late final List<Widget> _pages = [
    const HomePage(),
    const AnalysisPage(),
    const AssetsPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unauthorizedSub = AuthEventBus.instance.onUnauthorized.listen((_) {
      if (!mounted) return;
      if (_handlingUnauthorized) return;
      _handlingUnauthorized = true;
      // Navigate to landing and clear the whole stack to avoid stale pages accessing protected APIs.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginLandingPage()),
        (route) => false,
      );
    });
    _authChangedSub = AuthEventBus.instance.onAuthChanged.listen((_) {
      if (!mounted) return;
      _handleAuthChanged();
    });
    // 登录时自动同步（延迟执行，确保context和providers已准备好）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 增加延迟，确保所有providers都已加载完成
        Future.delayed(const Duration(milliseconds: 800), () {
          () async {
            if (!mounted) return;
            _performLoginSync();

            final tokenValid = await _authService.isTokenValid();
            if (!mounted) return;

            // 启动透明后台同步（仅登录态）
            if (tokenValid) {
              BackgroundSyncManager.instance.start(context);
              // 登录态：定时记账/存钱计划由服务端执行，避免客户端重复入账。
              RecurringRecordRunner.instance.stop();
              return;
            }

            // 未登录：本地执行（前台补齐）
            BackgroundSyncManager.instance.stop();
            RecurringRecordRunner.instance.start(context);
            _runSavingsPlanAutoIfNeeded();
          }();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) return;
    // “每天首次回到前台”自动补齐到期存钱。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runSavingsPlanAutoIfNeeded();
    });
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _runSavingsPlanAutoIfNeeded({bool force = false}) async {
    if (!mounted) return;
    if (_runningSavingsAuto) return;
    // 登录态交由服务端执行，避免客户端重复入账。
    final tokenValid = await _authService.isTokenValid();
    if (tokenValid) return;

    // Ensure providers are loaded (RootShell build uses them too).
    final bookProvider = context.read<BookProvider>();
    final recordProvider = context.read<RecordProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();
    final tagProvider = context.read<TagProvider>();
    if (!bookProvider.loaded ||
        !recordProvider.loaded ||
        !categoryProvider.loaded ||
        !accountProvider.loaded ||
        tagProvider.loading) {
      return;
    }

    final bookId = bookProvider.activeBookId;
    if (bookId.isEmpty) return;

    final key = 'savings_plan_auto_last_run_day_$bookId';
    try {
      _runningSavingsAuto = true;
      if (!force) {
        final last = await AppSettingsService.instance.getString(key);
        final today = _todayKey();
        if (last == today) return;
      }

      await SavingsPlanAutoExecutor.instance.runForActiveBook(context);
      await AppSettingsService.instance.setString(key, _todayKey());
    } catch (e, stackTrace) {
      debugPrint('[RootShell] savings plan auto-run failed: $e');
      debugPrint('$stackTrace');
    } finally {
      _runningSavingsAuto = false;
    }
  }

  /// 登录时拉取版本号并缓存（不再每次打开都请求服务器）
  Future<void> _performLoginSync() async {
    if (!mounted) return;

    try {
      final isValid = await _authService.isTokenValid();
      if (!isValid || !mounted) return;

      // 使用 Provider.of 并添加 listen: false，确保能正确访问
      final bookProvider = Provider.of<BookProvider>(context, listen: false);

      // 如果BookProvider还没加载，等待并重试
      int retryCount = 0;
      while (!bookProvider.loaded && retryCount < 10 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }

      if (!mounted || !bookProvider.loaded) {
        debugPrint(
            'BookProvider not loaded after retries, skipping version fetch');
        return;
      }

      // v2 透明同步下不再调用 v1 /api/sync/status/query，避免触发 sync_record 频繁查询。
      // 登录后后台同步由 BackgroundSyncManager 负责。
      // Meta sync is triggered by BackgroundSyncManager (app_start/login flows);
      // avoid duplicating it here to reduce extra SQL.
    } catch (e, stackTrace) {
      // 静默失败，不显示错误，但记录详细日志
      debugPrint('Login version fetch failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _handleAuthChanged() async {
    if (!mounted) return;
    if (_reloadingAuth) return;
    _reloadingAuth = true;
    try {
      final bookProvider = context.read<BookProvider>();
      final recordProvider = context.read<RecordProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final tagProvider = context.read<TagProvider>();
      final accountProvider = context.read<AccountProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final recurringProvider = context.read<RecurringRecordProvider>();

      await bookProvider.reload();
      final bookId = bookProvider.activeBookId;

      await recordProvider.reload();
      await budgetProvider.reload();
      await recurringProvider.reload();

      categoryProvider.reset();
      await categoryProvider.loadForBook(bookId);

      tagProvider.reset();
      await tagProvider.loadForBook(bookId, force: true);

      accountProvider.reset();
      await accountProvider.loadForBook(bookId, force: true);

      // After switching accounts/books and reloading meta, auto-run any due savings plan deposits.
      await _runSavingsPlanAutoIfNeeded(force: true);

      final isValid = await _authService.isTokenValid();
      if (!mounted) return;

      if (!isValid) {
        BackgroundSyncManager.instance.stop();
        RecurringRecordRunner.instance.start(context);
        await _runSavingsPlanAutoIfNeeded(force: true);
        return;
      }
      if (bookId.isEmpty || int.tryParse(bookId) == null) return;

      BackgroundSyncManager.instance.start(context);
      BackgroundSyncManager.instance.markLoggedIn();
      RecurringRecordRunner.instance.stop();
      BackgroundSyncManager.instance.requestSync(bookId, reason: 'login');
      BackgroundSyncManager.instance.requestMetaSync(bookId, reason: 'login');
    } catch (e, stackTrace) {
      debugPrint('[RootShell] auth change reload failed: $e');
      debugPrint('$stackTrace');
    } finally {
      _reloadingAuth = false;
    }
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    _authChangedSub?.cancel();
    BackgroundSyncManager.instance.stop();
    RecurringRecordRunner.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openQuickAddPage() async {
    if (_reloadingBook) {
      ErrorHandler.showWarning(context, 'æ­£åœ¨åˆ‡æ¢è´¦æœ¬ï¼Œè¯·ç¨åŽ');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRecordPage()),
    );
  }

  void _handleDestination(int value) {
    if (value == 2) {
      _openQuickAddPage();
      return;
    }
    final mapped = value > 2 ? value - 1 : value;
    setState(() => _index = mapped);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 确保所有providers都已加载
    final bookProvider = context.watch<BookProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final tagProvider = context.watch<TagProvider>();

    if (!bookProvider.loaded ||
        !recordProvider.loaded ||
        !categoryProvider.loaded ||
        !accountProvider.loaded ||
        tagProvider.loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final activeBookId = bookProvider.activeBookId;
    if (_lastBookId != activeBookId) {
      _lastBookId = activeBookId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _reloadingBook = true);
        try {
          if (int.tryParse(activeBookId) != null) {
            await SyncEngine().ensureMetaReady(
              context,
              activeBookId,
              requireCategories: true,
              requireAccounts: false,
              requireTags: false,
              reason: 'book_switched',
            );
          }
          await Future.wait([
            context.read<TagProvider>().loadForBook(activeBookId),
            context.read<AccountProvider>().loadForBook(activeBookId),
          ]);
        } catch (_) {}
        if (mounted) setState(() => _reloadingBook = false);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: _pages,
          ),
          if (_reloadingBook)
            Positioned.fill(
              child: Stack(
                children: const [
                  ModalBarrier(dismissible: false, color: Colors.black12),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.12),
        selectedIndex: _index >= 2 ? _index + 1 : _index,
        onDestinationSelected: _handleDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: AppStrings.navStats,
          ),
          NavigationDestination(
            icon: _RecordNavIcon(color: cs.primary),
            selectedIcon: _RecordNavIcon(color: cs.primary),
            label: AppStrings.navRecord,
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: AppStrings.navAssets,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AssetsPageBody();
  }
}

class _AssetsPageBody extends StatefulWidget {
  const _AssetsPageBody();

  @override
  State<_AssetsPageBody> createState() => _AssetsPageBodyState();
}

class _AssetsPageBodyState extends State<_AssetsPageBody> {
  bool _hideAmounts = false;

  @override
  void initState() {
    super.initState();
    _loadHideAmounts();
  }

  Future<void> _loadHideAmounts() async {
    final value = await AppSettingsService.instance.getBool(
      AppSettingsService.keyHideAmountsAssets,
      defaultValue: true,
    );
    if (!mounted) return;
    setState(() {
      _hideAmounts = value;
    });
  }

  Future<void> _toggleHideAmounts() async {
    final next = !_hideAmounts;
    setState(() {
      _hideAmounts = next;
    });
    try {
      await AppSettingsService.instance.setBool(
        AppSettingsService.keyHideAmountsAssets,
        next,
      );
    } catch (_) {
      // ignore persistence errors; UI state already updated
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accountProvider = context.watch<AccountProvider>();

    final accounts = accountProvider.accounts;
    final totalAssets = accountProvider.totalAssets;
    final totalDebts = accountProvider.totalDebts;
    final netWorth = accountProvider.netWorth;
    final grouped = _groupAccounts(accounts);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: accounts.isEmpty
                ? _EmptyAccounts(
                    onAdd: () => _startAddAccountFlow(context),
                  )
                : Column(
                    children: [
                      _AssetSummaryCard(
                        totalAssets: totalAssets,
                        totalDebts: totalDebts,
                        netWorth: netWorth,
                        hideAmounts: _hideAmounts,
                        onToggleHideAmounts: _toggleHideAmounts,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '账户余额来自你的记账记录。如不准确，请进入账户详情页，点击"调整余额"进行修正。',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.65),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_hasAnyBalanceIssue(accounts)) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.danger.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '检测到异常余额，请及时检查',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 快速操作栏
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        _openTransferSheet(context, accounts),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '转账',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _startAddAccountFlow(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 18,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '添加账户',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            for (final group in grouped)
                              _AccountGroupPanel(
                                group: group,
                                hideAmounts: _hideAmounts,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AssetSummaryCard extends StatelessWidget {
  const _AssetSummaryCard({
    required this.totalAssets,
    required this.totalDebts,
    required this.netWorth,
    required this.hideAmounts,
    required this.onToggleHideAmounts,
  });

  final double totalAssets;
  final double totalDebts;
  final double netWorth;
  final bool hideAmounts;
  final VoidCallback onToggleHideAmounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.22),
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.netWorth,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleHideAmounts,
                  icon: Icon(
                    hideAmounts
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  tooltip: hideAmounts ? '显示金额' : '隐藏金额',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _displayAmount(netWorth),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('资产', totalAssets, cs, theme.textTheme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem('负债', totalDebts, cs, theme.textTheme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayAmount(double value) {
    if (hideAmounts) return '****';
    return _formatAmount(value);
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    }
    return value.toStringAsFixed(2);
  }

  Widget _buildStatItem(
      String label, double value, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.75),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _displayAmount(value),
          style: tt.bodyMedium?.copyWith(
            fontSize: 14,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AccountGroupPanel extends StatelessWidget {
  const _AccountGroupPanel({
    required this.group,
    required this.hideAmounts,
  });

  final _AccountGroupData group;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            group.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.9),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (final account in group.accounts)
                _AccountTile(
                  account: account,
                  isLast: account == group.accounts.last,
                  hideAmounts: hideAmounts,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isLast,
    required this.hideAmounts,
  });

  final Account account;
  final bool isLast;
  final bool hideAmounts;

  Future<void> _handleDelete(BuildContext context) async {
    final accountProvider = context.read<AccountProvider>();
    final recordProvider = context.read<RecordProvider>();
    final bookId = context.read<BookProvider>().activeBookId;

    if (int.tryParse(bookId) != null) {
      try {
        final ok = await BookService().isCurrentUserOwner(bookId);
        if (!ok) {
          if (context.mounted) {
            ErrorHandler.showWarning(context, '多人账本仅创建者可修改账户');
          }
          return;
        }
      } catch (_) {}
    }

    // 1) 账户下还有流水：不允许删除（否则余额必然对不上/出现异常）
    final usedCount =
        await recordProvider.countRecordsForAccount(bookId, account);
    if (usedCount > 0) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法直接删除'),
          content: Text('该账户下还有 $usedCount 笔记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              child: const Text('删除记录并删除账户'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (action != 'force') return;

      try {
        final deleted =
            await recordProvider.deleteRecordsForAccount(bookId, account);
        await accountProvider.refreshBalancesFromRecords();
        if (!context.mounted) return;
        ErrorHandler.showSuccess(context, '已删除 $deleted 笔记录');
      } catch (e) {
        if (!context.mounted) return;
        ErrorHandler.handleAsyncError(context, e);
        return;
      }
    }

    // 2) 至少保留一个账户（记一笔/对账都需要稳定账户）
    if (accountProvider.accounts.length <= 1) {
      ErrorHandler.showError(context, '至少需要保留一个账户');
      return;
    }

    // 3) 默认钱包不允许删除（避免“删了又回来”的体验）
    final isDefaultWallet = account.id == 'default_wallet' ||
        account.brandKey == 'default_wallet' ||
        account.name.trim() == '默认钱包';
    if (isDefaultWallet) {
      ErrorHandler.showError(context, '默认钱包无法删除');
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除账户'),
            content: Text('确定删除账户"${account.name}"吗？删除后无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!context.mounted) return;
    if (!confirmed) return;

    try {
      await accountProvider.deleteAccount(account.id, bookId: bookId);

      if (context.mounted) {
        ErrorHandler.showSuccess(context, '账户已删除');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasIssue = _hasBalanceIssue(account);
    final amountColor = cs.onSurface;
    final icon = _iconForAccount(account);
    final amountText =
        hideAmounts ? '****' : account.currentBalance.toStringAsFixed(2);

    final tileContent = InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountDetailPage(accountId: account.id),
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                BrandLogoAvatar(
                  size: 38,
                  brandKey: account.brandKey,
                  icon: icon,
                  iconColor: cs.primary,
                  backgroundColor: cs.primary.withOpacity(0.08),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleForAccount(account),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: amountColor.withOpacity(0.9),
                      ),
                    ),
                    if (hasIssue) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 10,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '异常',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 60,
              endIndent: 12,
              color: cs.outlineVariant.withOpacity(0.3),
              thickness: 0.5,
            ),
        ],
      ),
    );

    return Slidable(
      key: ValueKey(account.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.26,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _handleDelete(context),
            backgroundColor: AppColors.danger,
            child: const SlidableIconLabel(
              icon: Icons.delete_outline,
              label: '删除',
              color: Colors.white,
            ),
          ),
        ],
      ),
      child: tileContent,
    );
  }

  IconData _iconForAccount(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    switch (subtype) {
      case AccountSubtype.cash:
        return Icons.account_balance_wallet_outlined;
      case AccountSubtype.savingCard:
        return Icons.credit_card;
      case AccountSubtype.creditCard:
        return Icons.credit_score_outlined;
      case AccountSubtype.virtual:
        return Icons.qr_code_2_outlined;
      case AccountSubtype.invest:
        return Icons.savings_outlined;
      case AccountSubtype.loan:
        return Icons.trending_down;
      case AccountSubtype.receivable:
        return Icons.swap_horiz_outlined;
      case AccountSubtype.customAsset:
        return Icons.category_outlined;
    }
  }

  String _subtitleForAccount(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    switch (subtype) {
      case AccountSubtype.cash:
        return '现金';
      case AccountSubtype.savingCard:
        return '储蓄卡';
      case AccountSubtype.creditCard:
        return '信用卡 / 花呗';
      case AccountSubtype.virtual:
        return '虚拟账户';
      case AccountSubtype.invest:
        return '投资账户';
      case AccountSubtype.loan:
        return '贷款 / 借入';
      case AccountSubtype.receivable:
        return '应收 / 借出';
      case AccountSubtype.customAsset:
        return '自定义资产';
    }
  }

  bool _hasBalanceIssue(Account account) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    // 储蓄卡、现金等资产账户不应该有负余额
    if (account.kind == AccountKind.asset &&
        (subtype == AccountSubtype.savingCard ||
            subtype == AccountSubtype.cash) &&
        account.currentBalance < 0) {
      return true;
    }
    return false;
  }
}

bool _hasAnyBalanceIssue(List<Account> accounts) {
  for (final account in accounts) {
    final subtype = AccountSubtype.fromCode(account.subtype);
    if (account.kind == AccountKind.asset &&
        (subtype == AccountSubtype.savingCard ||
            subtype == AccountSubtype.cash) &&
        account.currentBalance < 0) {
      return true;
    }
  }
  return false;
}

void _openTransferSheet(BuildContext context, List<Account> accounts) {
  final amountCtrl = TextEditingController();
  String? fromAccountId;
  String? toAccountId;

  // 过滤出资产账户（不包括负债账户）
  final assetAccounts = accounts.where((a) {
    return a.kind != AccountKind.liability;
  }).toList();

  if (assetAccounts.isEmpty) {
    ErrorHandler.showWarning(context, '至少需要两个资产账户才能进行转账');
    return;
  }

  // 默认选择第一个和第二个账户
  if (assetAccounts.length >= 2) {
    fromAccountId = assetAccounts[0].id;
    toAccountId = assetAccounts[1].id;
  } else {
    fromAccountId = assetAccounts[0].id;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom + 12;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '账户间转账',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                // 转出账户选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '转出账户',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final selectedId = await showAccountSelectBottomSheet(
                          context,
                          assetAccounts,
                          selectedAccountId: fromAccountId,
                          title: '选择转出账户',
                        );
                        if (selectedId != null) {
                          setState(() {
                            fromAccountId = selectedId;
                            // 如果转出账户和转入账户相同，自动选择另一个账户
                            if (selectedId == toAccountId &&
                                assetAccounts.length > 1) {
                              toAccountId = assetAccounts
                                  .firstWhere((a) => a.id != selectedId)
                                  .id;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fromAccountId != null
                                    ? assetAccounts
                                        .firstWhere(
                                            (a) => a.id == fromAccountId)
                                        .name
                                    : '请选择转出账户',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontSize: 15,
                                      color: fromAccountId != null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 转入账户选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '转入账户',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final availableAccounts = assetAccounts
                            .where((a) => a.id != fromAccountId)
                            .toList();
                        if (availableAccounts.isEmpty) {
                          ErrorHandler.showWarning(context, '没有可选的转入账户');
                          return;
                        }
                        final selectedId = await showAccountSelectBottomSheet(
                          context,
                          availableAccounts,
                          selectedAccountId: toAccountId,
                          title: '选择转入账户',
                        );
                        if (selectedId != null) {
                          setState(() => toAccountId = selectedId);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                toAccountId != null
                                    ? assetAccounts
                                        .firstWhere((a) => a.id == toAccountId)
                                        .name
                                    : '请选择转入账户',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontSize: 15,
                                      color: toAccountId != null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  decoration: InputDecoration(
                    labelText: '金额',
                    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            final amountStr = amountCtrl.text.trim();
                            final amount = double.tryParse(amountStr);

                            // 验证金额
                            final amountError =
                                Validators.validateAmount(amount);
                            if (amountError != null) {
                              ErrorHandler.showError(ctx, amountError);
                              return;
                            }

                            final fromId = fromAccountId;
                            final toId = toAccountId;
                            if (fromId == null || toId == null) {
                              ErrorHandler.showError(ctx, '请选择转出和转入账户');
                              return;
                            }
                            if (fromId == toId) {
                              ErrorHandler.showError(ctx, '转出账户和转入账户不能相同');
                              return;
                            }

                            final bookId =
                                context.read<BookProvider>().activeBookId;
                            await context.read<RecordProvider>().transfer(
                                  accountProvider:
                                      context.read<AccountProvider>(),
                                  fromAccountId: fromId,
                                  toAccountId: toId,
                                  amount: amount!,
                                  fee: 0,
                                  bookId: bookId,
                                );

                            // 先关闭弹窗
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            // 再显示成功消息（使用原始 context）
                            if (context.mounted) {
                              ErrorHandler.showSuccess(context, '转账成功');
                            }
                          } catch (e, stackTrace) {
                            // 记录详细错误日志
                            debugPrint('[转账错误] $e');
                            debugPrint('Stack trace: $stackTrace');

                            // 发生错误时也要关闭弹窗
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            // 显示错误消息
                            if (context.mounted) {
                              // 显示更具体的错误信息
                              String errorMessage = '操作失败，请稍后重试';
                              if (e is ArgumentError) {
                                errorMessage = e.message.toString();
                              } else if (e.toString().contains('StateError') ||
                                  e.toString().contains('找不到') ||
                                  e.toString().contains('not found')) {
                                errorMessage = '转账记录创建失败，请重试';
                              } else if (e.toString().contains('database') ||
                                  e.toString().contains('sql')) {
                                errorMessage = '数据库操作失败，请稍后重试';
                              }
                              ErrorHandler.showError(context, errorMessage,
                                  error: e);
                            }
                          }
                        },
                        child: const Text('确认转账'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 96,
            color: cs.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '从第一个账户开始，看清你的资产',
            style: tt.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加你的现金、银行卡或借款账户，净资产一目了然。',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
        ],
      ),
    );
  }
}

class _AccountGroupData {
  const _AccountGroupData({required this.title, required this.accounts});

  final String title;
  final List<Account> accounts;
}

class _GroupDefinition {
  const _GroupDefinition({
    required this.title,
    required this.kind,
    required this.subtypes,
  });

  final String title;
  final AccountKind kind;
  final List<String> subtypes;
}

List<_AccountGroupData> _groupAccounts(List<Account> accounts) {
  final definitions = [
    _GroupDefinition(
      title: '现金',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.cash.code],
    ),
    _GroupDefinition(
      title: '储蓄卡',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.savingCard.code],
    ),
    _GroupDefinition(
      title: '信用卡',
      kind: AccountKind.liability,
      subtypes: [AccountSubtype.creditCard.code],
    ),
    _GroupDefinition(
      title: '虚拟账户',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.virtual.code],
    ),
    _GroupDefinition(
      title: '投资账户',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.invest.code],
    ),
    _GroupDefinition(
      title: '自定义资产',
      kind: AccountKind.asset,
      subtypes: [AccountSubtype.customAsset.code],
    ),
    _GroupDefinition(
      title: '负债（贷款 / 借入）',
      kind: AccountKind.liability,
      subtypes: [AccountSubtype.loan.code],
    ),
  ];

  final handled = <String>{};
  final result = <_AccountGroupData>[];

  for (final def in definitions) {
    final list = accounts.where((a) {
      if (handled.contains(a.id)) return false;
      final belongs = def.subtypes.contains(a.subtype) && a.kind == def.kind;
      return belongs;
    }).toList();
    if (list.isNotEmpty) {
      handled.addAll(list.map((e) => e.id));
      result.add(_AccountGroupData(title: def.title, accounts: list));
    }
  }

  final leftovers = accounts.where((a) => !handled.contains(a.id)).toList();
  if (leftovers.isNotEmpty) {
    result.add(_AccountGroupData(title: '其他账户', accounts: leftovers));
  }
  return result;
}

Future<AccountKind?> _startAddAccountFlow(BuildContext context) async {
  final bookId = context.read<BookProvider>().activeBookId;
  if (int.tryParse(bookId) != null) {
    try {
      final ok = await BookService().isCurrentUserOwner(bookId);
      if (!ok) {
        if (context.mounted) {
          ErrorHandler.showWarning(context, '多人账本仅创建者可修改账户');
        }
        return null;
      }
    } catch (_) {}
  }
  final accountProvider = context.read<AccountProvider>();
  final assetBefore = accountProvider.byKind(AccountKind.asset).length;
  final hasDebtBefore =
      accountProvider.byKind(AccountKind.liability).isNotEmpty;

  final createdKind = await Navigator.push<AccountKind>(
    context,
    MaterialPageRoute(builder: (_) => const AddAccountTypePage()),
  );
  if (!context.mounted) return null;
  if (createdKind == null) return null;

  final hasDebtAfter = accountProvider.byKind(AccountKind.liability).isNotEmpty;
  if (createdKind == AccountKind.asset &&
      assetBefore == 0 &&
      !hasDebtBefore &&
      !hasDebtAfter &&
      context.mounted) {
    await _promptAddDebt(context);
  }
  return createdKind;
}

Future<void> _promptAddDebt(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('添加负债账户'),
      content: const Text('要不要顺便把负债账户也加进去？这样净资产会更真实。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('以后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('添加负债账户'),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    await Navigator.push<AccountKind>(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountTypePage()),
    );
  }
}

class _RecordNavIcon extends StatelessWidget {
  const _RecordNavIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.add,
        size: 26,
        color: cs.onPrimary,
      ),
    );
  }
}
