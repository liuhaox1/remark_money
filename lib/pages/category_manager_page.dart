import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../repository/category_repository.dart';
import '../theme/app_tokens.dart';

class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({super.key});

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<CategoryManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final expense = provider.categories.where((c) => c.isExpense).toList();
    final income = provider.categories.where((c) => !c.isExpense).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.categoryManager),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(expense),
          _buildList(income),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<Category> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Text(
          AppStrings.emptyCategoryHint,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = categories[index];
        final deletable = !_isDefaultCategory(category.key);
        return ListTile(
          leading: CircleAvatar(child: Icon(category.icon)),
          title: Text(category.name),
          subtitle: Text(category.key),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditCategoryDialog(category),
              ),
              if (deletable)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(category),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isDefaultCategory(String key) {
    return CategoryRepository.defaultCategories
        .any((element) => element.key == key);
  }

  Future<void> _confirmDelete(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除分类'),
          content: Text('确定要删除${category.name}吗'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) {
      await context.read<CategoryProvider>().deleteCategory(category.key);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await _showCategoryDialog();
    if (result != null && mounted) {
      await context.read<CategoryProvider>().addCategory(result);
    }
  }

  Future<void> _showEditCategoryDialog(Category original) async {
    final updated = await _showCategoryDialog(original: original);
    if (updated != null && mounted) {
      await context.read<CategoryProvider>().updateCategory(updated);
    }
  }

  Future<Category?> _showCategoryDialog({Category? original}) {
    return showDialog<Category>(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController(text: original?.name ?? '');
        IconData selectedIcon = original?.icon ?? _iconOptions.first;
        bool isExpense = original?.isExpense ?? _tabController.index == 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(original == null ? '新增分类' : '编辑分类'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '例如：奶茶',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '类型',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('支出')),
                        ButtonSegment(value: false, label: Text('收入')),
                      ],
                      selected: {isExpense},
                      onSelectionChanged: (value) {
                        setState(() => isExpense = value.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '图标',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((icon) {
                        final selected = icon == selectedIcon;
                        return ChoiceChip(
                          label: Icon(icon),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => selectedIcon = icon);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写分类名称')),
                      );
                      return;
                    }
                    final category = Category(
                      key: original?.key ??
                          'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      icon: selectedIcon,
                      isExpense: isExpense,
                    );
                    Navigator.pop(context, category);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<IconData> get _iconOptions => const [
        Icons.restaurant,
        Icons.shopping_bag,
        Icons.directions_bus,
        Icons.flash_on,
        Icons.local_hospital,
        Icons.school,
        Icons.home,
        Icons.sports_esports,
        Icons.pets,
        Icons.card_giftcard,
      ];
}
