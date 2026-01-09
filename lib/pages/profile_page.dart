import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/import_result.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_record_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/brand_theme.dart';
import '../models/book.dart';
import '../database/database_helper.dart';
import '../repository/repository_factory.dart';
import '../services/auth_service.dart';
import '../services/book_service.dart';
import '../services/background_sync_manager.dart';
import '../services/book_invite_code_store.dart';
import 'feedback_page.dart';
import '../services/gift_code_service.dart';
import '../services/local_data_reset_service.dart';
import '../services/records_export_service.dart';
import '../services/recurring_record_runner.dart';
import '../services/sync_outbox_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_v2_conflict_store.dart';
import '../services/user_service.dart';
import 'account_settings_page.dart';
import 'vip_purchase_page.dart';
import 'sync_conflicts_page.dart';
import 'export_data_page.dart';
import 'savings_plans_page.dart';
import 'recurring_records_page.dart';
import 'book_members_page.dart';
import '../utils/data_export_import.dart';
import '../utils/error_handler.dart';
import '../widgets/user_stats_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = const AuthService();
  String? _token;
  String? _nickname;
  bool _loadingToken = true;
  bool _wiping = false;
  bool _bootstrapping = false;

  Future<int> _conflictCountForDisplay(String bookId) async {
    final recordProvider = context.read<RecordProvider>();
    final count = await SyncV2ConflictStore.count(bookId);
    if (count <= 0) return 0;

    final hasLocal = recordProvider.recordsForBook(bookId).isNotEmpty;
    final outbox = await SyncOutboxService.instance.loadPending(bookId, limit: 1);
    if (!hasLocal && outbox.isEmpty) {
      await SyncV2ConflictStore.clear(bookId);
      return 0;
    }

    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _editNickname() async {
    final isLoggedIn = (_token != null && _token!.isNotEmpty);
    if (!isLoggedIn) {
      ErrorHandler.showWarning(context, '未登录，请先登录');
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _nickname ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('编辑昵称'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: '请输入昵称（最多20字）',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return '昵称不能为空';
                  if (t.length > 20) return '昵称最多20个字符';
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() != true) return;
                        setLocal(() => saving = true);
                        try {
                          final newName = controller.text.trim();
                          final resp =
                              await UserService().updateMyNickname(newName);
                          if (resp['success'] == true) {
                            await _authService.saveNickname(newName);
                            await BookService().invalidateMembersCache();
                            if (mounted) {
                              setState(() {
                                _nickname = newName;
                              });
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } else {
                            throw Exception(resp['error'] ?? '更新失败');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: cs.error,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setLocal(() => saving = false);
                        }
                      },
                child: Text(saving ? '保存中...' : '保存'),
              ),
            ],
          );
        });
      },
    );
    if (ok == true && mounted) {
      await _loadToken();
    }
  }

  Future<void> _openAccountSettings(bool isLoggedIn) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSettingsPage(initialLoggedIn: isLoggedIn),
      ),
    );
    if (changed == true) {
      await _loadToken();
    }
  }

  Future<void> _confirmWipeAllLocalData() async {
    if (!kDebugMode || _wiping) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('清空本地数据？'),
          content: const Text(
            '此操作会删除本机所有数据（账本/账户/记账/标签/同步队列/设置/登录信息），不可恢复。\n\n仅用于测试。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;
    await _wipeAllLocalData();
  }

  Future<void> _wipeAllLocalData() async {
    if (_wiping) return;
    setState(() => _wiping = true);

    BackgroundSyncManager.instance.stop();
    RecurringRecordRunner.instance.stop();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('正在清空数据...')),
            ],
          ),
        );
      },
    );

    try {
      await LocalDataResetService.wipeAllLocalData();

      await DatabaseHelper().database;
      await RepositoryFactory.initialize();

      final bookProvider = context.read<BookProvider>();
      final recordProvider = context.read<RecordProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final accountProvider = context.read<AccountProvider>();
      final recurringProvider = context.read<RecurringRecordProvider>();
      final themeProvider = context.read<ThemeProvider>();
      final tagProvider = context.read<TagProvider>();

      await bookProvider.load();
      await Future.wait([
        recordProvider.load(),
        categoryProvider.load(),
        budgetProvider.load(),
        accountProvider.load(),
        recurringProvider.load(),
        themeProvider.load(),
      ]);
      await tagProvider.loadForBook(bookProvider.activeBookId);
      await _loadToken();

      if (!mounted) return;
      BackgroundSyncManager.instance.start(context);
      RecurringRecordRunner.instance.start(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空本地数据')),
      );
    } catch (e, stackTrace) {
      ErrorHandler.logError('ProfilePage.wipeAllLocalData', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _wiping = false);
      }
    }
  }

  Future<void> _confirmForceBootstrap(String bookId) async {
    if (_bootstrapping) return;

    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('一键修复同步？'),
          content: const Text(
            '会强制把云端账单全量拉取一遍（不会删除本地未同步的新记录）。\n\n如果你正在离线编辑且有大量待上传数据，建议先等待同步完成再执行。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(1),
              child: const Text('仅拉取'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(2),
              child: const Text('推后再拉'),
            ),
          ],
        );
      },
    );

    if (choice == null || choice == 0 || !mounted) return;

    setState(() => _bootstrapping = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('正在修复同步...')),
            ],
          ),
        );
      },
    );

    try {
      await SyncEngine().forceBootstrapV2(
        context,
        bookId,
        pushBeforePull: choice == 2,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步修复完成')),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('ProfilePage.forceBootstrap', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步修复失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _bootstrapping = false);
      }
    }
  }

  Future<void> _loadToken() async {
    final t = await _authService.loadToken();
    final nick = await _authService.loadNickname();
    if (!mounted) return;
    setState(() {
      _token = t;
      _nickname = nick;
      _loadingToken = false;
    });
  }

  Future<void> _logout() async {
    await _authService.clearToken();
    try {
      final books = context.read<BookProvider>().books;
      for (final b in books) {
        await SyncV2ConflictStore.clear(b.id);
      }
    } catch (_) {}
    await _loadToken();
  }

  Future<void> _showGiftCodeDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Text(
            '兑换礼包码',
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
          ),
          content: TextField(
            controller: controller,
            maxLength: 8,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: '输入 8 位礼包码',
              hintStyle: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                '取消',
                style: tt.labelLarge?.copyWith(color: cs.onSurface),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = controller.text.trim();
                if (code.length != 8) {
                  ErrorHandler.showWarning(ctx, '请输入 8 位礼包码');
                  return;
                }
                Navigator.pop(ctx);
                await _redeemGiftCodeStub(code);
              },
              child: Text(
                '兑换',
                style: tt.labelLarge?.copyWith(color: cs.onPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _redeemGiftCodeStub(String code) async {
    if (!mounted) return;
    
    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final giftCodeService = GiftCodeService();
      final result = await giftCodeService.redeem(code);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载提示

      if (result.success) {
        var message = result.message;
        if (result.payExpire != null) {
          final expireStr =
              '${result.payExpire!.year}-${result.payExpire!.month.toString().padLeft(2, '0')}-${result.payExpire!.day.toString().padLeft(2, '0')}';
          message += '\n付费到期时间：$expireStr';
        }
        ErrorHandler.showSuccess(context, message);
      } else {
        ErrorHandler.showError(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载提示

      var errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('未登录')) {
        errorMsg = '未登录，请先登录';
      } else if (errorMsg.contains('格式不正确')) {
        errorMsg = '礼包码格式不正确，请输入8位数字';
      } else if (errorMsg.contains('不存在')) {
        errorMsg = '礼包码不存在';
      } else if (errorMsg.contains('已过期')) {
        errorMsg = '礼包码已过期';
      } else if (errorMsg.contains('已被使用')) {
        errorMsg = '礼包码已被使用';
      } else if (errorMsg.contains('兑换失败')) {
        errorMsg = '兑换失败，请稍后再试';
      }
      ErrorHandler.showError(context, errorMsg);
    }
  }


  String _generateInviteCode() {
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(rand.nextInt(10));
    }
    return buffer.toString();
  }

  Future<void> _showJoinInviteDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final raw = controller.text;
            final digitsOnly = raw.replaceAll(RegExp(r'\\D'), '');
            final canJoin = digitsOnly.length == 8;

            return AlertDialog(
              title: Text(
                '加入多人账本',
                style: tt.titleMedium?.copyWith(color: cs.onSurface),
              ),
              content: TextField(
                controller: controller,
                maxLength: 8,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: '输入 8 位邀请码',
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    '取消',
                    style: tt.labelLarge?.copyWith(color: cs.onSurface),
                  ),
                ),
                FilledButton(
                  onPressed: !canJoin
                      ? null
                      : () async {
                          final code = controller.text
                              .trim()
                              .replaceAll(RegExp(r'\\D'), '');
                          if (code.length != 8) {
                            ErrorHandler.showWarning(ctx, '请输入 8 位邀请码');
                            return;
                          }
                          Navigator.pop(ctx);
                          await _joinBookByCodeStub(code);
                        },
                  child: Text(
                    '加入',
                    style: tt.labelLarge,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyToClipboard(String text, {String? successMessage}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    ErrorHandler.showSuccess(context, successMessage ?? '已复制');
  }

  Future<void> _showInviteCodeDialog({
    required String bookId,
    required String bookName,
    required String inviteCode,
  }) async {
    await BookInviteCodeStore.instance.setInviteCode(bookId, inviteCode);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('多人账本邀请码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账本：$bookName'),
            const SizedBox(height: 10),
            SelectableText(inviteCode, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copyToClipboard(inviteCode, successMessage: '邀请码已复制'),
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinBookByCodeStub(String code) async {
    final bookService = BookService();
    try {
      final result = await bookService.joinBook(code);
      final serverBookId =
          (result['id'] as num?)?.toInt().toString() ?? '';
      final name = result['name'] as String? ?? '多人账本';
      final inviteCode = (result['inviteCode'] as String?)?.trim() ?? '';
      if (mounted && serverBookId.isNotEmpty) {
        final bookProvider = context.read<BookProvider>();
        await bookProvider.addServerBook(serverBookId, name);
        await bookProvider.selectBook(serverBookId);
        if (inviteCode.isNotEmpty) {
          await BookInviteCodeStore.instance.setInviteCode(serverBookId, inviteCode);
        }
        await SyncEngine().forceBootstrapV2(context, serverBookId);
      }
      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已成功加入账本');
    } catch (e) {
      if (!mounted) return;
      // 检查是否是付费相关错误
      final errorMsg = e.toString();
      if (_isPaymentRequiredError(errorMsg)) {
        _showVipPurchasePage();
      } else {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _goLogin() async {
    final result = await Navigator.pushNamed(context, '/login');
    if (result == true) {
      await _loadToken();
      if (!mounted) return;
      // Guest-created local records should not be uploaded without user consent.
      await SyncEngine().maybeUploadGuestOutboxAfterLogin(context, reason: 'login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final cs = Theme.of(context).colorScheme;

    final activeBookName = bookProvider.activeBook?.name ?? AppStrings.book;
    final bookCount = bookProvider.books.length;
 	    final categoryCount = categoryProvider.categories.length;
 	    final isLoggedIn = (_token != null && _token!.isNotEmpty);
 	    final activeBookId = bookProvider.activeBookId;
      final displayName =
          isLoggedIn ? (_nickname?.trim().isNotEmpty == true ? _nickname!.trim() : '用户') : '设置';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: Center(
           child: ConstrainedBox(
             constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
               padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [                
                 if (!isLoggedIn) ...[
                   _buildLoginHintCard(context),
                   const SizedBox(height: 12),
                 ] else ...[
 	                  FutureBuilder<int>(
	                    future: activeBookId.isNotEmpty
	                        ? _conflictCountForDisplay(activeBookId)
	                        : Future.value(0),
	                    builder: (ctx, snap) {
	                      final count = snap.data ?? 0;
	                      if (count <= 0) return const SizedBox.shrink();
	                      return Column(
	                        children: [
	                          InkWell(
	                        borderRadius: BorderRadius.circular(16),
	                        onTap: () {
	                          Navigator.push(
	                            context,
	                            MaterialPageRoute(
	                              builder: (_) => SyncConflictsPage(bookId: activeBookId),
	                            ),
	                          );
	                        },
	                        child: _buildInfoBanner(
	                        ctx,
	                        icon: Icons.sync_problem_outlined,
	                        title: '同步冲突 $count 条',
	                        subtitle: '已自动保留冲突记录（暂不自动覆盖），后续将提供处理入口',
	                        ),
	                          ),
	                          const SizedBox(height: 12),
	                        ],
	                      );
	                    },
	                  ),
                ],
                 _buildHeaderCard(
                   context,
                   title: displayName,
                   subtitle: isLoggedIn ? '点击头像可编辑昵称/账号设置' : '管理你的账本、主题和预算',
                   activeBook: activeBookName,
                   bookCount: bookCount,
                   categoryCount: categoryCount,
                   isLoggedIn: isLoggedIn,
                 ),
                const SizedBox(height: 12),
                const UserStatsCard(),
                const SizedBox(height: 12),
                _buildVipCard(context),
                const SizedBox(height: 12),
                _buildActionGrid(
                  context,
                ),
                const SizedBox(height: 12),
                _buildSettingsList(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVipCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showPlaceholder(context, '升级为 VIP'),
      child: Card(
        color: cs.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.workspace_premium_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '升级为 VIP',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '畅享更多高级功能',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginHintCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_outline, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '未登录',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '现在可以直接记账：数据默认保存在本机，离线也可用。\n登录后会在后台自动同步到云端，支持多设备与多人账本，不需要手动点“同步”。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurface.withOpacity(0.75), height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _goLogin,
                    child: const Text('登录'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openAccountSettings(false),
                    child: const Text('账户设置'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: cs.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      _ProfileAction(
        icon: Icons.card_giftcard_outlined,
        label: '兑换礼包码',
        onTap: _showGiftCodeDialog,
      ),
      _ProfileAction(
        icon: Icons.menu_book_outlined,
        label: '账本管理',
        onTap: () => _showBookManagerSheet(context),
      ),
      _ProfileAction(
        icon: Icons.color_lens_outlined,
        label: '主题风格',
        onTap: () => _openThemeSheet(context),
      ),
      _ProfileAction(
        icon: Icons.trending_down_outlined,
        label: AppStrings.budget,
        onTap: () => Navigator.pushNamed(context, '/budget'),
      ),
      _ProfileAction(
        icon: Icons.category_outlined,
        label: AppStrings.categoryManager,
        onTap: () => Navigator.pushNamed(context, '/category-manager'),
      ),
      _ProfileAction(
        icon: Icons.schedule_rounded,
        label: '定时记账',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringRecordsPage()),
        ),
      ),
      _ProfileAction(
        icon: Icons.savings_outlined,
        label: '存钱计划',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavingsPlansPage()),
        ),
      ),
      _ProfileAction(
        icon: Icons.privacy_tip_outlined,
        label: '数据与安全',
        onTap: () {
          final csInner = Theme.of(context).colorScheme;
          _showDataSecuritySheet(context, csInner);
        },
      ),
    ];

    return Card(
      color: cs.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.4,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookId = context.read<BookProvider>().activeBookId;
    final isLoggedIn = _token != null && _token!.isNotEmpty;
    return Card(
      color: cs.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.feedback_outlined,
                color: cs.onSurface.withOpacity(0.8)),
            title: Text(
              '意见反馈',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: cs.onSurface),
            ),
            trailing:
                Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading:
                Icon(Icons.info_outline, color: cs.onSurface.withOpacity(0.8)),
            title: Text(
              '关于指尖记账 1.0.0',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: cs.onSurface),
            ),
            trailing:
                Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.6)),
            onTap: () => _showPlaceholder(context, '关于指尖记账 1.0.0'),
          ),
          if (isLoggedIn && bookId.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              leading:
                  Icon(Icons.sync_outlined, color: cs.onSurface.withOpacity(0.8)),
              title: Text(
                '一键修复同步',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                '强制全量拉取云端账单，修复极端漏拉/游标异常',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
              ),
              trailing: _bootstrapping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: () => _confirmForceBootstrap(bookId),
            ),
          ],
          if (kDebugMode) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: cs.error.withOpacity(0.9)),
              title: Text(
                '一键清空本地数据（测试）',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                '删除账本/账户/记账/标签/设置/登录信息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
              ),
              trailing: _wiping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _confirmWipeAllLocalData,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
      BuildContext context, {
      required String title,
      required String subtitle,
      required String activeBook,
      required int bookCount,
      required int categoryCount,
      required bool isLoggedIn,
    }) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final brand = theme.extension<BrandTheme>();
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surfaceContainerHighest,
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () async {
                    if (isLoggedIn) {
                      await _editNickname();
                      return;
                    }
                    _openAccountSettings(isLoggedIn);
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primary.withOpacity(isDark ? 0.22 : 0.14),
                    child: Icon(
                      Icons.person_outline,
                      size: 26,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.72),
                            height: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat(
                context,
                label: '当前账本',
                value: activeBook,
              ),
              _buildHeaderStat(
                context,
                label: '账本数量',
                value: '$bookCount',
              ),
              _buildHeaderStat(
                context,
                label: '分类数量',
                value: '$categoryCount',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurface.withOpacity(0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookManagerSheet(BuildContext context) async {
    final bookProvider = context.read<BookProvider>();
    final cs = Theme.of(context).colorScheme;
    final loggedIn = _token != null && _token!.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '我的账本',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: cs.onSurface),
                    ),
                     const Spacer(),
                     TextButton.icon(
                       onPressed: () {
                         Navigator.pop(ctx);
                         if (!loggedIn) {
                           ErrorHandler.showWarning(
                             context,
                             AppStrings.guestSingleBookOnly,
                           );
                           _goLogin();
                           return;
                         }
                         _showAddBookDialog(context);
                       },
                       icon: Icon(Icons.add, color: cs.primary),
                       label: Text(
                         AppStrings.addBook,
                         style: tt.labelLarge?.copyWith(color: cs.primary),
                       ),
                     ),
                     if (loggedIn)
                       TextButton.icon(
                         onPressed: () {
                           Navigator.pop(ctx);
                           _showJoinInviteDialog();
                         },
                         style: TextButton.styleFrom(
                           foregroundColor: cs.primary,
                         ),
                         icon: Icon(Icons.person_add_alt_1, color: cs.primary),
                         label: Text(
                           '加入',
                           style: tt.labelLarge?.copyWith(color: cs.primary),
                         ),
                       ),
                   ],
                 ),
               ),
              ...bookProvider.books.map(
                (book) => RadioListTile<String>(
                  value: book.id,
                  groupValue: bookProvider.activeBookId,
                  activeColor: cs.primary,
                  title: Text(
                    book.name,
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    book.id == bookProvider.activeBookId ? '当前账本' : '点击切换',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.65),
                    ),
                  ),
                  secondary: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 20, color: cs.onSurface),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRenameBookDialog(context, book.id, book.name);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: cs.onSurface),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(context, book.id);
                        },
                      ),
                    ],
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      bookProvider.selectBook(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openThemeSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        return Consumer<ThemeProvider>(
          builder: (ctx, themeProvider, _) {
            final theme = Theme.of(ctx);
            final cs = theme.colorScheme;
            final tt = theme.textTheme;
            final currentMode =
                themeProvider.mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
            final currentStyle = themeProvider.style;

            ButtonStyle segmentedStyle() {
              return ButtonStyle(
                textStyle: MaterialStatePropertyAll(tt.labelLarge),
                foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return cs.onPrimaryContainer;
                    }
                    return cs.onSurface;
                  },
                ),
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return cs.primaryContainer;
                    }
                    return cs.surfaceVariant.withOpacity(0.22);
                  },
                ),
                side: MaterialStateProperty.resolveWith<BorderSide?>(
                  (states) {
                    final color = states.contains(MaterialState.selected)
                        ? cs.primary.withOpacity(0.55)
                        : cs.outlineVariant.withOpacity(0.55);
                    return BorderSide(color: color, width: 1);
                  },
                ),
              );
            }

            return SafeArea(
              child: Material(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cs.outlineVariant.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Text(
                        '主题风格',
                        style: tt.titleMedium?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        style: segmentedStyle(),
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(AppStrings.themeLight),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(AppStrings.themeDark),
                          ),
                        ],
                        selected: {currentMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) {
                          themeProvider.setMode(value.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '主题色',
                        style: tt.labelLarge?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ThemePresetChip(
                            title: '海洋蓝',
                            subtitle: '现代活泼',
                            color: const Color(0xFF2F6BFF),
                            selected: currentStyle == AppThemeStyle.ocean,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.ocean),
                          ),
                          _ThemePresetChip(
                            title: '琥珀沙',
                            subtitle: '温暖柔和',
                            color: const Color(0xFFB66A2E),
                            selected: currentStyle == AppThemeStyle.amber,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.amber),
                          ),
                          _ThemePresetChip(
                            title: '石墨灰',
                            subtitle: '极简高级',
                            color: const Color(0xFF6B7280),
                            selected: currentStyle == AppThemeStyle.graphite,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.graphite),
                          ),
                          _ThemePresetChip(
                            title: '薄荷青',
                            subtitle: '清爽明亮',
                            color: const Color(0xFF14B8A6),
                            selected: currentStyle == AppThemeStyle.mint,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.mint),
                          ),
                          _ThemePresetChip(
                            title: '玫瑰粉',
                            subtitle: '柔和精致',
                            color: const Color(0xFFDB2777),
                            selected: currentStyle == AppThemeStyle.rose,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.rose),
                          ),
                          _ThemePresetChip(
                            title: '紫罗兰',
                            subtitle: '高级克制',
                            color: const Color(0xFF7C3AED),
                            selected: currentStyle == AppThemeStyle.violet,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.violet),
                          ),
                          _ThemePresetChip(
                            title: '珊瑚橙',
                            subtitle: '活力温暖',
                            color: const Color(0xFFFF6B4A),
                            selected: currentStyle == AppThemeStyle.coral,
                            onTap: () => themeProvider.setStyle(AppThemeStyle.coral),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showImportExportSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.file_upload_outlined,
                      color: cs.onSurface.withOpacity(0.7)),
                  title: Text(
                    '导入 CSV 数据',
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importCsv(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.table_chart_outlined,
                      color: cs.onSurface.withOpacity(0.7)),
                  title: Text(
                    '导出 CSV',
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExportSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDataSecuritySheet(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        final bookId = context.read<BookProvider>().activeBookId;
        final now = DateTime.now();
        final initialRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );

        void openExport(RecordsExportFormat format) {
          Navigator.pop(ctx);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExportDataPage(
                bookId: bookId,
                initialRange: initialRange,
                format: format,
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.file_upload_outlined,
                    color: cs.onSurface.withOpacity(0.7)),
                title: Text(
                  '导入 CSV 数据',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importCsv(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.grid_on_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出 Excel',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.excel),
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出 PDF',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.pdf),
              ),
              ListTile(
                leading: Icon(
                  Icons.table_chart_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出 CSV',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.csv),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        final bookId = context.read<BookProvider>().activeBookId;
        final now = DateTime.now();
        final initialRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );

        void openExport(RecordsExportFormat format) {
          Navigator.pop(ctx);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExportDataPage(
                bookId: bookId,
                initialRange: initialRange,
                format: format,
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.grid_on_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出为 Excel',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.excel),
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出为 PDF',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.pdf),
              ),
              ListTile(
                leading: Icon(
                  Icons.table_view_outlined,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                title: Text(
                  '导出为 CSV',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                onTap: () => openExport(RecordsExportFormat.csv),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAllCsv(BuildContext context) async {
    try {
      final recordProvider = context.read<RecordProvider>();
      final bookProvider = context.read<BookProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final accountProvider = context.read<AccountProvider>();

      final bookId = bookProvider.activeBookId;
      final records = recordProvider.recordsForBook(bookId);
      if (records.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showWarning(context, '当前账本暂无记录');
        }
        return;
      }

      final categoryMap = {
        for (final c in categoryProvider.categories) c.key: c,
      };
      final bookMap = {
        for (final b in bookProvider.books) b.id: b,
      };
      final accountMap = {
        for (final a in accountProvider.accounts) a.id: a,
      };

      final csv = buildCsvForRecords(
        records,
        categoriesByKey: categoryMap,
        booksById: bookMap,
        accountsById: accountMap,
      );

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final safeBookId = bookId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = 'remark_records_all_${safeBookId}_$dateStr.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, encoding: utf8);

      if (!context.mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '指尖记账导出 CSV',
        text: '指尖记账导出的全部记录 CSV，可在表格中查看分析。',
      );

      if (context.mounted) {
        ErrorHandler.showSuccess(context, 'CSV 导出成功');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final file = File(path);
      final content = await file.readAsString(encoding: utf8);

      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final bookProvider = context.read<BookProvider>();

      await Future.wait([
        if (!recordProvider.loaded) recordProvider.load(),
        if (!accountProvider.loaded) accountProvider.load(),
        if (!categoryProvider.loaded) categoryProvider.load(),
        if (!bookProvider.loaded) bookProvider.load(),
      ]);

      final categoriesByName = {
        for (final c in categoryProvider.categories) c.name: c,
      };
      final booksByName = {
        for (final b in bookProvider.books) b.name: b,
      };
      final accountsByName = {
        for (final a in accountProvider.accounts) a.name: a,
      };

      final defaultBookId = bookProvider.activeBookId;
      final defaultAccount = accountProvider.accounts.firstWhere(
        (a) => a.name == '现金',
        orElse: () => accountProvider.accounts.first,
      );
      final defaultAccountId = defaultAccount.id;
      final defaultCategory = categoryProvider.categories.firstWhere(
        (c) => !c.isExpense,
        orElse: () => categoryProvider.categories.first,
      );
      final defaultCategoryKey = defaultCategory.key;

      final imported = parseCsvToRecords(
        content,
        categoriesByName: categoriesByName,
        booksByName: booksByName,
        accountsByName: accountsByName,
        defaultBookId: defaultBookId,
        defaultAccountId: defaultAccountId,
        defaultCategoryKey: defaultCategoryKey,
      );

      if (imported.isEmpty) {
        if (context.mounted) {
          ErrorHandler.showWarning(context, 'CSV 文件中没有有效的记录');
        }
        return;
      }

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              final tt = Theme.of(ctx).textTheme;
              return AlertDialog(
                title: Text(
                  '导入记录',
                  style: tt.titleMedium?.copyWith(color: cs.onSurface),
                ),
                content: Text(
                  '将导入约 ${imported.length} 条记录，可能会与当前数据合并。是否继续？',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppStrings.cancel,
                        style: tt.labelLarge?.copyWith(color: cs.onSurface)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(AppStrings.ok),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmed) return;

      final ImportResult summary = await recordProvider.importRecords(
        imported,
        activeBookId: defaultBookId,
        accountProvider: accountProvider,
      );

      if (context.mounted) {
        if (summary.failureCount > 0) {
          ErrorHandler.showWarning(
            context,
            '导入完成：成功 ${summary.successCount} 条，失败 ${summary.failureCount} 条',
          );
        } else {
          ErrorHandler.showSuccess(
            context,
            '导入成功：已导入 ${summary.successCount} 条记录',
          );
        }
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, 'CSV 文件格式不正确：${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final loggedIn = _token != null && _token!.isNotEmpty;
    final bookCount = context.read<BookProvider>().books.length;
    if (!loggedIn && bookCount > 0) {
      ErrorHandler.showWarning(context, AppStrings.guestSingleBookOnly);
      _goLogin();
      return;
    }
    bool createAsMulti = false;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text(AppStrings.newBook),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: AppStrings.bookNameHint),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppStrings.bookNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (loggedIn)
                    SwitchListTile(
                      value: createAsMulti,
                      onChanged: (value) {
                        setState(() => createAsMulti = value);
                      },
                      title: const Text('创建为多人账本'),
                      subtitle: const Text('生成邀请码，可与好友共享（需登录）'),
                      contentPadding: EdgeInsets.zero,
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group_outlined),
                      title: const Text('多人账本需登录'),
                      subtitle: const Text('登录后可直接创建多人账本并生成邀请码'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _goLogin();
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                final name = controller.text.trim();

                if (!createAsMulti) {
                  await context.read<BookProvider>().addBook(name);
                  if (context.mounted) Navigator.pop(ctx);
                  return;
                }

                if (!loggedIn) {
                  ErrorHandler.showWarning(context, '未登录，请先登录');
                  return;
                }

                // Create server multi-book, then add it locally.
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final result = await BookService().createMultiBook(name);
                  final serverBookId =
                      (result['id'] as num?)?.toInt().toString() ?? '';
                  if (serverBookId.isEmpty) {
                    throw Exception('创建多人账本失败');
                  }
                  final inviteCode = result['inviteCode'] as String?;

                  final bookProvider = context.read<BookProvider>();
                  await bookProvider.addServerBook(serverBookId, name);
                  await bookProvider.selectBook(serverBookId);

                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop(); // loading
                  Navigator.pop(ctx); // add dialog

                  if (inviteCode != null && inviteCode.isNotEmpty) {
                    await _showInviteCodeDialog(
                      bookId: serverBookId,
                      bookName: name,
                      inviteCode: inviteCode,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // loading
                    ErrorHandler.handleAsyncError(context, e);
                  }
                }
              },
              child: const Text(AppStrings.save),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameBookDialog(
    BuildContext context,
    String id,
    String initialName,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    final bookProvider = context.read<BookProvider>();
     
    // 检查是否已登录
    final loggedIn = _token != null && _token!.isNotEmpty;
    final isMultiBook = int.tryParse(id) != null;
    String? inviteCodeCache;
    if (loggedIn && isMultiBook) {
      inviteCodeCache = await BookInviteCodeStore.instance.getInviteCode(id);
    }
     
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
        title: Text(
          '账本设置',
          style: tt.titleMedium?.copyWith(color: cs.onSurface),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: '账本名称',
                    hintText: AppStrings.bookNameHint,
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.78),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.bookNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // 多人账本功能
                if (loggedIn && isMultiBook) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined, color: cs.primary),
                    title: const Text('多人账本'),
                    subtitle: Text(
                      (inviteCodeCache?.isNotEmpty ?? false)
                          ? '邀请码：$inviteCodeCache'
                          : '邀请码：—',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: '复制邀请码',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            final code = inviteCodeCache;
                            if (code == null || code.isEmpty) {
                              ErrorHandler.showWarning(ctx, '暂无邀请码');
                              return;
                            }
                            await _copyToClipboard(code, successMessage: '邀请码已复制');
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      final code = inviteCodeCache;
                      if (code == null || code.isEmpty) {
                        ErrorHandler.showWarning(ctx, '暂无邀请码');
                        return;
                      }
                      await _showInviteCodeDialog(
                        bookId: id,
                        bookName: controller.text.trim().isEmpty ? initialName : controller.text.trim(),
                        inviteCode: code,
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.people_alt_outlined, color: cs.primary),
                    title: const Text('成员列表'),
                    subtitle: const Text('查看该账本下的成员'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookMembersPage(
                            bookId: id,
                            bookName: controller.text.trim().isEmpty
                                ? initialName
                                : controller.text.trim(),
                          ),
                        ),
                      );
                    },
                  ),
                ] else if (loggedIn && !isMultiBook) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined, color: cs.primary),
                    title: const Text('升级为多人账本'),
                    subtitle: const Text('生成邀请码，与好友共享账本'),
                    trailing: Switch(
                      value: false,
                      onChanged: (value) {
                        if (value) {
                          Navigator.pop(ctx);
                          _showUpgradeToMultiBookDialog(context, id);
                        }
                      },
                    ),
                  ),
                ] else ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline, color: cs.outline),
                    title: const Text('多人账本'),
                    subtitle: const Text('登录后可使用多人账本功能'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _goLogin();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.cancel,
              style: tt.labelLarge?.copyWith(color: cs.onSurface),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await bookProvider.renameBook(id, controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.save),
          )
        ],
      ),
      ),
    );
  }

  Future<void> _showUpgradeToMultiBookDialog(BuildContext context, String bookId) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bookService = BookService();
    final bookProvider = context.read<BookProvider>();
     
    try {
      final localBook = bookProvider.books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => bookProvider.activeBook ?? Book(id: bookId, name: '多人账本'),
      );

      // 调用后端 API 创建多人账本（服务器端新账本），并把本地账本迁移到该 server bookId。
      final result = await bookService.createMultiBook(localBook.name);
      final serverBookId =
          (result['id'] as num?)?.toInt().toString() ?? '';
      if (serverBookId.isNotEmpty) {
        await bookProvider.upgradeLocalBookToServer(
          bookId,
          serverBookId,
          queueUploadAllRecords: true,
        );
        // Kick an immediate bootstrap so migrated local data starts uploading right away.
        if (mounted) {
          await SyncEngine().forceBootstrapV2(context, serverBookId);
        }
      }
      final inviteCode = (result['inviteCode'] as String?)?.trim() ?? '';
      if (inviteCode.isEmpty) {
        throw Exception('服务器未返回邀请码，请稍后重试');
      }
      if (serverBookId.isNotEmpty) {
        await BookInviteCodeStore.instance.setInviteCode(serverBookId, inviteCode);
      }
     
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '多人账本',
          style: tt.titleMedium?.copyWith(color: cs.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('邀请码已生成，分享给好友即可加入账本：',
                style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        inviteCode,
                      style: tt.headlineSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                    IconButton(
                      icon: Icon(Icons.copy, color: cs.primary),
                      onPressed: () async {
                        await _copyToClipboard(inviteCode, successMessage: '邀请码已复制');
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showJoinInviteDialog();
              },
              icon: Icon(Icons.person_add, color: cs.primary),
              label: Text('输入邀请码加入其他账本',
                  style: tt.labelLarge?.copyWith(color: cs.primary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '关闭',
              style: tt.labelLarge?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
    } catch (e) {
      // 检查是否是付费相关错误
      final errorMsg = e.toString();
      if (_isPaymentRequiredError(errorMsg)) {
        if (mounted) {
          _showVipPurchasePage();
        }
      } else {
        if (mounted) {
          ErrorHandler.handleAsyncError(context, e);
        }
      }
    }
  }

  /// 检查是否是付费相关错误
  bool _isPaymentRequiredError(String error) {
    return error.contains('无权限') ||
        error.contains('需要付费') ||
        error.contains('请升级') ||
        error.contains('VIP') ||
        error.contains('会员') ||
        error.contains('无云端同步权限') ||
        error.contains('付费已过期') ||
        error.contains('数据量超限');
  }

  /// 显示VIP购买页面
  void _showVipPurchasePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VipPurchasePage()),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final provider = context.read<BookProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          AppStrings.deleteBook,
          style: tt.titleMedium?.copyWith(color: cs.onSurface),
        ),
        content: Text(
          AppStrings.confirmDeleteBook,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.78)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.cancel,
              style: tt.labelLarge?.copyWith(color: cs.primary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteBook(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: tt.titleMedium?.copyWith(color: cs.onSurface),
        ),
        content: Text(
          '该功能将在后续版本中完善，敬请期待。',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.78)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.ok,
              style: tt.labelLarge?.copyWith(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ThemePresetChip extends StatelessWidget {
  const _ThemePresetChip({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        width: 156,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withOpacity(0.8),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.95),
                    color.withOpacity(0.55),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: selected
                  ? Icon(Icons.check, color: cs.onPrimary, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
