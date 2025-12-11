import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/sync_version_cache_service.dart';
import '../providers/book_provider.dart';
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
    if (result == true) {
      await _refreshToken();
      if (!mounted) return;
      
      // 登录成功后，拉取并缓存版本号
      try {
        final bookProvider = Provider.of<BookProvider>(context, listen: false);
        final bookId = bookProvider.activeBookId;
        if (bookId.isNotEmpty) {
          final cacheService = SyncVersionCacheService();
          await cacheService.fetchAndCacheVersion(bookId);
        }
      } catch (e) {
        // 忽略版本号拉取失败，不影响登录流程
      }
      
      Navigator.pop(context, true);
    }
  }
  
  Future<void> _handleLogout() async {
    await _authService.clearToken();
    
    // 退出登录时清除版本号缓存
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final bookId = bookProvider.activeBookId;
      if (bookId.isNotEmpty) {
        final cacheService = SyncVersionCacheService();
        await cacheService.clearCache(bookId);
      }
    } catch (e) {
      // 忽略清除缓存失败
    }
    
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('账号设置'),
        elevation: 0,
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
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
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    trailing: Text(
                      _isLoggedIn ? '已绑定账号' : '去登录',
                      style: TextStyle(
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
