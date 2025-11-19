import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
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
                      '快速记一笔',
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
                _buildDatePicker(),
                const SizedBox(height: 16),
                _buildRemarkField(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _handleSubmit,
                    child: const Text('保存'),
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
      onSelectionChanged: (value) {
        setState(() => _isExpense = value.first);
      },
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    if (categories.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              '暂无分类，请先前往「我的」页面添加分类',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/category-manager').then((_) {
                setState(() {});
              });
            },
            child: const Text('去管理'),
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
              '分类',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/category-manager').then((_) {
                  setState(() {});
                });
              },
              child: const Text('管理分类'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
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
    final exists =
        categories.any((element) => element.key == _selectedCategoryKey);
    if (!exists) {
      _selectedCategoryKey = categories.first.key;
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final last = DateTime(today.year, today.month, today.day);
    final initial =
        _selectedDate.isAfter(last) ? last : _selectedDate;
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

    final actualAmount = _isExpense ? amount : -amount;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记账成功')),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
