import 'package:flutter/material.dart';

/// 服务条款和隐私政策页面
class TermsPrivacyPage extends StatelessWidget {
  const TermsPrivacyPage({
    super.key,
    required this.type,
  });

  final TermsPrivacyType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = type == TermsPrivacyType.terms ? '用户协议' : '隐私政策';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              _getContent(type),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 24),
            // 如果设置了在线协议 URL，显示链接
            if (_getOnlineUrl(type) != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                '完整版本请访问：',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _launchUrl(context, _getOnlineUrl(type)!),
                child: Text(
                  _getOnlineUrl(type)!,
                  style: TextStyle(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) {
    // 如果需要打开外部链接，可以添加 url_launcher 依赖
    // 或者使用 showDialog 显示 URL 让用户复制
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('访问链接'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _getContent(TermsPrivacyType type) {
    if (type == TermsPrivacyType.terms) {
      return _termsContent;
    } else {
      return _privacyContent;
    }
  }

  String? _getOnlineUrl(TermsPrivacyType type) {
    // 如果设置了在线协议 URL，在这里返回
    // 例如：return 'https://your-domain.com/terms';
    return null;
  }

  // 用户协议内容（简化版，实际使用时需要根据应用情况完善）
  static const String _termsContent = '''
欢迎使用"指尖记账"应用！

在使用本应用之前，请您仔细阅读以下用户协议。使用本应用即表示您同意遵守本协议的所有条款。

一、服务说明
1. "指尖记账"是一款个人财务管理应用，帮助用户记录和管理个人收支情况。
2. 本应用提供的服务包括但不限于：记账、统计分析、预算管理等功能。

二、用户账户
1. 用户需要注册账户才能使用本应用的部分功能。
2. 用户有责任保护账户安全，对账户下的所有活动负责。
3. 如发现账户被盗用，请立即联系客服。

三、使用规范
1. 用户应合法、合规使用本应用，不得用于任何违法用途。
2. 用户不得恶意攻击、破坏本应用的正常运行。
3. 用户应保证提供的信息真实、准确。

四、知识产权
1. 本应用的所有知识产权归开发者所有。
2. 未经许可，不得复制、修改、传播本应用的任何内容。

五、免责声明
1. 本应用不对用户因使用本应用而产生的任何损失承担责任。
2. 本应用不保证服务的连续性、稳定性和准确性。

六、协议修改
1. 本协议可能会不定期更新，更新后的协议将在应用内公布。
2. 继续使用本应用即视为接受更新后的协议。

七、联系我们
如有任何问题，请通过应用内反馈功能联系我们。

最后更新时间：2024年12月
''';

  // 隐私政策内容（简化版，实际使用时需要根据应用情况完善）
  static const String _privacyContent = '''
"指尖记账"隐私政策

我们非常重视您的隐私保护。本隐私政策说明了我们如何收集、使用和保护您的个人信息。

一、信息收集
1. 账户信息：手机号码（用于登录验证）
2. 记账数据：您主动记录的收支信息、分类、备注等
3. 设备信息：设备型号、操作系统版本等（用于优化应用体验）
4. 使用数据：应用使用情况、功能使用频率等（用于改进服务）

二、信息使用
1. 我们使用收集的信息来：
   - 提供和改善应用服务
   - 进行数据分析和统计
   - 保障账户和数据安全
   - 发送重要通知

2. 我们不会：
   - 向第三方出售您的个人信息
   - 未经您同意将信息用于其他用途

三、信息存储
1. 您的数据主要存储在本地设备上。
2. 如使用云端同步功能，数据会加密存储在服务器上。
3. 我们采用行业标准的安全措施保护您的数据。

四、信息共享
1. 我们不会与第三方共享您的个人信息，除非：
   - 获得您的明确同意
   - 法律法规要求
   - 保护我们的合法权益

五、您的权利
1. 您可以随时查看、修改、删除您的个人信息。
2. 您可以注销账户，注销后我们将删除您的所有数据。
3. 您可以拒绝某些权限请求，但可能影响部分功能使用。

六、数据安全
1. 我们采用加密技术保护数据传输和存储。
2. 我们定期进行安全审计和漏洞修复。
3. 但请注意，任何数据传输和存储都无法保证100%安全。

七、未成年人保护
1. 本应用主要面向成年人使用。
2. 如您是未成年人，请在监护人指导下使用。

八、政策更新
1. 本隐私政策可能会不定期更新。
2. 重大变更时，我们会通过应用内通知告知您。

九、联系我们
如有任何隐私相关问题，请通过应用内反馈功能联系我们。

最后更新时间：2024年12月
''';
}

enum TermsPrivacyType {
  terms, // 用户协议
  privacy, // 隐私政策
}

