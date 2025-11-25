import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_record.dart';
import '../models/record_template.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../repository/record_template_repository.dart';
import '../repository/recurring_record_repository.dart';
import 'add_account_type_page.dart';

class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key, this.isExpense = true});

  final bool isExpense;

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  static bool _lastIsExpense = true;
  static String? _lastAccountId;
  static bool _lastIncludeInStats = true;
  static String? _lastSavingGoalId;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  late bool _isExpense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryKey;
  String? _selectedAccountId;
  bool _includeInStats = true;
  String? _selectedGoalId;
  bool _saveAsTemplate = false;
  bool _isRecurring = false;
  RecurringPeriodType _recurringPeriodType = RecurringPeriodType.monthly;
  String? _activeRecurringPlanId;
  bool _showRemarkInput = false;
  String _amountExpression = '';

  final RecordTemplateRepository _templateRepository =
      RecordTemplateRepository();
  final RecurringRecordRepository _recurringRepository =
      RecurringRecordRepository();

  List<RecordTemplate> _templates = const [];
  List<RecurringRecordPlan> _duePlans = const [];

  @override
  void initState() {
    super.initState();
    _isExpense = _lastIsExpense = widget.isExpense;
    _includeInStats = _lastIncludeInStats;
    _selectedGoalId = _lastSavingGoalId;
    _loadTemplatesAndPlans();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final filtered =
        categories.where((c) => c.isExpense == _isExpense).toList();
    _ensureCategorySelection(filtered);
    _ensureAccountSelection();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addRecord),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_duePlans.isNotEmpty) _buildRecurringBanner(),
                  if (_duePlans.isNotEmpty) const SizedBox(height: 12),
                  _buildAmountAndTypeRow(),
                  const SizedBox(height: 24),
                  if (_templates.isNotEmpty) ...[
                    _buildTemplateChips(),
                    const SizedBox(height: 16),
                  ],
                  _buildCategoryPicker(filtered),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildAccountPicker()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDatePicker()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildRemarkField(),
                  const SizedBox(height: 8),
                  _buildAdvancedSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _buildNumberPad(),
        ],
      ),
    );
  }

  Widget _buildAmountAndTypeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 140,
          child: _buildTypeSwitcher(),
        ),
        const SizedBox(width: 16),
        Expanded(child: _buildAmountField()),
      ],
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
      textAlign: TextAlign.right,
      readOnly: true,
      decoration: const InputDecoration(
        prefixText: '¥ ',
        hintText: AppStrings.inputAmount,
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildTypeSwitcher() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text(AppStrings.expense)),
        ButtonSegment(value: false, label: Text(AppStrings.income)),
      ],
      selected: {_isExpense},
      onSelectionChanged: (set) {
        setState(() {
          _isExpense = set.first;
          _lastIsExpense = _isExpense;
          if (_isExpense) {
            _selectedGoalId = null;
          }
        });
      },
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    return _buildCategoryQuickPicker(categories);
  }

  Widget _buildCategoryQuickPicker(List<Category> categories) {
    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            AppStrings.category,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            AppStrings.emptyCategoryForRecord,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.category,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: categories.map((cat) {
            final selected = cat.key == _selectedCategoryKey;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => _selectedCategoryKey = cat.key);
              },
              child: Container(
                width: 80,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 22,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountPicker() {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '账户',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedAccountId,
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.name} · ${a.currentBalance.toStringAsFixed(2)}',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _selectedAccountId = value;
            _selectedGoalId = null;
          }),
          decoration: const InputDecoration(
            hintText: '选择账户',
            border: OutlineInputBorder(),
          ),
        ),
        if (accounts.isEmpty)
          TextButton(
            onPressed: () async {
              await Navigator.push<AccountKind>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddAccountTypePage(),
                ),
              );
              if (!mounted) return;
              setState(() => _selectedAccountId = null);
            },
            child: const Text('去添加账户'),
          ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.selectDate,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceVariant
                  .withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateUtilsX.ymd(_selectedDate),
                  style: const TextStyle(fontSize: 15),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarkField() {
    if (_showRemarkInput || _remarkCtrl.text.isNotEmpty) {
      return TextField(
        controller: _remarkCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: AppStrings.remarkOptional,
          border: OutlineInputBorder(),
        ),
        onChanged: (_) {
          setState(() {});
        },
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _showRemarkInput = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.4),
        ),
        child: const Text(
          AppStrings.remarkOptional,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final color = Theme.of(context).colorScheme.surface;

    Widget buildKey({
      required String label,
      VoidCallback? onTap,
      Color? background,
      Color? textColor,
      FontWeight fontWeight = FontWeight.w500,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            color: background ?? color,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: textColor ?? AppColors.textMain,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottom > 0 ? 0 : 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                buildKey(label: '7', onTap: () => _onDigitTap('7')),
                buildKey(label: '8', onTap: () => _onDigitTap('8')),
                buildKey(label: '9', onTap: () => _onDigitTap('9')),
                buildKey(
                  label: '今天',
                  fontWeight: FontWeight.w600,
                  onTap: _onTodayTap,
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '4', onTap: () => _onDigitTap('4')),
                buildKey(label: '5', onTap: () => _onDigitTap('5')),
                buildKey(label: '6', onTap: () => _onDigitTap('6')),
                buildKey(
                  label: '+',
                  onTap: () => _onOperatorTap('+'),
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '1', onTap: () => _onDigitTap('1')),
                buildKey(label: '2', onTap: () => _onDigitTap('2')),
                buildKey(label: '3', onTap: () => _onDigitTap('3')),
                buildKey(
                  label: '-',
                  onTap: () => _onOperatorTap('-'),
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '.', onTap: _onDotTap),
                buildKey(label: '0', onTap: () => _onDigitTap('0')),
                buildKey(
                  label: '⌫',
                  onTap: _onBackspace,
                  textColor: AppColors.textSecondary,
                ),
                Expanded(
                  child: InkWell(
                    onTap: _onPadSubmit,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.primary,
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onDigitTap(String digit) {
    setState(() {
      _amountExpression += digit;
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onDotTap() {
    setState(() {
      _amountExpression += '.';
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onOperatorTap(String op) {
    setState(() {
      if (_amountExpression.isEmpty) {
        if (op == '-') {
          _amountExpression = '-';
        }
      } else {
        final last = _amountExpression[_amountExpression.length - 1];
        if (last == '+' || last == '-') {
          _amountExpression =
              _amountExpression.substring(0, _amountExpression.length - 1) +
                  op;
        } else {
          _amountExpression += op;
        }
      }
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onBackspace() {
    if (_amountExpression.isEmpty) return;
    setState(() {
      _amountExpression =
          _amountExpression.substring(0, _amountExpression.length - 1);
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onTodayTap() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  double? _evaluateAmount() {
    var exp = _amountExpression.trim();
    if (exp.isEmpty) return null;
    final last = exp[exp.length - 1];
    if (last == '+' || last == '-') {
      exp = exp.substring(0, exp.length - 1);
    }
    if (exp.isEmpty) return null;

    final regex = RegExp(r'([+-])|([0-9]*\.?[0-9]+)');
    double total = 0;
    var op = '+';
    for (final match in regex.allMatches(exp)) {
      final token = match.group(0)!;
      if (token == '+' || token == '-') {
        op = token;
      } else {
        final value = double.tryParse(token);
        if (value == null) return null;
        if (op == '+') {
          total += value;
        } else {
          total -= value;
        }
      }
    }
    return total;
  }

  Future<void> _onPadSubmit() async {
    final amount = _evaluateAmount();
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.amountError);
      return;
    }
    _amountCtrl.text = amount.toStringAsFixed(2);
    // 清空表达式，后续若再次编辑会从结果继续
    _amountExpression = _amountCtrl.text;
    await _handleSubmit();
  }

  Widget _buildSavingGoalPicker() {
    final goalProvider = context.watch<SavingGoalProvider>();
    final accountId = _selectedAccountId;
    final goals =
        goalProvider.goals.where((g) => g.accountId == accountId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '这笔钱关联到哪个存钱目标？',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGoalId,
          items: goals
              .map(
                (g) => DropdownMenuItem(
                  value: g.id,
                  child: Text(
                    '${g.name} · 目标 ¥${g.targetAmount.toStringAsFixed(0)}',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedGoalId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '选择目标（可选）',
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        '更多设置',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        '记账习惯、统计和循环记账',
        style: TextStyle(fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.only(top: 4),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInStats,
          title: const Text('计入统计'),
          onChanged: (v) => setState(() => _includeInStats = v),
        ),
        if (_showSavingGoalSection())
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildSavingGoalPicker(),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saveAsTemplate,
          title: const Text('保存为常用模板'),
          subtitle: const Text(
            '保存当前分类、账户和备注，方便下次快速填写。',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _saveAsTemplate = v ?? false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isRecurring,
          title: const Text('设为循环记账'),
          subtitle: const Text(
            '每周或每月提醒你再次记这笔账，不会自动生成记录。',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _isRecurring = v),
        ),
        if (_isRecurring)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                const Text(
                  '循环周期',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                DropdownButton<RecurringPeriodType>(
                  value: _recurringPeriodType,
                  items: const [
                    DropdownMenuItem(
                      value: RecurringPeriodType.weekly,
                      child: Text('每周'),
                    ),
                    DropdownMenuItem(
                      value: RecurringPeriodType.monthly,
                      child: Text('每月'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _recurringPeriodType = v);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTemplateChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '常用模板',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _templates
              .map(
                (t) => ChoiceChip(
                  label: Text(
                    t.remark.isNotEmpty ? t.remark : t.categoryKey,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: false,
                  onSelected: (_) => _applyTemplate(t),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRecurringBanner() {
    final plan = _duePlans.first;
    return InkWell(
      onTap: () => _applyRecurringPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.refresh_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '有循环记账待记录，点击一键带出草稿。',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  void _ensureCategorySelection(List<Category> categories) {
    if (categories.isEmpty) {
      _selectedCategoryKey = null;
      return;
    }
    final exists = categories.any((c) => c.key == _selectedCategoryKey);
    if (!exists) {
      _selectedCategoryKey = categories.first.key;
    }
  }

  void _ensureAccountSelection() {
    if (_selectedAccountId != null) return;
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) return;
    final exists = accounts.any((a) => a.id == _lastAccountId);
    if (_lastAccountId != null && exists) {
      _selectedAccountId = _lastAccountId;
      return;
    }
    _selectedAccountId = accounts.first.id;
  }

  Future<void> _loadTemplatesAndPlans() async {
    final templates = await _templateRepository.loadTemplates();
    final plans = await _recurringRepository.loadPlans();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = plans
        .where((p) => !p.nextDate.isAfter(todayDate))
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _duePlans = due;
    });
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final last = DateTime(today.year, today.month, today.day);
    final initial = _selectedDate.isAfter(last) ? last : _selectedDate;

    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 5),
      lastDate: last,
      helpText: AppStrings.selectDate,
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _handleSubmit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.amountError);
      return;
    }
    if (_selectedCategoryKey == null) {
      _showMessage(AppStrings.selectCategoryError);
      return;
    }
    if (_selectedAccountId == null) {
      _showMessage('请选择账户');
      return;
    }

    final direction =
        _isExpense ? TransactionDirection.out : TransactionDirection.income;
    final bookId = context.read<BookProvider>().activeBookId;
    final accountProvider = context.read<AccountProvider>();
    final savingGoalProvider = context.read<SavingGoalProvider>();
    final targetId = _showSavingGoalSection() ? _selectedGoalId : null;

    final record = await context.read<RecordProvider>().addRecord(
          amount: amount,
          remark: _remarkCtrl.text.trim(),
          date: _selectedDate,
          categoryKey: _selectedCategoryKey!,
          bookId: bookId,
          accountId: _selectedAccountId!,
          direction: direction,
          includeInStats: _includeInStats,
          targetId: targetId,
          accountProvider: accountProvider,
          savingGoalProvider: savingGoalProvider,
        );

    _lastAccountId = _selectedAccountId;
    _lastIncludeInStats = _includeInStats;
    _lastSavingGoalId = _selectedGoalId;

    await _maybeSaveTemplate(record);
    await _maybeSaveOrUpdateRecurring(record);

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  bool _showSavingGoalSection() {
    if (_selectedAccountId == null) return false;
    if (_isExpense) return false;
    final account =
        context.read<AccountProvider>().byId(_selectedAccountId!);
    return account?.kind == AccountKind.asset;
  }

  Future<void> _maybeSaveTemplate(Record record) async {
    if (!_saveAsTemplate) return;
    final template = RecordTemplate(
      id: record.id,
      categoryKey: record.categoryKey,
      accountId: record.accountId,
      direction: record.direction,
      includeInStats: record.includeInStats,
      remark: record.remark,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
    await _templateRepository.upsertTemplate(template);
  }

  Future<void> _maybeSaveOrUpdateRecurring(Record record) async {
    if (!_isRecurring) return;

    final nextDate = _recurringPeriodType == RecurringPeriodType.weekly
        ? record.date.add(const Duration(days: 7))
        : DateTime(record.date.year, record.date.month + 1, record.date.day);

    final planId = _activeRecurringPlanId ?? record.id;
    final plan = RecurringRecordPlan(
      id: planId,
      bookId: record.bookId,
      categoryKey: record.categoryKey,
      accountId: record.accountId,
      direction: record.direction,
      includeInStats: record.includeInStats,
      amount: record.amount,
      remark: record.remark,
      periodType: _recurringPeriodType,
      nextDate: nextDate,
    );
    await _recurringRepository.upsert(plan);
  }

  Future<void> _applyTemplate(RecordTemplate template) async {
    setState(() {
      _isExpense = template.direction == TransactionDirection.out;
      _lastIsExpense = _isExpense;
      _selectedCategoryKey = template.categoryKey;
      _selectedAccountId = template.accountId;
      _includeInStats = template.includeInStats;
      if (template.remark.isNotEmpty) {
        _remarkCtrl.text = template.remark;
      }
    });
    await _templateRepository.markUsed(template.id);
  }

  void _applyRecurringPlan(RecurringRecordPlan plan) {
    setState(() {
      _activeRecurringPlanId = plan.id;
      _isRecurring = true;
      _recurringPeriodType = plan.periodType;
      _isExpense = plan.direction == TransactionDirection.out;
      _lastIsExpense = _isExpense;
      _selectedCategoryKey = plan.categoryKey;
      _selectedAccountId = plan.accountId;
      _includeInStats = plan.includeInStats;
      _amountCtrl.text = plan.amount.toStringAsFixed(2);
      _remarkCtrl.text = plan.remark;
      _selectedDate = plan.nextDate;
    });
  }
}
