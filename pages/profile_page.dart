import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/book_provider.dart';
import '../providers/theme_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          '我的',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBookSection(context, bookProvider),
              const SizedBox(height: 24),
              _buildThemeSection(context, themeProvider),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('分类管理'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/category-manager'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: const Text('指尖记账 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/finger-accounting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, ThemeProvider provider) {
    const seedOptions = <Color>[
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
    ];

    final currentMode =
        provider.mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主题',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                ),
              ],
              selected: {currentMode},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                provider.setMode(value.first);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '主题色',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: seedOptions.map((color) {
                final selected = provider.seedColor.value == color.value;
                return GestureDetector(
                  onTap: () => provider.setSeedColor(color),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.white,
                        width: selected ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSection(BuildContext context, BookProvider provider) {
    if (provider.books.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '账本',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '新增账本',
                  onPressed: () => _showAddBookDialog(context),
                  icon: const Icon(Icons.add),
                )
              ],
            ),
            const SizedBox(height: 12),
            ...provider.books.map(
              (book) => RadioListTile<String>(
                value: book.id,
                groupValue: provider.activeBookId,
                onChanged: (value) {
                  if (value != null) {
                    provider.selectBook(value);
                  }
                },
                title: Text(book.name),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showRenameBookDialog(
                        context,
                        book.id,
                        book.name,
                      ),
                    ),
                    if (provider.books.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, book.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建账本'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '账本名称'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .addBook(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          )
        ],
      ),
    );
  }

  Future<void> _showRenameBookDialog(
    BuildContext context,
    String id,
    String initialName,
  ) async {
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名账本'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '账本名称'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .renameBook(id, controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          )
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final provider = context.read<BookProvider>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除账本'),
        content: const Text('删除后不可恢复，确认删除该账本吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteBook(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
