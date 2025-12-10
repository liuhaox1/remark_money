import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// 注册页面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _auth = const AuthService();

  bool _registering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (username.isEmpty) {
      _showSnack('请输入账号');
      return;
    }
    if (password.isEmpty) {
      _showSnack('请输入密码');
      return;
    }
    if (password.length < 6) {
      _showSnack('密码长度至少6位');
      return;
    }
    if (password != confirmPassword) {
      _showSnack('两次输入的密码不一致');
      return;
    }

    setState(() => _registering = true);
    try {
      await _auth.register(username: username, password: password);
      if (!mounted) return;
      _showSnack('注册成功');
      // 注册成功后返回 true，让登录页面跳转到登录页
      Navigator.pop(context, true);
    } catch (e) {
      // 显示友好的错误提示
      String errorMessage = '注册失败，请稍后再试';
      if (e is RegisterException) {
        errorMessage = e.message;
      } else if (e.toString().contains('账号已存在') || 
                 e.toString().contains('用户名已存在')) {
        errorMessage = '该账号已被注册，请使用其他账号或直接登录';
      } else if (e.toString().isNotEmpty) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _showSnack(errorMessage);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('注册'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '账号',
                  hintText: '请输入账号（用户名）',
                  labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.person_outline, color: cs.onSurface.withOpacity(0.7)),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码（至少6位）',
                  labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withOpacity(0.7)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscureConfirmPassword,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '确认密码',
                  hintText: '请再次输入密码',
                  labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withOpacity(0.7)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _registering ? null : _register,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(_registering ? '注册中...' : '注册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

