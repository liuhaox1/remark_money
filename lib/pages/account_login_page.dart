import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/network_guard.dart';
import '../theme/ios_tokens.dart';
import '../widgets/app_scaffold.dart';

/// 账号密码登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = const AuthService();

  bool _loggingIn = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty) {
      _showSnack('请输入账号');
      return;
    }
    if (password.isEmpty) {
      _showSnack('请输入密码');
      return;
    }

    setState(() => _loggingIn = true);
    try {
      await _auth.login(username: username, password: password);
      if (!mounted) return;
      _showSnack('登录成功');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(formatNetworkError(e), isError: true);
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          msg,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isError ? cs.error : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppScaffold(
      title: '登录',
      body: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.page.copyWith(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '账号',
                  hintText: '请输入账号',
                  labelStyle: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                  hintStyle: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: cs.onSurface.withOpacity(0.7)),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  labelStyle: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                  hintStyle: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withOpacity(0.7)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loggingIn ? null : _login,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(_loggingIn ? '登录中...' : '登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
