import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_landing_page.dart';
import '../widgets/app_scaffold.dart';

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

      // v2 透明同步下不再调用 v1 /api/sync/status/query，避免触发 sync_record 频繁查询。
      
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }
  
  Future<void> _handleLogout() async {
    await _authService.clearToken();
    if (!mounted) return;

    // v2 透明同步下无需维护 v1 版本号缓存
    
    await _refreshToken();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已退出登录')));
    // 退出登录后，清除所有路由并跳转到登录页
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginLandingPage()),
      (route) => false, // 清除所有之前的路由
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: '账号设置',
      body: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: cs.onSurface),
          child: ListTileTheme(
            data: ListTileThemeData(
              titleTextStyle: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: cs.onSurface),
              subtitleTextStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
            ),
            child: Column(
            children: [
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('头像'),
                    trailing: CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primary.withOpacity(0.15),
                      child: Icon(
                        Icons.person_outline,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('登录状态'),
                    subtitle: Text(
                      _isLoggedIn ? '已登录' : '未登录',
                    ),
                    trailing: Text(
                      _isLoggedIn ? '已绑定账号' : '去登录',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isLoggedIn ? cs.onSurface : cs.primary,
                          ),
                    ),
                    onTap: _isLoggedIn ? null : _handleLogin,
                  ),
                  // 隐藏手机和微信登录相关选项
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _isLoggedIn ? cs.error : cs.onSurface,
                    side: BorderSide(
                      color: _isLoggedIn ? cs.error : cs.outline.withOpacity(0.6),
                    ),
                  ),
                  onPressed: _isLoggedIn ? _handleLogout : _handleLogin,
                  child: Text(_isLoggedIn ? '退出登录' : '登录指尖记账'),
                ),
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
