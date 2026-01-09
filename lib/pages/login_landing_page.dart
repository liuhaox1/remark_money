import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/book_provider.dart';
import '../services/background_sync_manager.dart';
import '../services/sync_engine.dart';
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _afterLoginNavigateToRootShell() async {
    // Ensure the token is fully persisted before triggering sync/navigation.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Push any outbox ops created while logged out (e.g. first record before register/login).
    await SyncEngine().pushAllOutboxAfterLogin(context, reason: 'login');
    // Kick an immediate sync/meta sync after login so the UI won't show stale/empty data.
    BackgroundSyncManager.instance.start(context, triggerInitialSync: false);
    final activeBookId = context.read<BookProvider>().activeBookId;
    if (activeBookId.isNotEmpty) {
      BackgroundSyncManager.instance.requestMetaSync(activeBookId, reason: 'login');
      BackgroundSyncManager.instance.requestSync(activeBookId, reason: 'login');
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  Future<void> _onRegister() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }

    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (registered != true || !mounted) return;

    // DO NOT pushReplacement(LoginPage): if LoginPage later pops, the route stack may become empty
    // and the app will show a blank screen. Keep the landing page in the stack and navigate
    // to RootShell only after login success.
    final loginOk = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const account_login.LoginPage()),
    );
    if (loginOk == true && mounted) {
      await _afterLoginNavigateToRootShell();
    }
  }

  Future<void> _onLogin() async {
    if (!_agreed) {
      _showSnack('请先阅读并同意《用户协议》和《隐私协议》');
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const account_login.LoginPage()),
    );
    if (result != true || !mounted) return;

    await _afterLoginNavigateToRootShell();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
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
                      child: Text(
                        '注册',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _agreed ? _onLogin : null,
                      child: Text(
                        '登录',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        shape: const CircleBorder(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              '已阅读并同意 ',
                              style: tt.bodySmall?.copyWith(
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
                                style: tt.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              ' 和 ',
                              style: tt.bodySmall?.copyWith(
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
                                style: tt.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
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
