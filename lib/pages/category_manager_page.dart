import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
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
  final Set<String> _expandedTopKeys = <String>{};

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
            Tab(text: AppStrings.expenseCategory),
            Tab(text: AppStrings.incomeCategory),
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

    // 一级分类：parentKey 为空
    final topCategories =
        categories.where((c) => c.parentKey == null).toList();

    // 二级分类分组
    final Map<String, List<Category>> childrenMap = {};
    for (final c in categories) {
      final parent = c.parentKey;
      if (parent == null) continue;
      childrenMap.putIfAbsent(parent, () => []).add(c);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: topCategories.length,
      itemBuilder: (context, index) {
        final top = topCategories[index];
        final children = childrenMap[top.key] ?? const <Category>[];
        return _buildTopCategoryItem(top, children);
      },
    );
  }

  Widget _buildTopCategoryItem(
    Category top,
    List<Category> children,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final expanded = _expandedTopKeys.contains(top.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedTopKeys.remove(top.key);
                } else {
                  _expandedTopKeys.add(top.key);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withOpacity(0.08),
                    child: Icon(
                      top.icon,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      top.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showEditCategoryDialog(top),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDelete(top),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            if (children.isNotEmpty)
              const Divider(height: 1, indent: 56, endIndent: 12),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                child: Column(
                  children: children
                      .map(
                        (c) => _buildChildCategoryItem(c),
                      )
                      .toList(),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddSubCategoryDialog(top),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加子分类'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChildCategoryItem(Category category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            category.icon,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showEditCategoryDialog(category),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _confirmDelete(category),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubCategoryDialog(Category parent) async {
    final created = await _showCategoryDialog(
      parentKey: parent.key,
      initialIsExpense: parent.isExpense,
    );
    if (created != null && mounted) {
      await context.read<CategoryProvider>().addCategory(created);
      setState(() => _expandedTopKeys.add(parent.key));
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.deleteCategory),
          content: Text(AppStrings.deleteCategoryConfirm(category.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.delete),
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

  Future<Category?> _showCategoryDialog({
    Category? original,
    String? parentKey,
    bool? initialIsExpense,
  }) {
    return showDialog<Category>(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController(text: original?.name ?? '');
        IconData selectedIcon = original?.icon ?? _iconOptions.first;
        final String? effectiveParentKey =
            original?.parentKey ?? parentKey;
        bool isExpense =
            original?.isExpense ?? initialIsExpense ?? _tabController.index == 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                original == null
                    ? AppStrings.addCategory
                    : AppStrings.editCategory,
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: AppStrings.categoryName,
                        hintText: AppStrings.categoryNameHint,
                      ),
                    ),
                    if (effectiveParentKey == null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        AppStrings.categoryType,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text(AppStrings.expenseCategory),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(AppStrings.incomeCategory),
                          ),
                        ],
                        selected: {isExpense},
                        onSelectionChanged: (value) {
                          setState(() => isExpense = value.first);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.categoryIcon,
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
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.categoryNameRequired),
                        ),
                      );
                      return;
                    }
                    final category = Category(
                      key: original?.key ??
                          'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      icon: selectedIcon,
                      isExpense: isExpense,
                      parentKey: effectiveParentKey,
                    );
                    Navigator.pop(context, category);
                  },
                  child: const Text(AppStrings.save),
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
