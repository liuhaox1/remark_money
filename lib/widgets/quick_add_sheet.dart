import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/date_utils.dart';

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryKey;
  String? _selectedAccountId;
  bool _includeInStats = true;

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

    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      AppStrings.quickAddPrimary,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAmountField(),
                const SizedBox(height: 16),
                _buildTypeSwitcher(),
                const SizedBox(height: 16),
                _buildCategoryPicker(filtered),
                const SizedBox(height: 16),
                _buildAccountPicker(),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 16),
                _buildRemarkField(),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _includeInStats,
                  title: const Text('计入收支统计'),
                  onChanged: (v) => setState(() => _includeInStats = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _handleSubmit,
                    child: const Text(AppStrings.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
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
      onSelectionChanged: (value) {
        setState(() => _isExpense = value.first);
      },
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    // 仅展示二级分类
    final secondLevel =
        categories.where((c) => c.parentKey != null).toList();
    if (categories.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              AppStrings.emptyCategoryForRecord,
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/category-manager').then((_) {
                setState(() {});
              });
            },
            child: const Text(AppStrings.goManage),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              AppStrings.category,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/category-manager').then((_) {
                  setState(() {});
                });
              },
              child: const Text(AppStrings.manageCategory),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: secondLevel.map((cat) {
            final selected = cat.key == _selectedCategoryKey;
            return ChoiceChip(
              selected: selected,
              avatar: Icon(cat.icon, size: 18),
              label: Text(cat.name),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              onSelected: (_) {
                setState(() => _selectedCategoryKey = cat.key);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
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
            Text(DateUtilsX.ymd(_selectedDate)),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
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

  Widget _buildAccountPicker() {
    final accounts = context.watch<AccountProvider>().accounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '账户',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedAccountId,
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} · ${a.currentBalance.toStringAsFixed(2)}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedAccountId = value),
          decoration: const InputDecoration(
            hintText: '从哪个账户出/入',
            border: OutlineInputBorder(),
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
    final exists =
        categories.any((element) => element.key == _selectedCategoryKey);
    if (!exists) {
      _selectedCategoryKey = categories.first.key;
    }
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
    await context.read<RecordProvider>().addRecord(
          amount: amount,
          remark: _remarkCtrl.text.trim(),
          date: _selectedDate,
          categoryKey: _selectedCategoryKey!,
          bookId: bookId,
          accountId: _selectedAccountId!,
          direction: direction,
          includeInStats: _includeInStats,
          accountProvider: accountProvider,
        );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.recordSaved)),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _ensureAccountSelection() {
    if (_selectedAccountId != null) return;
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) return;
    _selectedAccountId = accounts.first.id;
  }
}
