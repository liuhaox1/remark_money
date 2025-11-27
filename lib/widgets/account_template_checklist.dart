import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/account_template.dart';
import '../providers/account_template_provider.dart';
import '../pages/account_form_page.dart';
import 'account_template_card.dart';

/// 账户模板激活Checklist组件
class AccountTemplateChecklist extends StatelessWidget {
  const AccountTemplateChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    final templateProvider = context.watch<AccountTemplateProvider>();
    final progress = templateProvider.getActivationProgress();

    // 如果所有推荐模板都已激活，则不显示
    if (progress.isComplete) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '推荐账户',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${progress.added}/${progress.total}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: progress.templates.map((info) {
                return AccountTemplateCard(
                  template: info.template,
                  status: info.status,
                  onTap: () => _handleTemplateTap(context, info.template),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTemplateTap(BuildContext context, AccountTemplate template) {
    Navigator.push<AccountKind>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountFormPage(
          kind: template.kind,
          subtype: template.subtype,
        ),
      ),
    );
  }
}

