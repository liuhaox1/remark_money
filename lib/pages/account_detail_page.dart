import 'package:flutter/material.dart';

import 'account_records_page.dart';

/// 账户详情页（历史原因：外部仍使用 AccountDetailPage 进行导航）
///
/// 当前实现复用 `AccountRecordsPage`，展示该账户的流水与编辑入口。
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({
    super.key,
    required this.accountId,
  });

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return AccountRecordsPage(accountId: accountId);
  }
}
