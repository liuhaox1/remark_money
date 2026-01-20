import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/savings_plan.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../repository/savings_plan_repository.dart';
import '../services/sync_engine.dart';
import '../utils/error_handler.dart';
import '../widgets/account_select_bottom_sheet.dart';

class SavingsPlanCreatePage extends StatefulWidget {
  const SavingsPlanCreatePage({
    super.key,
    this.initialType = SavingsPlanType.flexible,
    this.initialPlan,
  });

  final SavingsPlanType initialType;
  final SavingsPlan? initialPlan;

  @override
  State<SavingsPlanCreatePage> createState() => _SavingsPlanCreatePageState();
}

class _SavingsPlanCreatePageState extends State<SavingsPlanCreatePage> {
  final _repo = SavingsPlanRepository();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String? _depositAccountId;

  late SavingsPlanType _type;
  DateTime? _endDate;
  int _monthlyDay = 1;
  final _monthlyAmountCtrl = TextEditingController();
  int _weeklyWeekday = DateTime.now().weekday;
  final _weeklyAmountCtrl = TextEditingController();

  bool _saving = false;
  bool _ensuringMeta = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _monthlyAmountCtrl.dispose();
    _weeklyAmountCtrl.dispose();
    super.dispose();
  }

  double _parseAmount(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlan;
    if (initial != null) {
      _type = initial.type;
      _nameCtrl.text = initial.name;
      _targetCtrl.text =
          initial.targetAmount > 0 ? initial.targetAmount.toStringAsFixed(2) : '';
      _depositAccountId = initial.accountId;
      _endDate = initial.endDate;
      _monthlyDay = initial.monthlyDay ?? _monthlyDay;
      _monthlyAmountCtrl.text = (initial.monthlyAmount ?? 0) > 0
          ? initial.monthlyAmount!.toStringAsFixed(2)
          : '';
      _weeklyWeekday = initial.weeklyWeekday ?? _weeklyWeekday;
      _weeklyAmountCtrl.text = (initial.weeklyAmount ?? 0) > 0
          ? initial.weeklyAmount!.toStringAsFixed(2)
          : '';
    } else {
      _type = widget.initialType;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bookId = context.read<BookProvider>().activeBookId;
      final ok = await _ensureMetaReadyForBook(bookId);
      if (!ok || !mounted) return;
      final accounts = context.read<AccountProvider>().accounts;
      String? firstId;
      for (final a in accounts) {
        if (a.kind == AccountKind.asset && a.includeInOverview) {
          firstId = a.id;
          break;
        }
      }
      firstId ??= accounts.isEmpty ? null : accounts.first.id;
      if ((_depositAccountId == null || _depositAccountId!.isEmpty) &&
          firstId != null &&
          firstId.isNotEmpty) {
        setState(() => _depositAccountId = firstId);
      }
    });
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

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? now.add(const Duration(days: 30));
    final picked = await _pickDateSheet(initial);
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<DateTime?> _pickDateSheet(DateTime initial) async {
    final today = DateTime.now();
    final startYear = today.year - 20;
    final endYear = today.year + 5;

    int tempYear = initial.year.clamp(startYear, endYear);
    int tempMonth = initial.month;
    int tempDay = initial.day;

    final years =
        List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
    final months = List<int>.generate(12, (i) => i + 1);
    final days = List<int>.generate(31, (i) => i + 1);

    final yearController = FixedExtentScrollController(
      initialItem: years.indexOf(tempYear).clamp(0, years.length - 1),
    );
    final monthController = FixedExtentScrollController(
      initialItem: tempMonth - 1,
    );
    final dayController = FixedExtentScrollController(
      initialItem: tempDay - 1,
    );

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '选择日期',
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final lastDayOfMonth =
                            DateTime(tempYear, tempMonth + 1, 0).day;
                        if (tempDay > lastDayOfMonth) tempDay = lastDayOfMonth;
                        Navigator.pop(ctx, DateTime(tempYear, tempMonth, tempDay));
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: yearController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempYear = years[index];
                        },
                        children: years
                            .map((y) => Center(child: Text('$y年')))
                            .toList(growable: false),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: monthController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempMonth = months[index];
                        },
                        children: months
                            .map((m) => Center(child: Text('${m}月')))
                            .toList(growable: false),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: dayController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempDay = days[index];
                        },
                        children: days
                            .map((d) => Center(child: Text('${d}日')))
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _typeLabel(SavingsPlanType t) {
    switch (t) {
      case SavingsPlanType.flexible:
        return '灵活存钱';
      case SavingsPlanType.countdown:
        return '倒数日存钱';
      case SavingsPlanType.monthlyFixed:
        return '每月定额';
      case SavingsPlanType.weeklyFixed:
        return '每周定额';
    }
  }

  Future<void> _submit() async {
    final cs = Theme.of(context).colorScheme;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入计划名称')),
      );
      return;
    }

    if (_depositAccountId == null || _depositAccountId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择存钱账户')),
      );
      return;
    }

    final double targetAmount =
        max(0.0, _parseAmount(_targetCtrl.text)).toDouble();
    if ((_type == SavingsPlanType.countdown || _type == SavingsPlanType.monthlyFixed) &&
        targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入目标金额')),
      );
      return;
    }

    if (_type == SavingsPlanType.countdown && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择结束日期')),
      );
      return;
    }

    final double? monthlyAmount = _type == SavingsPlanType.monthlyFixed
        ? max(0.0, _parseAmount(_monthlyAmountCtrl.text)).toDouble()
        : null;
    if (_type == SavingsPlanType.monthlyFixed && (monthlyAmount ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入每月定额')),
      );
      return;
    }

    final double? weeklyAmount = _type == SavingsPlanType.weeklyFixed
        ? max(0.0, _parseAmount(_weeklyAmountCtrl.text)).toDouble()
        : null;
    if (_type == SavingsPlanType.weeklyFixed && (weeklyAmount ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入每周定额')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final bookId = context.read<BookProvider>().activeBookId;
      final now = DateTime.now();
      final accountId = _depositAccountId!;

      final initial = widget.initialPlan;
      final plan = (initial == null)
          ? SavingsPlan(
              id: 'sp_${now.microsecondsSinceEpoch}',
              bookId: bookId,
              accountId: accountId,
              name: name,
              type: _type,
              targetAmount: targetAmount,
              includeInStats: false,
              createdAt: now,
              updatedAt: now,
              startDate: now,
              endDate: _endDate,
              monthlyDay: _type == SavingsPlanType.monthlyFixed ? _monthlyDay : null,
              monthlyAmount: monthlyAmount,
              weeklyWeekday: _type == SavingsPlanType.weeklyFixed ? _weeklyWeekday : null,
              weeklyAmount: weeklyAmount,
            )
          : initial.copyWith(
              bookId: bookId,
              accountId: accountId,
              name: name,
              type: _type,
              targetAmount: targetAmount,
              endDate: _endDate,
              monthlyDay: _type == SavingsPlanType.monthlyFixed ? _monthlyDay : null,
              monthlyAmount: monthlyAmount,
              weeklyWeekday: _type == SavingsPlanType.weeklyFixed ? _weeklyWeekday : null,
              weeklyAmount: weeklyAmount,
              updatedAt: now,
            );

      await _repo.upsertPlan(plan);
      if (!mounted) return;
      Navigator.of(context).pop(plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('创建失败：$e'),
          backgroundColor: cs.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSection({required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = context.watch<AccountProvider>().accounts;
    String? depositAccountName;
    if (_depositAccountId != null) {
      for (final a in accounts) {
        if (a.id == _depositAccountId) {
          depositAccountName = a.name;
          break;
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialPlan == null ? '添加存钱计划' : '编辑存钱计划'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildSection(
            title: '计划类型',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in SavingsPlanType.values)
                  ChoiceChip(
                    label: Text(_typeLabel(t)),
                    selected: _type == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: '基本信息',
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '例如：买电脑、旅行基金',
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final selectable = accounts
                        .where((a) => a.kind == AccountKind.asset && a.includeInOverview)
                        .toList(growable: false);
                    final picked = await showAccountSelectBottomSheet(
                      context,
                      selectable,
                      selectedAccountId: _depositAccountId,
                      title: '选择存钱账户',
                    );
                    if (picked != null) setState(() => _depositAccountId = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cs.surfaceContainerHighest.withOpacity(0.55),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('存钱账户'),
                        const Spacer(),
                        Text(depositAccountName ?? '请选择'),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: cs.onSurface.withOpacity(0.55)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '目标金额',
                    hintText: '请输入目标金额',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_type == SavingsPlanType.countdown) ...[
            _buildSection(
              title: '倒数日设置',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickEndDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate == null
                              ? '选择结束日期'
                              : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.55)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_type == SavingsPlanType.monthlyFixed) ...[
            _buildSection(
              title: '每月定额',
              child: Column(
                children: [
                  TextField(
                    controller: _monthlyAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '每月存入金额',
                      hintText: '例如：500',
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        showDragHandle: true,
                        backgroundColor: cs.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: 28,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final day = i + 1;
                                final selected = day == _monthlyDay;
                                return ListTile(
                                  title: Text('每月$day号'),
                                  trailing: selected
                                      ? Icon(Icons.check_rounded, color: cs.primary)
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(day),
                                );
                              },
                            ),
                          );
                        },
                      );
                      if (selected != null) setState(() => _monthlyDay = selected);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: cs.surfaceContainerHighest.withOpacity(0.55),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Text('每月几号'),
                          const Spacer(),
                          Text('$_monthlyDay号'),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              color: cs.onSurface.withOpacity(0.55)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_type == SavingsPlanType.weeklyFixed) ...[
            _buildSection(
              title: '每周定额',
              child: Column(
                children: [
                  TextField(
                    controller: _weeklyAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '每周存入金额',
                      hintText: '例如：200',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final weekday = i + 1;
                      const labels = ['一', '二', '三', '四', '五', '六', '日'];
                      return ChoiceChip(
                        label: Text('周${labels[i]}'),
                        selected: _weeklyWeekday == weekday,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _weeklyWeekday = weekday),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 灵活存钱：不额外配置，直接手动存入即可
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
    );
  }
}
