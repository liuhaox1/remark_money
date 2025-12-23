import 'dart:math';

import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../theme/app_tokens.dart';
import '../models/account.dart';
import '../models/savings_plan.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../repository/savings_plan_repository.dart';
import 'savings_plan_create_page.dart';
import 'savings_plan_detail_page.dart';

class SavingsPlansPage extends StatefulWidget {
  const SavingsPlansPage({super.key});

  @override
  State<SavingsPlansPage> createState() => _SavingsPlansPageState();
}

class _SavingsPlansPageState extends State<SavingsPlansPage>
    with SingleTickerProviderStateMixin {
  final _repo = SavingsPlanRepository();
  bool _loading = true;
  List<SavingsPlan> _plans = const [];
  late final TabController _tabController;
  SavingsPlanType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final bookId = context.read<BookProvider>().activeBookId;
    setState(() => _loading = true);
    try {
      final list = await _repo.loadPlans(bookId: bookId);
      if (!mounted) return;
      setState(() {
        _plans = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<SavingsPlan> _visiblePlans(bool archived) {
    final accounts = context.read<AccountProvider>().accounts;
    bool isArchived(SavingsPlan p) {
      final saved = _savedAmount(p, accounts);
      final now = DateTime.now();
      final reached = p.targetAmount > 0 && saved >= p.targetAmount;
      if (reached) return true;
      if (p.type == SavingsPlanType.countdown && p.endDate != null) {
        final end = DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day);
        final today = DateTime(now.year, now.month, now.day);
        return today.isAfter(end);
      }
      return false;
    }

    var list = _plans.where((p) => isArchived(p) == archived).toList();
    if (_typeFilter != null) {
      list = list.where((p) => p.type == _typeFilter).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Account? _accountOf(String id, List<Account> accounts) {
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  double _savedAmount(SavingsPlan p, List<Account> accounts) {
    return p.savedAmount;
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

  Future<void> _createPlan() async {
    final created = await Navigator.of(context).push<SavingsPlan>(
      MaterialPageRoute(
        builder: (_) => SavingsPlanCreatePage(
          initialType: _typeFilter ?? SavingsPlanType.flexible,
        ),
      ),
    );
    if (created == null) return;
    await _reload();
    if (!mounted) return;
    await _openDetail(created);
  }

  Future<void> _openDetail(SavingsPlan plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SavingsPlanDetailPage(planId: plan.id),
      ),
    );
    await _reload();
  }

  Future<bool> _confirmDeletePlan(
    SavingsPlan plan, {
    required double balance,
  }) async {
    if (balance != 0) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先把余额转出为 0 再删除')),
      );
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('删除存钱目标？'),
          content: Text('“${plan.name}”将被删除，无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _deletePlan(SavingsPlan plan) async {
    await _repo.deletePlan(plan.id);
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 72, color: cs.onSurface.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text(
              '还没有存钱计划',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.8),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '添加一个计划，把存钱变成可坚持的过程。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.55),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加存钱计划'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = context.watch<AccountProvider>().accounts;

    final tabArchived = _tabController.index == 1;
    final list = _visiblePlans(tabArchived);

    final totalTarget = list.fold<double>(0, (s, p) => s + p.targetAmount);
    final totalSaved =
        list.fold<double>(0, (s, p) => s + _savedAmount(p, accounts));
    final hasProgress = list.isNotEmpty && totalTarget > 0;
    final progress =
        hasProgress ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
    final percentText =
        hasProgress ? '${(progress * 100).toStringAsFixed(2)}%' : '—';
    final savedText = hasProgress ? totalSaved.toStringAsFixed(2) : '—';
    final remainingText = hasProgress
        ? max(0, totalTarget - totalSaved).toStringAsFixed(2)
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('存钱计划'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: '进行中'),
            Tab(text: '归档'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ScrollConfiguration(
              behavior: const _DesktopDragScrollBehavior(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.25),
                        ),
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
                                percentText,
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
                                child: Text(
                                  '已存：$savedText',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: cs.onSurface.withOpacity(
                                          hasProgress ? 0.9 : 0.55,
                                        ),
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '剩余：$remainingText',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: cs.onSurface.withOpacity(
                                          hasProgress ? 0.9 : 0.55,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (!hasProgress) ...[
                            const SizedBox(height: 6),
                            Text(
                              '添加存钱计划后自动显示进度',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.55),
                                  ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: hasProgress
                                  ? cs.primary
                                  : cs.onSurface.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ScrollConfiguration(
                    behavior: const _DesktopDragScrollBehavior(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: _typeFilter == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _typeFilter = null),
                      ),
                          const SizedBox(width: 8),
                          for (final t in SavingsPlanType.values) ...[
                            ChoiceChip(
                              label: Text(_typeLabel(t)),
                              selected: _typeFilter == t,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _typeFilter = t),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: list.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = list[i];
                            final saved = _savedAmount(p, accounts);
                            final pct = p.targetAmount <= 0
                                ? 0.0
                                : (saved / p.targetAmount).clamp(0.0, 1.0);
                            return Slidable(
                              key: ValueKey(p.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.22,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final ok =
                                          await _confirmDeletePlan(p, balance: saved);
                                      if (!ok) return;
                                      await _deletePlan(p);
                                      await _reload();
                                    },
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: cs.onError,
                                    label: '删除',
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openDetail(p),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(0.25),
                                    ),
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
                                        child: Icon(Icons.savings_outlined,
                                            color: cs.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    p.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: cs.primary.withOpacity(0.10),
                                                    borderRadius: BorderRadius.circular(99),
                                                  ),
                                                  child: Text(
                                                    _typeLabel(p.type),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(color: cs.primary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(99),
                                              child: LinearProgressIndicator(
                                                value: pct,
                                                minHeight: 8,
                                                backgroundColor: cs.surfaceContainerHighest,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Text(
                                                  '已存入：${saved.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: cs.onSurface
                                                            .withOpacity(0.72),
                                                      ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '目标：${p.targetAmount.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: cs.onSurface
                                                            .withOpacity(0.72),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                ],
              ),
            ),
    );
  }
}

class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}
