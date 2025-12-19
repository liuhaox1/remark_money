import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/recurring_record.dart';
import '../models/record.dart';
import '../models/tag.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_record_provider.dart';
import '../providers/tag_provider.dart';
import '../utils/error_handler.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../widgets/number_pad_sheet.dart';
import '../widgets/tag_picker_bottom_sheet.dart';
import '../widgets/ymd_date_picker_sheet.dart';

class RecurringRecordFormPage extends StatefulWidget {
  const RecurringRecordFormPage({super.key, this.plan});

  final RecurringRecordPlan? plan;

  @override
  State<RecurringRecordFormPage> createState() => _RecurringRecordFormPageState();
}

class _RecurringRecordFormPageState extends State<RecurringRecordFormPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  bool _didInit = false;
  bool _isSaving = false;
  bool _isExpense = true;
  RecurringPeriodType _periodType = RecurringPeriodType.monthly;
  DateTime? _startDate;
  int? _weekday; // 1-7 (Mon..Sun)
  int? _monthDay; // 1-31
  String? _selectedCategoryKey;
  String? _selectedAccountId;
  List<String> _selectedTagIds = <String>[];

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final bookId = context.read<BookProvider>().activeBookId;
    context.read<TagProvider>().loadForBook(bookId);

    final plan = widget.plan;
    if (plan != null) {
      _isExpense = plan.direction == TransactionDirection.out;
      _periodType = plan.periodType;
      _startDate = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
      _weekday = plan.weekday;
      _monthDay = plan.monthDay;
      _selectedCategoryKey = plan.categoryKey;
      _selectedAccountId = plan.accountId;
      _selectedTagIds = List<String>.from(plan.tagIds);
      _amountCtrl.text = plan.amount == 0 ? '' : plan.amount.toStringAsFixed(2);
      _remarkCtrl.text = plan.remark;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accountProvider = context.read<AccountProvider>();
      final wallet = await accountProvider.ensureDefaultWallet(bookId: bookId);
      if (!mounted) return;
      setState(() => _selectedAccountId = wallet.id);
    });
  }

  Future<void> _openCategoryPicker() async {
    final categories = context.read<CategoryProvider>().categories;
    final filtered = categories.where((c) => c.isExpense == _isExpense).toList();
    if (filtered.isEmpty) {
      ErrorHandler.showWarning(context, '当前没有可用分类');
      return;
    }

    final hasHierarchy = filtered.any((c) => c.parentKey != null);
    final topLevel = hasHierarchy
        ? filtered.where((c) => c.parentKey == null).toList()
        : filtered;
    final childrenByParent = <String, List<Category>>{};
    if (hasHierarchy) {
      for (final c in filtered.where((c) => c.parentKey != null)) {
        final parent = c.parentKey!;
        (childrenByParent[parent] ??= <Category>[]).add(c);
      }
    }

    String? activeParentKey;
    String? selectedKey = _selectedCategoryKey;
    if (hasHierarchy && selectedKey != null) {
      try {
        final selected = filtered.firstWhere((c) => c.key == selectedKey);
        activeParentKey = selected.parentKey ?? selected.key;
      } catch (_) {}
    }
    activeParentKey ??= topLevel.isEmpty ? null : topLevel.first.key;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;

        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final activeChildren = (!hasHierarchy || activeParentKey == null)
                  ? topLevel
                  : (childrenByParent[activeParentKey] ??
                      <Category>[]);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '选择分类',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final cat in topLevel)
                                  _CategoryTile(
                                    category: cat,
                                    selected: cat.key == selectedKey,
                                    active:
                                        hasHierarchy && cat.key == activeParentKey,
                                    onTap: () {
                                      if (!hasHierarchy) {
                                        setState(() => _selectedCategoryKey = cat.key);
                                        Navigator.pop(ctx);
                                        return;
                                      }
                                      setSheetState(() {
                                        activeParentKey = cat.key;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            if (hasHierarchy) ...[
                              const SizedBox(height: 14),
                              Divider(
                                height: 1,
                                color: cs.outlineVariant.withOpacity(0.35),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final cat in activeChildren)
                                    _CategoryTile(
                                      category: cat,
                                      selected: cat.key == selectedKey,
                                      onTap: () {
                                        setState(() => _selectedCategoryKey = cat.key);
                                        setSheetState(() => selectedKey = cat.key);
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openAccountPicker() async {
    final accountProvider = context.read<AccountProvider>();
    final bookId = context.read<BookProvider>().activeBookId;
    final accounts = accountProvider.accounts;
    if (accounts.isEmpty) {
      final wallet = await accountProvider.ensureDefaultWallet(bookId: bookId);
      if (!mounted) return;
      setState(() => _selectedAccountId = wallet.id);
      return;
    }

    final id = await showAccountSelectBottomSheet(
      context,
      accounts,
      selectedAccountId: _selectedAccountId,
      title: '选择账户',
    );
    if (!mounted || id == null) return;
    setState(() => _selectedAccountId = id);
  }

  Future<void> _openTagPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagPickerBottomSheet(
        initialSelectedIds: _selectedTagIds.toSet(),
        onChanged: (ids) {
          if (!mounted) return;
          setState(() => _selectedTagIds = ids.toList());
        },
      ),
    );
  }

  Future<void> _openStartDatePicker() async {
    final initial = _startDate ?? _dateOnly(DateTime.now());
    final picked = await showYmdDatePickerSheet(
      context,
      title: '首次记账日期',
      initialDate: initial,
      minDate: DateTime(2000, 1, 1),
      maxDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _startDate = _dateOnly(picked));
  }

  Future<void> _openRepeatPicker() async {
    final picked = await showModalBottomSheet<_RepeatPicked>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final weekSubtitle = _weekday == null ? '请选择星期' : _weekdayLabel(_weekday!);
        final monthSubtitle =
            _monthDay == null ? '请选择日期' : '$_monthDay号';
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('每周'),
                subtitle: Text(weekSubtitle),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withOpacity(0.55),
                ),
                onTap: () => Navigator.pop(
                  ctx,
                  _RepeatPicked(
                    periodType: RecurringPeriodType.weekly,
                    weekday: _weekday ?? DateTime.now().weekday,
                    monthDay: null,
                  ),
                ),
              ),
              ListTile(
                title: const Text('每月'),
                subtitle: Text(monthSubtitle),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withOpacity(0.55),
                ),
                onTap: () => Navigator.pop(
                  ctx,
                  _RepeatPicked(
                    periodType: RecurringPeriodType.monthly,
                    weekday: null,
                    monthDay: _monthDay ?? DateTime.now().day,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked.periodType == RecurringPeriodType.weekly) {
      final weekday = await _openWeekdayPicker(initial: picked.weekday ?? DateTime.now().weekday);
      if (!mounted || weekday == null) return;
      setState(() {
        _periodType = RecurringPeriodType.weekly;
        _weekday = weekday;
      });
      return;
    }
    final day = await _openMonthDayPicker(initial: picked.monthDay ?? DateTime.now().day);
    if (!mounted || day == null) return;
    setState(() {
      _periodType = RecurringPeriodType.monthly;
      _monthDay = day;
    });
  }

  Future<int?> _openWeekdayPicker({required int initial}) async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 7; i++)
                ListTile(
                  title: Text(_weekdayLabel(i)),
                  trailing: (i == initial) ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(ctx, i),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _openMonthDayPicker({required int initial}) async {
    final days = List<int>.generate(31, (i) => i + 1);
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '选择日期',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: days.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final d = days[index];
                      final selected = d == initial;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, d),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primary.withOpacity(0.14)
                                : cs.surfaceContainerHighest.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? cs.primary
                                  : cs.outlineVariant.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            '$d',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? cs.primary : cs.onSurface.withOpacity(0.8),
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
      },
    );
  }

  Future<void> _openAmountPad() async {
    await showNumberPadBottomSheet(
      context,
      controller: _amountCtrl,
      allowDecimal: true,
      formatFixed2OnClose: true,
    );
  }

  String _displayCategoryName(List<Category> categories) {
    final key = _selectedCategoryKey;
    if (key == null) return '请选择分类';
    final cat = categories.where((c) => c.key == key).toList();
    return cat.isEmpty ? '请选择分类' : cat.first.name;
  }

  IconData _displayCategoryIcon(List<Category> categories) {
    final key = _selectedCategoryKey;
    if (key == null) return Icons.category_rounded;
    final cat = categories.where((c) => c.key == key).toList();
    return cat.isEmpty ? Icons.category_rounded : cat.first.icon;
  }

  String _displayAccountName(List<Account> accounts) {
    final id = _selectedAccountId;
    if (id == null) return '请选择账户';
    final acc = accounts.where((a) => a.id == id).toList();
    return acc.isEmpty ? '请选择账户' : acc.first.name;
  }

  String _displayTags(List<Tag> tags) {
    if (_selectedTagIds.isEmpty) return '不添加标签';
    final selected = tags.where((t) => _selectedTagIds.contains(t.id)).toList();
    if (selected.isEmpty) return '不添加标签';
    if (selected.length <= 2) return selected.map((t) => t.name).join('、');
    return '${selected.take(2).map((t) => t.name).join('、')} 等${selected.length}个';
  }

  String _displayRepeat() {
    if (_periodType == RecurringPeriodType.weekly) {
      final w = _weekday;
      return w == null ? '请选择周期' : '每周 ${_weekdayLabel(w)}';
    }
    final d = _monthDay;
    return d == null ? '请选择周期' : '每月 ${d}号';
  }

  static String _weekdayLabel(int weekday) {
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

  static DateTime _firstDueDate(
    DateTime start,
    RecurringPeriodType periodType, {
    int? weekday,
    int? monthDay,
  }) {
    final s = _dateOnly(start);
    if (periodType == RecurringPeriodType.weekly) {
      final w = weekday ?? s.weekday;
      final delta = (w - s.weekday) % 7;
      return s.add(Duration(days: delta));
    }

    final desiredDay = monthDay ?? s.day;
    final lastDayThisMonth = DateTime(s.year, s.month + 1, 0).day;
    final clampedThis = desiredDay.clamp(1, lastDayThisMonth);
    var candidate = DateTime(s.year, s.month, clampedThis);
    if (!candidate.isBefore(s)) return candidate;

    final nextMonth = _addMonthsClampedByDay(s, 1, desiredDay);
    return nextMonth;
  }

  static DateTime _addMonthsClampedByDay(DateTime from, int monthsToAdd, int dayOfMonth) {
    final year = from.year;
    final month0 = from.month - 1 + monthsToAdd;
    final targetYear = year + month0 ~/ 12;
    final targetMonth = month0 % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = dayOfMonth.clamp(1, lastDay);
    return DateTime(targetYear, targetMonth, day);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final bookId = context.read<BookProvider>().activeBookId;
    final recurringProvider = context.read<RecurringRecordProvider>();
    final accountProvider = context.read<AccountProvider>();

    final categoryKey = _selectedCategoryKey;
    if (categoryKey == null || categoryKey.isEmpty) {
      ErrorHandler.showWarning(context, '请选择分类');
      return;
    }

    final startNullable = _startDate;
    if (startNullable == null) {
      ErrorHandler.showWarning(context, '请选择首次记账日期');
      return;
    }

    final rawAmount = _amountCtrl.text.trim();
    final normalized = rawAmount.startsWith('.') ? '0$rawAmount' : rawAmount;
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) {
      ErrorHandler.showWarning(context, '请输入正确金额');
      return;
    }

    final accountId = (_selectedAccountId ?? '').trim();
    final resolvedAccount = await accountProvider.ensureDefaultWallet(bookId: bookId);
    final finalAccountId = accountId.isEmpty ? resolvedAccount.id : accountId;

    final start = _dateOnly(startNullable);

    final base = widget.plan;
    final id = base?.id ?? recurringProvider.generateId();
    final firstDue = _firstDueDate(
      start,
      _periodType,
      weekday: _weekday,
      monthDay: _monthDay,
    );
    final nextDate = base == null
        ? firstDue
        : (firstDue.isAfter(base.nextDate) ? firstDue : base.nextDate);

    final plan = RecurringRecordPlan(
      id: id,
      bookId: bookId,
      categoryKey: categoryKey,
      accountId: finalAccountId,
      direction: _isExpense ? TransactionDirection.out : TransactionDirection.income,
      includeInStats: base?.includeInStats ?? true,
      amount: amount,
      remark: _remarkCtrl.text.trim(),
      enabled: base?.enabled ?? true,
      periodType: _periodType,
      startDate: start,
      nextDate: nextDate,
      lastRunAt: base?.lastRunAt,
      tagIds: List<String>.from(_selectedTagIds),
      weekday: _weekday,
      monthDay: _monthDay,
    );

    setState(() => _isSaving = true);
    try {
      await recurringProvider.upsert(plan);
      if (!mounted) return;
      Navigator.pop(context);
      ErrorHandler.showSuccess(context, '已保存');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final categories = context.watch<CategoryProvider>().categories;
    final accounts = context.watch<AccountProvider>().accounts;
    final tags = context.watch<TagProvider>().tags;
    final title = widget.plan == null ? '添加定时记账' : '编辑定时记账';

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: const Color(0x00000000),
        leadingWidth: 64,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildCard(
            children: [
              _FormRow(
                label: '记账类型',
                trailing: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('支出')),
                    ButtonSegment(value: false, label: Text('收入')),
                  ],
                  selected: {_isExpense},
                  onSelectionChanged: (set) {
                    setState(() {
                      _isExpense = set.first;
                      _selectedCategoryKey = null;
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              _FormRow(
                label: '分类',
                value: _displayCategoryName(categories),
                leadingIcon: _displayCategoryIcon(categories),
                onTap: _openCategoryPicker,
              ),
              const Divider(height: 1),
              _FormRow(
                label: '标签',
                value: _displayTags(tags),
                onTap: _openTagPicker,
              ),
              const Divider(height: 1),
              _FormRow(
                label: '首次记账日期',
                value: _startDate == null ? '请选择日期' : _ymd(_startDate!),
                onTap: _openStartDatePicker,
              ),
              const Divider(height: 1),
              _FormRow(
                label: '金额',
                value: _amountCtrl.text.trim().isEmpty ? '请输入金额' : _amountCtrl.text.trim(),
                valueEmphasis: true,
                onTap: _openAmountPad,
              ),
              const Divider(height: 1),
              _FormRow(
                label: '账户',
                value: _displayAccountName(accounts),
                onTap: _openAccountPicker,
              ),
              const Divider(height: 1),
              _FormRow(
                label: '备注',
                trailing: Expanded(
                  child: TextField(
                    controller: _remarkCtrl,
                    textAlign: TextAlign.end,
                    textAlignVertical: TextAlignVertical.center,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                    decoration: InputDecoration(
                      hintText: '选填',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(0.55),
                          ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              _FormRow(
                label: '重复',
                value: _displayRepeat(),
                onTap: _openRepeatPicker,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '说明：定时记账会在你打开 App（或回到前台）时检查并自动补齐错过的记录。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCard({required List<Widget> children}) {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(children: children),
      );
    });
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _ymd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.leadingIcon,
    this.valueEmphasis = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final IconData? leadingIcon;
  final bool valueEmphasis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isClickable = onTap != null;
    final displayValue = value ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leadingIcon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  leadingIcon,
                  size: 18,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            Text(
              label,
              style: tt.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              trailing!
            else
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        displayValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: valueEmphasis ? FontWeight.w700 : FontWeight.w400,
                          color: displayValue.isEmpty || displayValue.contains('请选择') || displayValue == '请输入金额'
                              ? cs.onSurface.withOpacity(0.45)
                              : cs.onSurface.withOpacity(0.82),
                        ),
                      ),
                    ),
                    if (isClickable)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
    this.active = false,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.12)
              : (active ? cs.surfaceContainerHighest.withOpacity(0.35) : cs.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? cs.primary
                : (active
                    ? cs.primary.withOpacity(0.35)
                    : cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 22,
              color: selected ? cs.primary : cs.onSurface.withOpacity(0.75),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatPicked {
  const _RepeatPicked({
    required this.periodType,
    this.weekday,
    this.monthDay,
  });

  final RecurringPeriodType periodType;
  final int? weekday;
  final int? monthDay;
}
