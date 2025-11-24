import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/records_export_bundle.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
          AppStrings.profile,
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
              _buildDataSection(context),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text(AppStrings.budget),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/budget'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text(AppStrings.categoryManager),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/category-manager'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: const Text(AppStrings.version),
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
              AppStrings.theme,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(AppStrings.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(AppStrings.themeDark),
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
              AppStrings.themeSeed,
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
                  AppStrings.book,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: AppStrings.addBook,
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

  Widget _buildDataSection(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('导入记录（JSON 备份）'),
            subtitle: const Text('从指尖记账导出的 JSON 备份文件导入记账记录'),
            onTap: () => _importRecords(context),
          ),
        ],
      ),
    );
  }

  Future<void> _importRecords(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final file = File(path);
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      final bundle = RecordsExportBundle.fromMap(map);
      if (bundle.type != 'records') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件格式不正确，无法导入')),
          );
        }
        return;
      }

      final imported = bundle.records;
      if (imported.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份中没有任何记录')),
          );
        }
        return;
      }

      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final bookProvider = context.read<BookProvider>();

      // Ensure related providers are loaded so that subsequent views work.
      await Future.wait([
        if (!recordProvider.loaded) recordProvider.load(),
        if (!accountProvider.loaded) accountProvider.load(),
        if (!categoryProvider.loaded) categoryProvider.load(),
        if (!bookProvider.loaded) bookProvider.load(),
      ]);

      final count = await recordProvider.importRecords(imported);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 $count 条记录')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败，请检查文件是否为指尖记账备份')),
        );
      }
    }
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.newBook),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: AppStrings.bookNameHint),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppStrings.bookNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .addBook(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.save),
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
        title: const Text(AppStrings.renameBook),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: AppStrings.bookNameHint),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppStrings.bookNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .renameBook(id, controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.save),
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
        title: const Text(AppStrings.deleteBook),
        content: const Text(AppStrings.confirmDeleteBook),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deleteBook(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
