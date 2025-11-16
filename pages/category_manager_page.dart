import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remark_money/models/category.dart';
import 'package:remark_money/providers/category_provider.dart';
import 'package:remark_money/repository/category_repository.dart';

class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({super.key});

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<CategoryManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<IconData> _iconOptions = [
    Icons.fastfood_outlined,
    Icons.shopping_bag_outlined,
    Icons.directions_bus_outlined,
    Icons.home_outlined,
    Icons.spa_outlined,
    Icons.pets_outlined,
    Icons.school_outlined,
    Icons.work_outline,
    Icons.trending_up,
    Icons.attach_money,
    Icons.card_giftcard,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final expenses =
        provider.categories.where((element) => element.isExpense).toList();
    final incomes =
        provider.categories.where((element) => !element.isExpense).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("分类管理"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "支出"),
            Tab(text: "收入"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(expenses),
          _buildList(incomes),
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
          "暂无分类，点击右下角新增。",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (_, index) {
        final category = categories[index];
        final deletable = !_isDefaultCategory(category.key);
        return ListTile(
          leading: CircleAvatar(
            child: Icon(category.icon),
          ),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: categories.length,
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
          title: const Text("删除分类"),
          content: Text("确定要删除「${category.name}」吗？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("删除"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (ok == true) {
      await context.read<CategoryProvider>().deleteCategory(category.key);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await showDialog<Category>(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController();
        IconData selectedIcon = _iconOptions.first;
        bool isExpense = _tabController.index == 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("新增分类"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "名称",
                        hintText: "例如：奶茶",
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "类型",
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text("支出")),
                        ButtonSegment(value: false, label: Text("收入")),
                      ],
                      selected: {isExpense},
                      onSelectionChanged: (value) {
                        setState(() => isExpense = value.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "图标",
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                  child: const Text("取消"),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("请填写分类名称")),
                      );
                      return;
                    }
                    final category = Category(
                      key: "custom_${DateTime.now().millisecondsSinceEpoch}",
                      name: name,
                      icon: selectedIcon,
                      isExpense: isExpense,
                    );
                    Navigator.pop(context, category);
                  },
                  child: const Text("保存"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await context.read<CategoryProvider>().addCategory(result);
    }
  }

  Future<void> _showEditCategoryDialog(Category category) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController(text: category.name);
        IconData selectedIcon = category.icon;
        bool isExpense = category.isExpense;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("编辑分类"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "名称",
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "类型",
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text("支出")),
                        ButtonSegment(value: false, label: Text("收入")),
                      ],
                      selected: {isExpense},
                      onSelectionChanged: (value) {
                        setState(() => isExpense = value.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "图标",
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                  child: const Text("取消"),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("请填写分类名称")),
                      );
                      return;
                    }
                    final updated = Category(
                      key: category.key,
                      name: name,
                      icon: selectedIcon,
                      isExpense: isExpense,
                    );
                    Navigator.pop(context, updated);
                  },
                  child: const Text("保存"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await context.read<CategoryProvider>().updateCategory(result);
    }
  }
}
