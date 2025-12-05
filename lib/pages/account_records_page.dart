import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../providers/category_provider.dart';
import '../utils/date_utils.dart';
import '../theme/app_tokens.dart';
import 'add_record_page.dart';

/// 账户流水列表页
class AccountRecordsPage extends StatelessWidget {
  const AccountRecordsPage({
    super.key,
    required this.accountId,
  });

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();

    // 检查加载状态
    if (!accountProvider.loaded || !recordProvider.loaded || 
        !categoryProvider.loaded || !bookProvider.loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('账户流水')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final account = accountProvider.byId(accountId);
    final bookId = bookProvider.activeBookId;

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('账户流水')),
        body: const Center(child: Text('账户不存在')),
      );
    }

    // 使用 FutureBuilder 异步加载账户记录（支持100万条记录）
    return FutureBuilder<List<Record>>(
      future: recordProvider.recordsForBookAsync(bookId).then((records) => 
        records.where((r) => r.accountId == accountId).toList()
          ..sort((a, b) => b.date.compareTo(a.date))
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text('${account.name} - 流水')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('${account.name} - 流水')),
            body: Center(child: Text('加载失败: ${snapshot.error}')),
          );
        }

        final allRecords = snapshot.data ?? [];
        
        // 按日期分组
        final groupedRecords = _groupRecordsByDate(allRecords);
        final categoryMap = {
          for (final c in categoryProvider.categories) c.key: c,
        };

        // 计算统计
        final totalIncome = allRecords
            .where((r) => r.isIncome)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final totalExpense = allRecords
            .where((r) => r.isExpense)
            .fold<double>(0, (sum, r) => sum + r.amount);
        final netChange = totalIncome - totalExpense;

        return Scaffold(
      appBar: AppBar(
        title: Text('${account.name} - 流水'),
      ),
      body: Column(
        children: [
          // 统计卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    '收入',
                    totalIncome,
                    AppColors.success,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '支出',
                    totalExpense,
                    AppColors.danger,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '净变化',
                    netChange,
                    AppColors.amount(netChange),
                  ),
                ),
              ],
            ),
          ),
          // 流水列表
          Expanded(
            child: allRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无流水记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddRecordPage(isExpense: false),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('记一笔'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groupedRecords.length,
                    itemBuilder: (context, index) {
                      final group = groupedRecords[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 日期标题
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatDateHeader(group.date),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          // 记录列表
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < group.records.length; i++)
                                  _buildRecordTile(
                                    context,
                                    group.records[i],
                                    categoryMap,
                                    i < group.records.length - 1,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value >= 0 ? '+${value.toStringAsFixed(2)}' : value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    Record record,
    Map<String, Category> categoryMap,
    bool showDivider,
  ) {
    final category = categoryMap[record.categoryKey];
    final isIncome = record.isIncome;
    final amountColor = isIncome ? AppColors.success : AppColors.danger;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRecordPage(initialRecord: record),
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    category?.icon ?? Icons.category_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? record.categoryKey,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (record.remark.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.remark,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isIncome ? '+' : '-'}${record.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              indent: 60,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withOpacity(0.4),
            ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (DateUtilsX.isSameDay(date, now)) {
      return '今天';
    }
    if (DateUtilsX.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return '昨天';
    }
    return DateUtilsX.ymd(date);
  }

  List<_RecordGroup> _groupRecordsByDate(List<Record> records) {
    final groups = <DateTime, List<Record>>{};
    for (final record in records) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      groups.putIfAbsent(day, () => []).add(record);
    }
    return groups.entries
        .map((e) => _RecordGroup(date: e.key, records: e.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _RecordGroup {
  const _RecordGroup({
    required this.date,
    required this.records,
  });

  final DateTime date;
  final List<Record> records;
}

