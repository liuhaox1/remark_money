import 'package:flutter/material.dart';

import '../models/account_template.dart';
import '../providers/account_template_provider.dart';

/// 账户模板卡片
class AccountTemplateCard extends StatelessWidget {
  const AccountTemplateCard({
    super.key,
    required this.template,
    required this.status,
    this.onTap,
  });

  final AccountTemplate template;
  final TemplateStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdded = status == TemplateStatus.added;
    final brandColor = template.brandColor != null
        ? Color(template.brandColor!)
        : cs.primary;

    return InkWell(
      onTap: isAdded ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isAdded
              ? cs.surfaceVariant.withOpacity(0.5)
              : brandColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAdded
                ? cs.outline.withOpacity(0.3)
                : brandColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isAdded
                    ? cs.outline.withOpacity(0.2)
                    : brandColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getIcon(template.icon),
                size: 18,
                color: isAdded ? cs.outline : brandColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              template.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isAdded ? cs.outline : cs.onSurface,
                decoration: isAdded ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isAdded) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: 16,
                color: cs.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String iconName) {
    // 简单的图标映射，实际应该使用更完善的图标系统
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

