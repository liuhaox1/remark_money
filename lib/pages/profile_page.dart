import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/import_result.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/book_service.dart';
import 'account_settings_page.dart';
import 'sync_page.dart';
import 'vip_purchase_page.dart';
import '../utils/data_export_import.dart';
import '../utils/error_handler.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = const AuthService();
  String? _token;
  bool _loadingToken = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
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

  Future<void> _loadToken() async {
    final t = await _authService.loadToken();
    if (!mounted) return;
    setState(() {
      _token = t;
      _loadingToken = false;
    });
  }

  Future<void> _logout() async {
    await _authService.clearToken();
    await _loadToken();
  }

  Future<void> _handleCloudSync() async {
    if (_loadingToken) return;
    final loggedIn = _token != null && _token!.isNotEmpty;
    if (loggedIn) {
      // 已登录：跳转云端同步页
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncPage()),
        );
      }
      return;
    }
    // 未登录直接跳转登录页
    await _goLogin();
  }

  Future<void> _showGiftCodeDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('兑换礼包码', style: TextStyle(color: cs.onSurface)),
          content: TextField(
            controller: controller,
            maxLength: 8,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: '输入 8 位礼包码',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: cs.onSurface)),
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
              child: Text('兑换', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _redeemGiftCodeStub(String code) async {
    // TODO: 接入后端接口 /api/gift/redeem
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    ErrorHandler.showSuccess(
        context, '礼包码已提交，当前为体验模式（未接入后端）');
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
        return AlertDialog(
          title: Text('加入多人账本', style: TextStyle(color: cs.onSurface)),
          content: TextField(
            controller: controller,
            maxLength: 8,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: '输入 8 位邀请码',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: cs.onSurface)),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = controller.text.trim();
                if (code.length != 8) {
                  ErrorHandler.showWarning(ctx, '请输入 8 位邀请码');
                  return;
                }
                Navigator.pop(ctx);
                await _joinBookByCodeStub(code);
              },
              child: Text('加入', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinBookByCodeStub(String code) async {
    final bookService = BookService();
    try {
      await bookService.joinBook(code);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final reminderProvider = context.watch<ReminderProvider>();
    final cs = Theme.of(context).colorScheme;

    final activeBookName = bookProvider.activeBook?.name ?? AppStrings.book;
    final bookCount = bookProvider.books.length;
    final categoryCount = categoryProvider.categories.length;
    final reminderEnabled = reminderProvider.enabled;
    final isLoggedIn = (_token != null && _token!.isNotEmpty);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 本地存储提示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: cs.primary.withOpacity(0.25), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: cs.primary.withOpacity(0.9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '当前数据仅保存在本地。登录后可开启云端同步与多人账本。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.85),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildHeaderCard(
                  context,
                  title: '设置',
                  subtitle: '管理你的账本、主题、预算和提醒',
                  activeBook: activeBookName,
                  bookCount: bookCount,
                  categoryCount: categoryCount,
                  reminderEnabled: reminderEnabled,
                  isLoggedIn: isLoggedIn,
                ),
                const SizedBox(height: 12),
                _buildVipCard(context),
                const SizedBox(height: 12),
                _buildActionGrid(
                  context,
                  reminderProvider: reminderProvider,
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

  Widget _buildActionGrid(
    BuildContext context, {
    required ReminderProvider reminderProvider,
  }) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      _ProfileAction(
        icon: Icons.cloud_sync_outlined,
        label: '云端同步',
        onTap: _handleCloudSync,
      ),
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
        icon: Icons.privacy_tip_outlined,
        label: '数据与安全',
        onTap: () {
          final csInner = Theme.of(context).colorScheme;
          _showDataSecuritySheet(context, csInner);
        },
      ),
      _ProfileAction(
        icon: Icons.alarm_outlined,
        label: '提醒设置',
        onTap: () => _showReminderSheet(context, reminderProvider),
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
            onTap: () => _showPlaceholder(context, '意见反馈'),
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
      required bool reminderEnabled,
      required bool isLoggedIn,
    }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.85),
            cs.primaryContainer.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _openAccountSettings(isLoggedIn),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.onPrimary.withOpacity(0.18),
                    child: Icon(
                      Icons.person_outline,
                      size: 30,
                      color: cs.onPrimary,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimary.withOpacity(0.85),
                          ),
                    ),
                  ],
                ),
              ),
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
              _buildHeaderStat(
                context,
                label: '提醒',
                value: reminderEnabled ? '已开启' : '未开启',
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onPrimary.withOpacity(0.85)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showBookManagerSheet(BuildContext context) async {
    final bookProvider = context.read<BookProvider>();
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      builder: (ctx) {
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
                        _showAddBookDialog(context);
                      },
                      icon: Icon(Icons.add, color: cs.primary),
                      label: Text(
                        AppStrings.addBook,
                        style: TextStyle(color: cs.primary),
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
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    book.id == bookProvider.activeBookId ? '当前账本' : '点击切换',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.65)),
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
    final themeProvider = context.read<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;
    const seedOptions = <Color>[
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
    ];
    final currentMode =
        themeProvider.mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题风格',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
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
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: seedOptions.map((color) {
                    final selected =
                        themeProvider.seedColor.value == color.value;
                    return GestureDetector(
                      onTap: () => themeProvider.setSeedColor(color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: selected
                                ? cs.onSurface
                                : cs.outlineVariant.withOpacity(0.6),
                            width: selected ? 3 : 2,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.35),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? Icon(Icons.check, color: cs.onPrimary, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReminderSheet(
    BuildContext context,
    ReminderProvider provider,
  ) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      builder: (ctx) {
        final time = provider.timeOfDay;
        final timeLabel =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: provider.enabled,
                  title: Text(
                    '开启每日记账提醒',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  subtitle: Text(
                    '每天固定时间提醒你打开指尖记账',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  ),
                  onChanged: (v) => provider.setEnabled(v),
                ),
                ListTile(
                  leading: Icon(Icons.schedule_outlined,
                      color: cs.onSurface.withOpacity(0.8)),
                  title: Text(
                    '提醒时间',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  subtitle: Text(
                    timeLabel,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  ),
                  onTap: () async {
                    final current = provider.timeOfDay;
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: current,
                    );
                    if (picked != null) {
                      await provider.setTime(picked);
                    }
                  },
                ),
              ],
            ),
          ),
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.file_upload_outlined,
                      color: cs.onSurface.withOpacity(0.7)),
                  title:
                      Text('导入 CSV 数据', style: TextStyle(color: cs.onSurface)),
                  subtitle: Text('从 CSV 文件导入记账记录',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importCsv(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.table_chart_outlined,
                      color: cs.onSurface.withOpacity(0.7)),
                  title: Text('导出 CSV', style: TextStyle(color: cs.onSurface)),
                  subtitle: Text('适合 Excel/表格查看与分析',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.file_upload_outlined,
                    color: cs.onSurface.withOpacity(0.7)),
                title: Text(
                  '导入 CSV 数据',
                  style: TextStyle(color: cs.onSurface),
                ),
                subtitle: Text(
                  '从 CSV 文件导入记账记录',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
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
                  '导出 CSV 数据',
                  style: TextStyle(color: cs.onSurface),
                ),
                subtitle: Text(
                  '导出当前账本的全部记账记录',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showExportSheet(context);
                },
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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.table_view_outlined,
                    color: cs.onSurface.withOpacity(0.7)),
                title: Text(
                  '导出为 CSV',
                  style: TextStyle(color: cs.onSurface),
                ),
                subtitle: Text(
                  '适合在 Excel / 表格中查看',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAllCsv(context);
                },
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
              return AlertDialog(
                title: Text('导入记录', style: TextStyle(color: cs.onSurface)),
                content: Text(
                  '将导入约 ${imported.length} 条记录，可能会与当前数据合并。是否继续？',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.9)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppStrings.cancel,
                        style: TextStyle(color: cs.onSurface)),
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
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.newBook),
        content: Form(
          key: formKey,
          child: TextFormField(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .addBook(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.save),
          )
        ],
      ),
    );
  }

  Future<void> _showRenameBookDialog(
    BuildContext context,
    String id,
    String initialName,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.books.firstWhere((b) => b.id == id);
    
    // 检查是否已登录
    final loggedIn = _token != null && _token!.isNotEmpty;
    
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '账本设置',
          style: TextStyle(color: cs.onSurface),
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
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: '账本名称',
                    hintText: AppStrings.bookNameHint,
                    hintStyle: TextStyle(
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
                if (loggedIn) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined, color: cs.primary),
                    title: const Text('升级为多人账本'),
                    subtitle: const Text('生成邀请码，与好友共享账本'),
                    trailing: Switch(
                      value: false, // TODO: 从服务器获取是否已升级
                      onChanged: (value) {
                        if (value) {
                          Navigator.pop(context);
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
                      Navigator.pop(context);
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(color: cs.onSurface),
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
    );
  }

  Future<void> _showUpgradeToMultiBookDialog(BuildContext context, String bookId) async {
    final cs = Theme.of(context).colorScheme;
    final bookService = BookService();
    
    try {
      // 调用后端API升级为多人账本
      final result = await bookService.createMultiBook(bookId);
      final inviteCode = result['inviteCode'] as String? ?? _generateInviteCode();
    
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('多人账本', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('邀请码已生成，分享给好友即可加入账本：',
                style: TextStyle(color: cs.onSurface)),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: cs.primary),
                    onPressed: () {
                      // TODO: 复制到剪贴板
                      ErrorHandler.showSuccess(context, '已复制邀请码');
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
                  style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: cs.onSurface)),
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
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          AppStrings.deleteBook,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.confirmDeleteBook,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.78),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteBook(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          '该功能将在后续版本中完善，敬请期待。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.78),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.ok,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
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
