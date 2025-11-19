import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        title: const Text('新增记账'),
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
                  '保存',
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
        hintText: '输入金额',
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildTypeSwitcher() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('支出')),
        ButtonSegment(value: false, label: Text('收入')),
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
          '分类',
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
            hintText: '请选择分类',
            border: OutlineInputBorder(),
          ),
        ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '暂无分类，请先在分类管理中添加',
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
          '日期',
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
        hintText: '备注（可选）',
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
      helpText: '选择日期',
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _handleSubmit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('请填写正确的金额');
      return;
    }
    if (_selectedCategoryKey == null) {
      _showMessage('请先添加并选择分类');
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
