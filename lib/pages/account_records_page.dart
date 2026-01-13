import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/tag.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../services/book_service.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../utils/error_handler.dart';
import '../widgets/brand_logo_avatar.dart';
import '../widgets/number_pad_sheet.dart';
import 'account_form_page.dart';
import 'add_record_page.dart';

class AccountRecordsPage extends StatefulWidget {
  const AccountRecordsPage({
    super.key,
    required this.accountId,
  });

  final String accountId;

  static const Map<String, ({String name, IconData icon})> _internalCategoryUi = {
    'saving-in': (name: '存入', icon: Icons.call_received_rounded),
    'saving-out': (name: '转出', icon: Icons.call_made_rounded),
    'transfer-in': (name: '转入', icon: Icons.call_received_rounded),
    'transfer-out': (name: '转出', icon: Icons.call_made_rounded),
    'transfer-fee': (name: '手续费', icon: Icons.receipt_long_rounded),
  };

  @override
  State<AccountRecordsPage> createState() => _AccountRecordsPageState();
}

class _AccountRecordsPageState extends State<AccountRecordsPage> {
  late int _selectedYear;
  final Set<int> _expandedMonths = <int>{};
  String? _recordsKey;
  Future<List<Record>>? _recordsFuture;
  String? _tagsKey;
  Future<Map<String, List<Tag>>>? _tagsFuture;
  String? _membersBookId;
  Map<int, String> _memberNameById = const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _expandedMonths.add(now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureMemberNames();
  }

  Future<void> _ensureMemberNames() async {
    final bookId = context.read<BookProvider>().activeBookId;
    if (_membersBookId == bookId) return;
    _membersBookId = bookId;
    if (int.tryParse(bookId) == null) {
      if (mounted) setState(() => _memberNameById = const {});
      return;
    }
    try {
      final members = await BookService().listMembers(bookId);
      final next = <int, String>{};
      for (final m in members) {
        final uid = (m['userId'] as num?)?.toInt();
        if (uid == null || uid <= 0) continue;
        final nickname = (m['nickname'] as String?)?.trim();
        final username = (m['username'] as String?)?.trim();
        next[uid] = (nickname != null && nickname.isNotEmpty)
            ? nickname
            : (username != null && username.isNotEmpty)
                ? username
                : '用户$uid';
      }
      if (!mounted) return;
      setState(() => _memberNameById = next);
    } catch (_) {}
  }

  String _memberName(int? userId) {
    if (userId == null || userId <= 0) return '';
    return _memberNameById[userId] ?? '用户$userId';
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return List<int>.generate(10, (i) => now - i);
  }

  Future<void> _openYearSelector() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final y in _yearOptions())
                ListTile(
                  title: Text('$y年'),
                  trailing:
                      y == _selectedYear ? Icon(Icons.check_rounded, color: cs.primary) : null,
                  onTap: () => Navigator.of(ctx).pop(y),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == _selectedYear) return;
    setState(() {
      _selectedYear = selected;
      _expandedMonths
        ..clear()
        ..add(12);
      _recordsKey = null;
      _recordsFuture = null;
      _tagsKey = null;
      _tagsFuture = null;
    });
  }

  void _toggleMonth(int month) {
    setState(() {
      if (_expandedMonths.contains(month)) {
        _expandedMonths.remove(month);
      } else {
        _expandedMonths.add(month);
      }
    });
  }

  String _dayBadge(DateTime date) {
    final now = DateTime.now();
    if (DateUtilsX.isSameDay(date, now)) return '今天';
    if (DateUtilsX.isSameDay(date, now.subtract(const Duration(days: 1)))) return '昨天';
    return '星期${DateUtilsX.weekdayShort(date)}';
  }

  Future<void> _openActionsSheet(Account account) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑账户'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountFormPage(
                        kind: account.kind,
                        subtype: AccountSubtype.fromCode(account.subtype),
                        account: account,
                        initialBrandKey: account.brandKey,
                        presetName: account.name,
                        customTitle: '编辑账户',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('调整余额'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _adjustBalance(account);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('记一笔'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddRecordPage(isExpense: false),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _adjustBalance(Account account) async {
    final bookId = context.read<BookProvider>().activeBookId;
    if (int.tryParse(bookId) != null) {
      try {
        final ok = await BookService().isCurrentUserOwner(bookId);
        if (!ok) {
          if (mounted) {
            ErrorHandler.showWarning(context, '多人账本仅创建者可修改账户');
          }
          return;
        }
      } catch (_) {}
    }

    final amountCtrl =
        TextEditingController(text: account.currentBalance.toStringAsFixed(2));
    try {
      final nextBalance = await showDialog<double?>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('调整余额'),
            content: TextField(
              controller: amountCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                hintText: '请输入余额',
              ),
              onTap: () async {
                await showNumberPadBottomSheet(
                  ctx,
                  controller: amountCtrl,
                  allowDecimal: true,
                  formatFixed2OnClose: true,
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final raw = amountCtrl.text.trim();
                  final value = double.tryParse(raw);
                  if (value == null) {
                    ErrorHandler.showWarning(ctx, '请输入合法余额');
                    return;
                  }
                  Navigator.of(ctx).pop(value);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );

      if (nextBalance == null) return;
      final newInitialBalance =
          account.initialBalance + (nextBalance - account.currentBalance);
      await context.read<AccountProvider>().adjustInitialBalance(
            account.id,
            newInitialBalance,
            bookId: bookId,
          );
      if (!mounted) return;
      ErrorHandler.showSuccess(context, '余额已更新');
    } finally {
      amountCtrl.dispose();
    }
  }

  Widget _buildHeaderCard(BuildContext context, Account account) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandLogoAvatar(
                size: 40,
                brandKey: account.brandKey,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: cs.primary,
                backgroundColor: cs.primary.withOpacity(0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: cs.surfaceContainerHighest,
                  foregroundColor: cs.onSurface,
                ),
                onPressed: () => _openActionsSheet(account),
                child: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '当前余额(元)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            account.currentBalance.toStringAsFixed(2),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    final tagProvider = context.watch<TagProvider>();

    if (!accountProvider.loaded ||
        !recordProvider.loaded ||
        !categoryProvider.loaded ||
        !bookProvider.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final account = accountProvider.byId(widget.accountId);
    final bookId = bookProvider.activeBookId;
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: const Center(child: Text('账户不存在')),
      );
    }

    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    final recordChangeCounter = recordProvider.changeCounter;
    final nextKey =
        '$bookId:${widget.accountId}:$_selectedYear:$recordChangeCounter';
    if (_recordsKey != nextKey || _recordsFuture == null) {
      _recordsKey = nextKey;
      _recordsFuture = recordProvider
          .recordsForPeriodAllAsync(bookId, start: yearStart, end: yearEnd)
          .then((records) {
        final filtered =
            records.where((r) => r.accountId == widget.accountId).toList();
        filtered.sort((a, b) => b.date.compareTo(a.date));
        return filtered;
      });
      _tagsKey = null;
      _tagsFuture = null;
    }

    return FutureBuilder<List<Record>>(
      future: _recordsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('资产详情')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('资产详情')),
            body: Center(child: Text('加载失败: ${snap.error}')),
          );
        }

        final records = snap.data ?? const <Record>[];
        final recordIds = records.map((r) => r.id).toList(growable: false);

        final nextTagsKey = '${_recordsKey ?? nextKey}:tags';
        if (_tagsKey != nextTagsKey || _tagsFuture == null) {
          _tagsKey = nextTagsKey;
          _tagsFuture = recordIds.isEmpty
              ? Future.value(const <String, List<Tag>>{})
              : tagProvider.loadTagsForRecords(recordIds);
        }

        return FutureBuilder<Map<String, List<Tag>>>(
          future: _tagsFuture,
          builder: (context, tagSnap) {
            final tagsByRecordId = tagSnap.data ?? const <String, List<Tag>>{};
            final categoryMap = {for (final c in categoryProvider.categories) c.key: c};

            return Scaffold(
              appBar: AppBar(
                title: const Text('资产详情'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildHeaderCard(context, account),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openYearSelector,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_selectedYear年',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '暂无流水记录',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                      ),
                    )
                  else
                    ..._buildMonthSections(context, records, categoryMap, tagsByRecordId),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMonthSections(
    BuildContext context,
    List<Record> records,
    Map<String, Category> categoryMap,
    Map<String, List<Tag>> tagsByRecordId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final byMonth = <int, List<Record>>{};
    for (final r in records) {
      byMonth.putIfAbsent(r.date.month, () => <Record>[]).add(r);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final month in months) {
      final monthRecords = byMonth[month]!..sort((a, b) => b.date.compareTo(a.date));
      final monthIncome = monthRecords
          .where((r) => r.isIncome)
          .fold<double>(0, (sum, r) => sum + r.amount);
      final monthExpense = monthRecords
          .where((r) => r.isExpense)
          .fold<double>(0, (sum, r) => sum + r.amount);
      final expanded = _expandedMonths.contains(month);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _toggleMonth(month),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        color: cs.outline,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$month月',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '支出 ¥${monthExpense.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '收入 ¥${monthIncome.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                Divider(height: 1, color: cs.outlineVariant.withOpacity(0.35)),
                ..._buildDayGroups(context, monthRecords, categoryMap, tagsByRecordId),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildDayGroups(
    BuildContext context,
    List<Record> monthRecords,
    Map<String, Category> categoryMap,
    Map<String, List<Tag>> tagsByRecordId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final groups = _groupRecordsByDate(monthRecords);
    final widgets = <Widget>[];

    for (final group in groups) {
      final dayIncome =
          group.records.where((r) => r.isIncome).fold<double>(0, (s, r) => s + r.amount);
      final dayExpense =
          group.records.where((r) => r.isExpense).fold<double>(0, (s, r) => s + r.amount);
      final net = dayIncome - dayExpense;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text(
                '${group.date.month}月${group.date.day}日 ${_dayBadge(group.date)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '收支:${net.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.55),
                    ),
              ),
            ],
          ),
        ),
      );

      widgets.add(
        Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          elevation: 0,
          color: cs.surface,
          child: Column(
            children: [
              for (var i = 0; i < group.records.length; i++)
                _buildRecordTile(
                  context,
                  group.records[i],
                  categoryMap,
                  tagsByRecordId[group.records[i].id] ?? const <Tag>[],
                  i < group.records.length - 1,
                ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildRecordTile(
    BuildContext context,
    Record record,
    Map<String, Category> categoryMap,
    List<Tag> tags,
    bool showDivider,
  ) {
    final category = categoryMap[record.categoryKey];
    final internalUi = AccountRecordsPage._internalCategoryUi[record.categoryKey];
    final isIncome = record.isIncome;
    final amountColor = isIncome ? AppColors.success : AppColors.danger;
    final title = category?.name ?? internalUi?.name ?? record.categoryKey;
    final icon = category?.icon ?? internalUi?.icon ?? Icons.category_outlined;
    final sharedBook = int.tryParse(record.bookId) != null;
    final createdBy = record.createdByUserId;
    final updatedBy = record.updatedByUserId;
    final createdName = _memberName(createdBy);
    final updatedName = _memberName(updatedBy);
    final showAttribution = sharedBook && (createdName.isNotEmpty || updatedName.isNotEmpty);
    final attribution = (() {
      if (!showAttribution) return '';
      if (createdName.isNotEmpty && updatedName.isNotEmpty && createdBy != updatedBy) {
        return '记录:$createdName · 修改:$updatedName';
      }
      if (createdName.isNotEmpty) return '记录:$createdName';
      if (updatedName.isNotEmpty) return '修改:$updatedName';
      return '';
    })();

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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
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
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (record.remark.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.remark,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (attribution.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          attribution,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.9),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: -8,
                          children: [
                            for (final tag in tags.take(3)) _buildTagChip(context, tag),
                            if (tags.length > 3) _buildMoreChip(context, tags.length - 3),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isIncome ? '+' : '-'}${record.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, Tag tag) {
    final cs = Theme.of(context).colorScheme;
    final bg = tag.colorValue == null
        ? cs.surfaceContainerHighest.withOpacity(0.35)
        : Color(tag.colorValue!).withOpacity(0.14);
    final fg = tag.colorValue == null ? cs.onSurface : Color(tag.colorValue!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
      ),
      child: Text(
        tag.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildMoreChip(BuildContext context, int moreCount) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
      ),
      child: Text(
        '+$moreCount',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  List<_RecordGroup> _groupRecordsByDate(List<Record> records) {
    final groups = <DateTime, List<Record>>{};
    for (final record in records) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      groups.putIfAbsent(day, () => <Record>[]).add(record);
    }
    return groups.entries
        .map((e) => _RecordGroup(date: e.key, records: e.value..sort((a, b) => b.date.compareTo(a.date))))
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
