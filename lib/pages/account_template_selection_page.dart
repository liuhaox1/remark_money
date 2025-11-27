import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/account_template_provider.dart';
import 'account_form_page.dart';

/// 账户模板选择页面（用于选择品牌模板）
class AccountTemplateSelectionPage extends StatelessWidget {
  const AccountTemplateSelectionPage({
    super.key,
    required this.subtype,
  });

  final AccountSubtype subtype;

  @override
  Widget build(BuildContext context) {
    final templateProvider = context.watch<AccountTemplateProvider>();
    final templates = templateProvider.getTemplatesBySubtype(subtype);

    String title;
    switch (subtype) {
      case AccountSubtype.savingCard:
        title = '添加储蓄卡';
        break;
      case AccountSubtype.virtual:
        title = '添加虚拟账户';
        break;
      case AccountSubtype.creditCard:
        title = '添加信用卡';
        break;
      default:
        title = '选择账户';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('暂无可用模板'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final info = templates[index];
                final template = info.template;
                final isAdded = info.status == TemplateStatus.added;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: template.brandColor != null
                          ? Color(template.brandColor!).withOpacity(0.1)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIcon(template.icon),
                      color: template.brandColor != null
                          ? Color(template.brandColor!)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    template.name,
                    style: TextStyle(
                      decoration: isAdded ? TextDecoration.lineThrough : null,
                      color: isAdded
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
                  ),
                  subtitle: template.description != null
                      ? Text(template.description!)
                      : null,
                  trailing: isAdded
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: isAdded
                      ? null
                      : () {
                          Navigator.push<AccountKind>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountFormPage(
                                kind: template.kind,
                                subtype: template.subtype,
                                template: template,
                              ),
                            ),
                          );
                        },
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: templates.length,
            ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'alipay':
        return Icons.qr_code_2_outlined;
      case 'wechat':
        return Icons.chat_bubble_outline;
      case 'icbc':
      case 'ccb':
      case 'abc':
      case 'boc':
      case 'cmb':
      case 'bocom':
      case 'citic':
      case 'spdb':
      case 'ceb':
      case 'cgb':
        return Icons.credit_card;
      case 'huabei':
      case 'baitiao':
        return Icons.credit_card_rounded;
      case 'stock':
        return Icons.show_chart;
      case 'fund':
        return Icons.trending_up;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

