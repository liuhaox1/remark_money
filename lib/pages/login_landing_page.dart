import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'root_shell.dart';
import 'terms_privacy_page.dart';
import 'register_page.dart';
import 'account_login_page.dart' as account_login;

class LoginLandingPage extends StatefulWidget {
  const LoginLandingPage({super.key});

  @override
  State<LoginLandingPage> createState() => _LoginLandingPageState();
}

class _LoginLandingPageState extends State<LoginLandingPage> {
  bool _agreed = true;
  final _auth = const AuthService();

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _onRegister() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }
    // 跳转到注册页面
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (result == true && mounted) {
      // 注册成功后，跳转到登录页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const account_login.LoginPage()),
      );
    }
  }

  Future<void> _onLogin() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }
    // 跳转到登录页面
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const account_login.LoginPage()),
    );
    if (result == true && mounted) {
      // 登录成功，直接跳转到首页
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo + App 名称
            Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.currency_yen,
                    size: 48,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '指尖记账',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 注册按钮（主按钮）
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _agreed ? _onRegister : null,
                      child: const Text(
                        '注册',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 登录按钮
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _agreed ? _onLogin : null,
                      child: const Text(
                        '登录',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 协议勾选
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) =>
                            setState(() => _agreed = v ?? false),
                        shape: const CircleBorder(),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              '已阅读并同意 ',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TermsPrivacyPage(
                                      type: TermsPrivacyType.terms,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '《用户协议》',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            Text(
                              ' 和 ',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TermsPrivacyPage(
                                      type: TermsPrivacyType.privacy,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '《隐私协议》',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

