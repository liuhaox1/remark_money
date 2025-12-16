import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_tab_top_bar.dart';
import '../utils/validators.dart';
import '../utils/error_handler.dart';

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
  void initState() {
    super.initState();
    // 进入页面时强制重新加载分类，确保迁移逻辑执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().reload();
    });
  }

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppTabTopBar(
        title: AppStrings.categoryManager,
        tabBar: TabBar(
          controller: _tabController,
          labelColor: cs.onSurface,
          unselectedLabelColor: cs.onSurface.withOpacity(0.6),
          indicatorColor: cs.primary,
          labelStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
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
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return Center(
        child: Text(
          AppStrings.emptyCategoryHint,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.65),
          ),
        ),
      );
    }

    // 一级分类：parentKey 为空
    final topCategories = categories.where((c) => c.parentKey == null).toList();

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontFamily: _getSystemChineseFont(),
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 20, color: cs.onSurface.withOpacity(0.7)),
                    onPressed: () => _showEditCategoryDialog(top),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: cs.onSurface.withOpacity(0.7)),
                    onPressed: () => _confirmDelete(top),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65),
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
                icon: Icon(Icons.add, size: 18, color: cs.primary),
                label: Text(
                  '添加子分类',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: cs.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChildCategoryItem(Category category) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            category.icon,
            size: 20,
            color: cs.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontFamily: _getSystemChineseFont(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: cs.onSurface.withOpacity(0.7)),
            onPressed: () => _showEditCategoryDialog(category),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: cs.onSurface.withOpacity(0.7)),
            onPressed: () => _confirmDelete(category),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSubCategoryDialog(Category parent) async {
    try {
      final created = await _showCategoryDialog(
        parentKey: parent.key,
        initialIsExpense: parent.isExpense,
      );
      if (created != null && mounted) {
        await context.read<CategoryProvider>().addCategory(created);
        if (mounted) {
          setState(() => _expandedTopKeys.add(parent.key));
          ErrorHandler.showSuccess(context, '分类已添加');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text(
            AppStrings.deleteCategory,
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
          ),
          content: Text(
            AppStrings.deleteCategoryConfirm(category.name),
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppStrings.cancel,
                style: tt.labelLarge?.copyWith(color: cs.onSurface),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.delete),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) {
      try {
        await context.read<CategoryProvider>().deleteCategory(category.key);
        if (mounted) {
          ErrorHandler.showSuccess(context, '分类已删除');
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handleAsyncError(context, e);
        }
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    try {
      final result = await _showCategoryDialog();
      if (result != null && mounted) {
        await context.read<CategoryProvider>().addCategory(result);
        if (mounted) {
          ErrorHandler.showSuccess(context, '分类已添加');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _showEditCategoryDialog(Category original) async {
    try {
      final updated = await _showCategoryDialog(original: original);
      if (updated != null && mounted) {
        await context.read<CategoryProvider>().updateCategory(updated);
        if (mounted) {
          ErrorHandler.showSuccess(context, '分类已更新');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
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
        final String? effectiveParentKey = original?.parentKey ?? parentKey;
        bool isExpense = original?.isExpense ??
            initialIsExpense ??
            _tabController.index == 0;

        return StatefulBuilder(
          builder: (context, setState) {
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;
            return AlertDialog(
              title: Text(
                original == null
                    ? AppStrings.addCategory
                    : AppStrings.editCategory,
                style: tt.titleMedium?.copyWith(color: cs.onSurface),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: AppStrings.categoryName,
                        labelStyle: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.78),
                        ),
                        hintText: AppStrings.categoryNameHint,
                        hintStyle: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.78),
                        ),
                      ),
                    ),
                    if (effectiveParentKey == null) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.categoryType,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<bool>(
                        segments: [
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
                    Text(
                      AppStrings.categoryIcon,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
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
                  child: Text(
                    AppStrings.cancel,
                    style: tt.labelLarge?.copyWith(color: cs.onSurface),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      final name = nameCtrl.text.trim();
                      final nameError = Validators.validateCategoryName(name);
                      if (nameError != null) {
                        ErrorHandler.showError(context, nameError);
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
                    } catch (e) {
                      ErrorHandler.handleAsyncError(context, e);
                    }
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

  /// 获取系统默认中文字体
  /// 返回 null 表示使用系统默认字体，避免 Noto Sans SC 对某些字符（如"门"）的渲染问题
  String? _getSystemChineseFont() {
    // 返回 null 让 Flutter 使用系统默认字体
    // 在 Windows 上通常是 Microsoft YaHei（微软雅黑）
    // 在 macOS 上通常是 PingFang SC（苹方）
    // 在 Android 上通常是 Roboto 或系统默认中文字体
    return null;
  }
}
