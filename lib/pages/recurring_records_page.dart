import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/recurring_record.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_record_provider.dart';
import '../utils/error_handler.dart';
import 'recurring_record_form_page.dart';

class RecurringRecordsPage extends StatefulWidget {
  const RecurringRecordsPage({super.key});

  @override
  State<RecurringRecordsPage> createState() => _RecurringRecordsPageState();
}

class _RecurringRecordsPageState extends State<RecurringRecordsPage> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    final provider = context.read<RecurringRecordProvider>();
    if (provider.loaded) return;
    setState(() => _loading = true);
    try {
      await provider.load();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecurringRecordFormPage()),
    );
  }

  Future<void> _openEdit(RecurringRecordPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringRecordFormPage(plan: plan)),
    );
  }

  Future<void> _confirmDelete(RecurringRecordPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除定时记账？'),
        content: const Text('删除后将不再自动生成该计划的记账记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<RecurringRecordProvider>().remove(plan.id);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '删除失败：$e');
    }
  }

  Category? _findCategory(List<Category> categories, String key) {
    try {
      return categories.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }

  String _repeatLabel(RecurringRecordPlan plan) {
    if (plan.periodType == RecurringPeriodType.weekly) {
      final w = plan.weekday ?? plan.startDate.weekday;
      return '每周 ${_weekdayLabel(w)}';
    }
    final d = plan.monthDay ?? plan.startDate.day;
    return '每月 ${d}号';
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
        return '周日';
      default:
        return '周$weekday';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBookId = context.watch<BookProvider>().activeBookId;
    final categories = context.watch<CategoryProvider>().categories;
    final plansAll = context.watch<RecurringRecordProvider>().plans;
    final plans = plansAll.where((p) => p.bookId == activeBookId).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (plans.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 44,
                      color: cs.onSurface.withOpacity(0.35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无定时记账',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加定时记账'),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final cat = _findCategory(categories, plan.categoryKey);
                final title = cat?.name ?? '未分类';
                final icon = cat?.icon ?? Icons.category_rounded;
                final amountText = plan.amount.toStringAsFixed(2);
                final isExpense = plan.direction == TransactionDirection.out;
                final amountColor = isExpense ? cs.error : cs.primary;

                return Slidable(
                  key: ValueKey(plan.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.46,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _openEdit(plan),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        icon: Icons.edit_rounded,
                        label: '编辑',
                      ),
                      SlidableAction(
                        onPressed: (_) => _confirmDelete(plan),
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        icon: Icons.delete_rounded,
                        label: '删除',
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: cs.onSurface.withOpacity(0.78)),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_repeatLabel(plan)} · 下次 ${_ymd(plan.nextDate)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.62),
                              ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isExpense ? '-' : '+'}$amountText',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: amountColor,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Switch(
                            value: plan.enabled,
                            onChanged: (v) => context
                                .read<RecurringRecordProvider>()
                                .toggleEnabled(plan, v),
                          ),
                        ],
                      ),
                      onTap: () => _openEdit(plan),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加定时记账'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('定时记账'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: const Color(0x00000000),
      ),
      body: body,
    );
  }

  static String _ymd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
