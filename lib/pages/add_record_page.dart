import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/saving_goal.dart';
import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _isExpense = _lastIsExpense;
    _includeInStats = _lastIncludeInStats;
    _selectedGoalId = _lastSavingGoalId;
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
    final filtered = categories.where((c) => c.isExpense == _isExpense).toList();
    _ensureCategorySelection(filtered);
    _ensureAccountSelection();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addRecord),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountField(),
            const SizedBox(height: 20),
            _buildTypeSwitcher(),
            const SizedBox(height: 16),
            _buildCategoryPicker(filtered),
            const SizedBox(height: 16),
            _buildAccountPicker(),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 16),
            _buildRemarkField(),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeInStats,
              title: const Text('计入收支统计'),
              onChanged: (v) => setState(() => _includeInStats = v),
            ),
            if (_showSavingGoalSection())
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildSavingGoalPicker(),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _handleSubmit,
                child: const Text(
                  AppStrings.save,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.category,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedCategoryKey,
          items: categories
              .map(
                (cat) => DropdownMenuItem(
                  value: cat.key,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(cat.name),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: categories.isEmpty
              ? null
              : (value) => setState(() => _selectedCategoryKey = value),
          decoration: const InputDecoration(
            hintText: AppStrings.selectCategory,
            border: OutlineInputBorder(),
          ),
        ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              AppStrings.emptyCategoryForRecord,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
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
          '璐︽埛',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedAccountId,
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} 路 ${a.currentBalance.toStringAsFixed(2)}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _selectedAccountId = value;
            _selectedGoalId = null;
          }),
          decoration: const InputDecoration(
            hintText: '閫夋嫨璐︽埛',
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
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
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
    return TextField(
      controller: _remarkCtrl,
      maxLines: 2,
      decoration: const InputDecoration(
        hintText: AppStrings.remarkOptional,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSavingGoalPicker() {
    final goalProvider = context.watch<SavingGoalProvider>();
    final accountId = _selectedAccountId;
    final goals = goalProvider.goals
        .where((g) => g.accountId == accountId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '杩欑瑪閽辨槸鍚︾敤浜庢煇涓瓨娆剧洰鏍囷紵',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGoalId,
          items: goals
              .map(
                (g) => DropdownMenuItem(
                  value: g.id,
                  child: Text('${g.name} 路 鐩爣 楼${g.targetAmount.toStringAsFixed(0)}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedGoalId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '閫夋嫨瀛樻鐩爣锛堝彲閫夛級',
          ),
        ),
      ],
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
      _showMessage('璇烽€夋嫨璐︽埛');
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

    if (!mounted) return;
    Navigator.pop(context);
    debugPrint('Record created ${record.id}');
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
}





