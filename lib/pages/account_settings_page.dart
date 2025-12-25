import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/sync_engine.dart';
import '../providers/book_provider.dart';
import '../theme/ios_tokens.dart';
import '../widgets/app_scaffold.dart';
import 'login_landing_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.initialLoggedIn});

  final bool initialLoggedIn;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final AuthService _authService = const AuthService();
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialLoggedIn;
  }

  Future<void> _refreshToken() async {
    final token = await _authService.loadToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  Future<void> _handleLogin() async {
    final result = await Navigator.pushNamed(context, '/login');
    if (!mounted) return;
    if (result == true) {
      await _refreshToken();
      if (!mounted) return;
      // If user created records while logged out, push queued outbox ops immediately after login.
      final bookId = context.read<BookProvider>().activeBookId;
      if (bookId.isNotEmpty) {
        await SyncEngine().pushAllOutboxAfterLogin(context, reason: 'login');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.clearToken();
    if (!mounted) return;
    await _refreshToken();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已退出登录')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginLandingPage()),
      (route) => false,
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(
    BuildContext context,
    String text, {
    required bool positive,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = positive ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = positive ? cs.onPrimaryContainer : cs.onSurface.withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: '账号设置',
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                _sectionCard(
                  context: context,
                  children: [
                    ListTile(
                      title: const Text('头像'),
                      subtitle: Text(
                        _isLoggedIn ? '已登录，可更换头像' : '登录后可设置头像',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(
                              Icons.person_outline,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: cs.onSurface.withOpacity(0.35),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!_isLoggedIn) {
                          _handleLogin();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('头像功能开发中')),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('登录状态'),
                      subtitle: Text(_isLoggedIn ? '已登录' : '未登录'),
                      trailing: _isLoggedIn
                          ? _statusPill(context, '已绑定账号', positive: true)
                          : TextButton(
                              onPressed: _handleLogin,
                              child: Text(
                                '去登录',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                      onTap: _isLoggedIn ? null : _handleLogin,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoggedIn)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    onPressed: _handleLogout,
                    child: const Text('退出登录'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    onPressed: _handleLogin,
                    child: const Text('登录指尖记账'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
