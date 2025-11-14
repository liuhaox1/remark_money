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
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
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
                  title: const Text('指尖记账 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/finger-accounting'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, ThemeProvider provider) {
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
            DropdownButton<ThemeMode>(
              value: provider.mode,
              onChanged: (mode) {
                if (mode != null) {
                  provider.setMode(mode);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('浅色'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('深色'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('跟随系统'),
                ),
              ],
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
                secondary: provider.books.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, book.id),
                      )
                    : null,
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
