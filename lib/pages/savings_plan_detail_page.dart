import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/record.dart';
import '../models/savings_plan.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../repository/savings_plan_repository.dart';
import '../services/sync_engine.dart';
import '../utils/error_handler.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../widgets/week_strip.dart';

class SavingsPlanDetailPage extends StatefulWidget {
  const SavingsPlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  State<SavingsPlanDetailPage> createState() => _SavingsPlanDetailPageState();
}

class _SavingsPlanDetailPageState extends State<SavingsPlanDetailPage> {
  final _repo = SavingsPlanRepository();
  SavingsPlan? _plan;
  bool _loading = true;
  List<Record> _records = const [];
  DateTime _selectedDay = DateTime.now();
  bool _ensuringMeta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final bookId = context.read<BookProvider>().activeBookId;
    setState(() => _loading = true);
    try {
      final ok = await _ensureMetaReadyForBook(bookId);
      if (!ok || !mounted) {
        setState(() => _loading = false);
        return;
      }
      final plans = await _repo.loadPlans(bookId: bookId);
      final plan = plans.firstWhere((p) => p.id == widget.planId);
      final recordProvider = context.read<RecordProvider>();
      // 仅用于展示：按 planId 前缀筛选本计划的转账记录（避免多个计划共享同一存钱账户时混杂）
      final all = recordProvider.records;
      final prefix = 'sp_${plan.id}_';
      final list = all
          .where((r) => (r.pairId ?? '').startsWith(prefix))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _records = list.take(50).toList(growable: false);
        _selectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<bool> _ensureMetaReadyForBook(String bookId) async {
    if (_ensuringMeta) return false;
    if (int.tryParse(bookId) == null) return true;

    final accountProvider = context.read<AccountProvider>();
    if (accountProvider.accounts.where((a) => a.bookId == bookId).isNotEmpty) {
      return true;
    }

    _ensuringMeta = true;
    try {
      final ok = await SyncEngine().ensureMetaReady(
        context,
        bookId,
        requireCategories: false,
        requireAccounts: true,
        requireTags: false,
        reason: 'meta_ensure',
      );
      if (!ok && mounted) {
        ErrorHandler.showError(context, 'åŒæ­¥å¤±è´¥ï¼Œè¯·ç¨åŽé‡è¯•');
      }
      return ok;
    } finally {
      _ensuringMeta = false;
    }
  }

  Account? _accountOf(String id, List<Account> accounts) {
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  String _typeLabel(SavingsPlanType t) {
    switch (t) {
      case SavingsPlanType.flexible:
        return '灵活存钱';
      case SavingsPlanType.countdown:
        return '倒数日';
      case SavingsPlanType.monthlyFixed:
        return '每月定额';
      case SavingsPlanType.weeklyFixed:
        return '每周定额';
    }
  }

  double _suggestAmount(SavingsPlan p, double saved) {
    final double remaining =
        max(0.0, p.targetAmount - saved).toDouble();
    final today = DateTime.now();
    switch (p.type) {
      case SavingsPlanType.flexible:
        return min(remaining, 100.0).toDouble();
      case SavingsPlanType.countdown:
        final end = p.endDate ?? today;
        final daysLeft = max(1, end.difference(DateTime(today.year, today.month, today.day)).inDays + 1);
        final per = remaining <= 0 ? 0 : remaining / daysLeft;
        return double.parse(per.toStringAsFixed(2));
      case SavingsPlanType.monthlyFixed:
        return p.monthlyAmount ?? 0;
      case SavingsPlanType.weeklyFixed:
        return p.weeklyAmount ?? 0;
    }
  }

  Future<String?> _pickFromAccountId({String? initial}) async {
    final accounts = context.read<AccountProvider>().accounts;
    final selectable = accounts
        .where((a) => a.includeInOverview)
        .toList(growable: false);
    final result = await showAccountSelectBottomSheet(
      context,
      selectable,
      selectedAccountId: initial,
      title: '选择扣款账户',
    );
    return result ?? initial;
  }

  Future<void> _deposit() async {
    final plan = _plan;
    if (plan == null) return;
    final cs = Theme.of(context).colorScheme;

    final bookId = context.read<BookProvider>().activeBookId;
    final accounts = context.read<AccountProvider>().accounts;
    final planAcc = _accountOf(plan.accountId, accounts);
    if (planAcc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('存钱账户不存在')));
      return;
    }
    final saved = plan.savedAmount;
    final suggested = _suggestAmount(plan, saved);

    final amountCtrl = TextEditingController(
      text: suggested > 0 ? suggested.toStringAsFixed(2) : '',
    );
    final remarkCtrl = TextEditingController();
    var fromAccountId = plan.defaultFromAccountId;

    Future<void> confirm() async {
      final raw = amountCtrl.text.trim();
      final amount = double.tryParse(raw) ?? 0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入金额')));
        return;
      }
      if (fromAccountId == null || fromAccountId!.isEmpty) {
        fromAccountId = await _pickFromAccountId(initial: fromAccountId);
      }
      if (fromAccountId == null || fromAccountId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择扣款账户')));
        return;
      }

      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();

      try {
        final pairId = 'sp_${plan.id}_${DateTime.now().microsecondsSinceEpoch}';
        final now = DateTime.now();
        final note = remarkCtrl.text.trim();
        final text = note.isEmpty ? '存钱' : note;

        // 转出：扣款账户
        await recordProvider.addRecord(
          amount: amount,
          remark: text,
          date: now,
          categoryKey: 'saving-out',
          bookId: bookId,
          accountId: fromAccountId!,
          direction: TransactionDirection.out,
          includeInStats: false,
          pairId: pairId,
          accountProvider: accountProvider,
        );
        // 转入：计划账户
        await recordProvider.addRecord(
          amount: amount,
          remark: text,
          date: now,
          categoryKey: 'saving-in',
          bookId: bookId,
          accountId: plan.accountId,
          direction: TransactionDirection.income,
          includeInStats: false,
          pairId: pairId,
          accountProvider: accountProvider,
        );

        final updated = plan.copyWith(
          savedAmount: plan.savedAmount + amount,
          executedCount: plan.executedCount + 1,
          lastExecutedAt: now,
          defaultFromAccountId: fromAccountId,
          updatedAt: now,
        );
        await _repo.upsertPlan(updated);

        if (!mounted) return;
        Navigator.of(context).pop();
        await _reload();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e'), backgroundColor: cs.error),
        );
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            return Padding(
              padding:
                  EdgeInsets.only(left: 16, right: 16, bottom: max(16, bottom)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text('存一笔', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_yen_rounded),
                      labelText: '金额',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: remarkCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.notes_rounded),
                      labelText: '备注（可选）',
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.30),
                        border: Border.all(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('存入账户')),
                          Text(
                            planAcc.name,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      fromAccountId =
                          await _pickFromAccountId(initial: fromAccountId);
                      sheetSetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.55),
                        border: Border.all(
                          color: Theme.of(ctx)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fromAccountId == null
                                  ? '选择扣款账户'
                                  : (_accountOf(fromAccountId!, accounts)
                                          ?.name ??
                                      '选择扣款账户'),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: confirm,
                      child: const Text('保存'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = context.watch<AccountProvider>().accounts;

    final plan = _plan;
    final planAcc = plan == null ? null : _accountOf(plan.accountId, accounts);
    final saved = plan?.savedAmount ?? 0;
    final target = plan?.targetAmount ?? 0;
    final pct = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);

    final selectedMonthRecords = _records
        .where((r) => r.date.year == _selectedDay.year && r.date.month == _selectedDay.month)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.name ?? '存钱计划'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null
              ? const Center(child: Text('计划不存在'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.savings_outlined, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_typeLabel(plan.type)} · 不计入统计',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurface.withOpacity(0.65),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '¥ ${target.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '存钱进度',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: cs.primary,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '${(pct * 100).toStringAsFixed(2)}%',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.primary.withOpacity(0.85),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text('已存：${saved.toStringAsFixed(2)}'),
                              ),
                              Expanded(
                                child: Text(
                                  '剩余：${max(0, target - saved).toStringAsFixed(2)}',
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 10,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                '已执行 ${plan.executedCount} 次',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withOpacity(0.65),
                                    ),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _deposit,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('存一笔'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_selectedDay.year}年${_selectedDay.month}月',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '上个月',
                          onPressed: () {
                            final prev = DateTime(_selectedDay.year, _selectedDay.month - 1, 1);
                            setState(() => _selectedDay = prev);
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          tooltip: '下个月',
                          onPressed: () {
                            final next = DateTime(_selectedDay.year, _selectedDay.month + 1, 1);
                            setState(() => _selectedDay = next);
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    WeekStrip(
                      selectedDay: _selectedDay,
                      onSelected: (d) => setState(() => _selectedDay = d),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '记录',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (selectedMonthRecords.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                        ),
                        child: Text(
                          '还没有存钱记录',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                        ),
                      )
                    else
                      ...selectedMonthRecords.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.attach_money_rounded, color: cs.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.remark,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: cs.onSurface.withOpacity(0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '+${r.amount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
