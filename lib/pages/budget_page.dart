import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../theme/app_tokens.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final TextEditingController _totalCtrl = TextEditingController();
  final Map<String, TextEditingController> _categoryCtrls = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final budget = context.read<BudgetProvider>().budget;
    final categories = context.read<CategoryProvider>().categories;

    _totalCtrl.text = budget.total == 0 ? '' : budget.total.toStringAsFixed(0);
    for (final cat in categories) {
      _categoryCtrls[cat.key] = TextEditingController(
        text: budget.categoryBudgets[cat.key]?.toStringAsFixed(0) ?? '',
      );
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    for (final c in _categoryCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final provider = context.read<BudgetProvider>();
    final total = double.tryParse(_totalCtrl.text.trim()) ?? 0;

    final categoryBudgets = <String, double>{};
    _categoryCtrls.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isEmpty) return;
      final amount = double.tryParse(value);
      if (amount != null && amount > 0) {
        categoryBudgets[key] = amount;
      }
    });

    await provider.updateBudget(
      totalBudget: total,
      categoryBudgets: categoryBudgets,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = context.watch<CategoryProvider>().categories;
    final expenseCats = categories.where((c) => c.isExpense).toList();
    final incomeCats = categories.where((c) => !c.isExpense).toList();

    for (final cat in categories) {
      _categoryCtrls.putIfAbsent(cat.key, () => TextEditingController());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度总预算',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _totalCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '¥ ',
                filled: true,
                fillColor: cs.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: '输入整个月的预算（可选）',
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '支出分类预算',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (expenseCats.isEmpty)
              const Text(
                '暂无支出分类，可以在分类管理中新增',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...expenseCats.map(_buildCategoryField),
            const SizedBox(height: 24),
            Text(
              '收入分类预算',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (incomeCats.isEmpty)
              const Text(
                '暂无收入分类，可以在分类管理中新增',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...incomeCats.map(_buildCategoryField),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveBudget,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  '保存预算',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryField(Category cat) {
    final cs = Theme.of(context).colorScheme;
    final controller = _categoryCtrls[cat.key]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(cat.icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cat.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                hintText: '预算',
                prefixText: '¥ ',
                isDense: true,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

