import 'package:flutter/material.dart';

import '../data/account_templates.dart';
import '../models/account.dart';
import '../models/account_template.dart';
import 'account_provider.dart';

/// 账户模板Provider：管理模板状态和推荐逻辑
class AccountTemplateProvider extends ChangeNotifier {
  AccountTemplateProvider(this.accountProvider);

  final AccountProvider accountProvider;

  /// 获取所有模板
  List<AccountTemplate> get allTemplates => AccountTemplates.all;

  /// 获取推荐模板（常用账户）
  List<AccountTemplate> get recommendedTemplates =>
      AccountTemplates.getRecommended();

  /// 检查模板是否已添加
  bool isTemplateAdded(String templateId) {
    final template = allTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => throw StateError('Template not found: $templateId'),
    );

    // 检查是否有相同类型的账户
    final existing = accountProvider.accounts.where((a) {
      // 首先检查类型和子类型是否匹配
      if (a.kind != template.kind || a.subtype != template.subtype.code) {
        return false;
      }

      // 对于现金账户，只要subtype匹配就认为已添加
      if (template.subtype == AccountSubtype.cash) {
        return true;
      }

      // 对于其他账户，检查名称是否匹配（支持部分匹配）
      final accountName = a.name.toLowerCase();
      final templateName = template.displayName.toLowerCase();
      return accountName == templateName || 
             accountName.contains(templateName) ||
             templateName.contains(accountName);
    }).toList();

    return existing.isNotEmpty;
  }

  /// 获取模板的激活状态
  TemplateStatus getTemplateStatus(String templateId) {
    if (isTemplateAdded(templateId)) {
      return TemplateStatus.added;
    }
    return TemplateStatus.available;
  }

  /// 获取推荐模板的激活进度
  ActivationProgress getActivationProgress() {
    final recommended = recommendedTemplates;
    final addedCount = recommended
        .where((t) => isTemplateAdded(t.id))
        .length;

    return ActivationProgress(
      total: recommended.length,
      added: addedCount,
      templates: recommended.map((t) => TemplateStatusInfo(
        template: t,
        status: getTemplateStatus(t.id),
      )).toList(),
    );
  }

  /// 根据子类型获取模板列表（带状态）
  List<TemplateStatusInfo> getTemplatesBySubtype(AccountSubtype subtype) {
    final templates = AccountTemplates.getBySubtype(subtype);
    return templates.map((t) => TemplateStatusInfo(
      template: t,
      status: getTemplateStatus(t.id),
    )).toList();
  }

  /// 根据分类获取模板列表（带状态）
  List<TemplateStatusInfo> getTemplatesByCategory(String category) {
    final templates = AccountTemplates.getByCategory(category);
    return templates.map((t) => TemplateStatusInfo(
      template: t,
      status: getTemplateStatus(t.id),
    )).toList();
  }
}

/// 模板状态
enum TemplateStatus {
  available, // 可添加
  added, // 已添加
}

/// 模板状态信息
class TemplateStatusInfo {
  const TemplateStatusInfo({
    required this.template,
    required this.status,
  });

  final AccountTemplate template;
  final TemplateStatus status;
}

/// 激活进度
class ActivationProgress {
  const ActivationProgress({
    required this.total,
    required this.added,
    required this.templates,
  });

  final int total;
  final int added;
  final List<TemplateStatusInfo> templates;

  double get progress => total > 0 ? added / total : 0.0;
  bool get isComplete => added >= total;
}

