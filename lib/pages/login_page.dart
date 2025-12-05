import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  final _auth = const AuthService();

  bool _sendingCode = false;
  bool _loggingIn = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showSnack('请输入手机号');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await _auth.sendSmsCode(phone);
      _showSnack('验证码已发送');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _loginWithSms() async {
    final phone = _phoneCtrl.text.trim();
    final code = _smsCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      _showSnack('请输入手机号和验证码');
      return;
    }
    setState(() => _loggingIn = true);
    try {
      await _auth.loginWithSms(phone: phone, code: code);
      if (!mounted) return;
      _showSnack('登录成功');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _loginWithWeChat() async {
    _showSnack('请先接入微信 SDK，获取 code 后调用 AuthService.loginWithWeChat');
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
        title: const Text('登录'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _smsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '短信验证码',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendingCode ? null : _sendCode,
                    child:
                        Text(_sendingCode ? '发送中...' : '获取验证码'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loggingIn ? null : _loginWithSms,
                  child: Text(_loggingIn ? '登录中...' : '使用手机号登录'),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      '或使用微信登录',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loginWithWeChat,
                      child: const Text('微信登录'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

