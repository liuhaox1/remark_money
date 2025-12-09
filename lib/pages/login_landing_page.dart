import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'root_shell.dart';

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

  Future<void> _onWeChatLogin() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }
    try {
      // 预留：接入原生微信 SDK 后，在这里获取 code
      // final code = await getWeChatAuthCode();
      // final result = await _auth.loginWithWeChat(code: code);
      // if (mounted) {
      //   Navigator.of(context).pushReplacement(
      //     MaterialPageRoute(builder: (_) => const RootShell()),
      //   );
      // }
      _showSnack('微信登录接入后在这里完成授权和登录');
    } catch (e) {
      if (mounted) {
        _showSnack('微信登录失败: $e');
      }
    }
  }

  Future<void> _onPhoneLogin() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SmsLoginPage()),
    );
    if (result == true && mounted) {
      // 登录成功，替换整个路由栈到主页面
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootShell()),
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
                  // 微信登录按钮（主按钮）
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD54F),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _agreed ? _onWeChatLogin : null,
                      child: const Text(
                        '微信登录',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 手机号登录按钮
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _agreed ? _onPhoneLogin : null,
                      child: const Text(
                        '使用手机号登录',
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
                                _showSnack('用户协议内容待接入');
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
                                _showSnack('隐私协议内容待接入');
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

