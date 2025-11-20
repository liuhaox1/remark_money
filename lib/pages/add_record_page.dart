import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';

class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key, this.isExpense = true});

  final bool isExpense;

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  late bool _isExpense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryKey;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.isExpense;
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
            _buildDatePicker(),
            const SizedBox(height: 16),
            _buildRemarkField(),
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

    final actualAmount = _isExpense ? -amount : amount;
    final bookId = context.read<BookProvider>().activeBookId;

    await context.read<RecordProvider>().addRecord(
          amount: actualAmount,
          remark: _remarkCtrl.text.trim(),
          date: _selectedDate,
          categoryKey: _selectedCategoryKey!,
          bookId: bookId,
        );

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
