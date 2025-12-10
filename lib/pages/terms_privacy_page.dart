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

  // 用户协议内容（针对“指尖记账”应用的合规草案）
  static const String _termsContent = '''
用户协议（适用于“指尖记账”）

一、协议范围与接受
1. 本协议由您与“指尖记账”运营方订立，规范您使用本应用的权利与义务。
2. 您安装、注册、登录或使用本应用即视为已阅读并同意本协议全部条款。

二、服务内容
1. 本应用提供个人收支记录、分类管理、预算/统计展示、账户管理与转账记录、短信登录、微信登录、数据导出/备份等功能。
2. 部分功能依赖网络、短信服务、微信平台或操作系统权限；因第三方或网络原因导致的中断或限制，我们将在合理范围内协助排查，但不对第三方服务可用性承担保证责任。

三、账户与安全
1. 您可通过手机号（短信验证码）或微信登录；请妥善保管登录凭证，不向他人泄露。
2. 如发现账号被盗用或存在安全风险，请立即联系我们并配合处理。
3. 您需对账号下的所有操作负责，包括数据录入、修改、删除、导出等。

四、用户行为规范
1. 遵守法律法规，不得利用本应用从事违法违规或侵害他人权益的行为。
2. 不得对本应用进行逆向工程、恶意攻击、干扰或破坏。
3. 不得上传、发布违法、侵权、低俗、垃圾信息或其他不当内容。
4. 对违反本条的行为，我们有权视情节采取警告、限制功能、暂停或终止服务等措施，并可配合监管依法处理。

五、知识产权
1. 本应用的代码、界面、功能逻辑、商标与标识等受法律保护，归我们或相关权利人所有。
2. 未经书面许可，您不得复制、修改、传播、出售或以其他方式使用上述内容。
3. 您在使用本应用过程中生成的合法数据归您所有，我们依据隐私政策进行处理与保护。

六、第三方服务
1. 短信登录由短信服务商提供，微信登录由微信平台提供；使用第三方服务时，还应遵守该第三方条款与政策。
2. 因第三方原因导致的服务中断、延迟或数据错误，我们将在合理范围内协助，但不承担超出法定范围的责任。

七、费用与结算
1. 当前基础功能免费；如后续提供付费或增值服务，将另行公示价格与规则并征得您同意。
2. 使用本应用可能产生的流量费、短信费等由运营商或第三方收取。

八、免责与责任限制
1. 因不可抗力、网络故障、第三方服务异常等原因导致的服务中断或数据异常，我们不承担因无法合理预见或不可避免造成的损失责任。
2. 我们不对您基于本应用的财务决策或结果提供保证或担保。
3. 在法律允许范围内，对于任何间接、附带、惩罚性或特殊损害，我们不承担责任。

九、协议变更与终止
1. 我们可能根据运营或法律要求更新本协议，并在应用内公示或以合理方式通知；更新后继续使用视为接受变更。
2. 您可随时停止使用并注销账户（如提供该功能）；如您严重违反本协议，我们有权暂停或终止部分或全部服务。

十、适用法律与争议解决
1. 本协议适用中华人民共和国法律。
2. 因本协议产生的争议，双方应友好协商；协商不成的，提交我们所在地有管辖权的人民法院诉讼解决。

十一、联系方式
如有问题或建议，请通过应用内反馈与我们联系。

2025年12月
''';

  // 隐私政策内容（针对“指尖记账”应用的合规草案）
  static const String _privacyContent = '''
隐私政策（适用于“指尖记账”）

一、总则
我们重视您的个人信息和隐私保护。本政策说明我们如何收集、使用、存储、共享及保护您的信息，并说明您的权利。

二、我们收集的信息
1. 账户信息：手机号（短信登录）、微信返回的 openId/unionId、昵称、头像（如有）。
2. 设备与日志：设备型号、系统版本、设备标识、网络类型、操作/崩溃日志（用于安全与性能优化）。
3. 记账与资产相关：账本、账户、转账记录、收支金额、分类、备注、时间、汇率/币种（如有）、预算和统计数据。
4. 反馈信息：您在反馈中主动提供的联系方式或问题描述。

三、使用目的
1. 提供与维护核心功能：记账、账户管理、转账记录、分类管理、预算与统计、登录认证。
2. 身份验证与安全：短信/微信登录、风控、异常检测、防止恶意访问。
3. 服务优化：性能监测、故障排查、功能改进、体验优化。
4. 通知与提醒：重要变更、安全提醒、功能更新（在您开启或同意的情况下）。
5. 符合法律法规或监管要求的其他用途。

四、存储与保护
1. 存储位置：本地（记账数据、分类、偏好等）和服务器（登录凭证、必要业务数据，如启用云端相关功能）。
2. 存储期限：为实现目的所需的最短期限内保存；期限届满后删除或匿名化，法律法规另有规定的除外。
3. 安全措施：访问控制、加密传输（HTTPS）、最小化授权等。发生安全事件时，将按法规要求告知并采取补救措施。

五、共享与委托处理
1. 不出售您的个人信息。
2. 仅在以下情形共享或委托处理：
   - 取得您的明确同意；
   - 实现短信发送（短信服务商）、微信登录（微信平台）等必要功能；
   - 法律法规或监管要求。
3. 我们要求第三方承担相应的数据保护义务，确保您的信息安全。

六、第三方服务/SDK
为实现短信登录、微信登录，可能集成：
- 短信服务商：发送验证码（收集手机号、发送状态等）。
- 微信开放平台：微信登录（收集 code、openid/unionid、昵称、头像等）。
请同时查阅相应第三方的隐私政策。

七、您的权利
1. 访问、更正、删除：可在应用内查看、编辑、删除您的记账数据和账户信息；登录凭证可通过退出登录清除。
2. 撤回同意：可停止使用相关功能或关闭权限设置（可能影响部分功能）。
3. 注销账户：可通过应用内反馈申请注销；注销后我们将删除或匿名化处理您的个人信息，法律法规另有规定的除外。
4. 获取副本：在符合法律法规的范围内，您可申请导出或获取您的个人信息副本。

八、Cookie/本地存储
为提升体验，可能使用本地缓存/存储（含 Web 端 localStorage 等）保存会话信息、偏好设置等，不用于跨站跟踪或广告投放。

九、未成年人保护
本应用主要面向成年人。如为未成年人，请在监护人同意与指导下使用；我们不以未成年人为目标用户，不主动收集未成年人的个人信息。

十、国际/跨境传输
当前数据计划存储和处理在境内。如未来涉及跨境传输，将遵守相关法律法规并在必要时征得您的同意。

十一、变更与通知
隐私政策更新后，我们会在应用内提示或通过合理方式通知；重大变更将单独提示。继续使用视为接受更新。

十二、联系我们
如有隐私相关问题、建议或投诉，请通过应用内反馈渠道联系我们，我们会尽快处理。

2025年12月
''';
}

enum TermsPrivacyType {
  terms, // 用户协议
  privacy, // 隐私政策
}

