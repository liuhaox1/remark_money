import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../l10n/profile_strings_local.dart';
import '../models/import_result.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/data_export_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final reminderProvider = context.watch<ReminderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              const Text(
                ProfileStringsLocal.settings,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ProfileStringsLocal.profileIntro,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              _buildBookSection(context, bookProvider),
              const SizedBox(height: 16),
              _buildThemeSection(context, themeProvider),
              const SizedBox(height: 16),
              _buildBudgetCategorySection(context),
              const SizedBox(height: 16),
              _buildDataSecuritySection(context),
              const SizedBox(height: 16),
              _buildDangerSection(context),
              const SizedBox(height: 16),
              _buildHelpAboutSection(context),
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
              spacing: 12,
              children: seedOptions.map((color) {
                final selected = provider.seedColor.value == color.value;
                return GestureDetector(
                  onTap: () => provider.setSeedColor(color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: selected 
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.grey.withOpacity(0.3),
                        width: selected ? 3 : 2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
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
                const Icon(Icons.menu_book_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  AppStrings.book,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddBookDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    AppStrings.addBook,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.books.length == 1)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(provider.books.first.name),
                subtitle: const Text(ProfileStringsLocal.currentBookSingleHint),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: AppStrings.renameBook,
                      onPressed: () => _showRenameBookDialog(
                        context,
                        provider.books.first.id,
                        provider.books.first.name,
                      ),
                    ),
                  ],
                ),
              )
            else
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
                        tooltip: AppStrings.renameBook,
                        onPressed: () => _showRenameBookDialog(
                          context,
                          book.id,
                          book.name,
                        ),
                      ),
                      if (provider.books.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: AppStrings.deleteBook,
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

  Widget _buildLegacyDataSecuritySection(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.ios_share_outlined),
            title: Text('数据导入/导出'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导入数据'),
            subtitle: const Text('从 CSV 文件导入记账记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importCsv(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('导出数据'),
            subtitle: const Text('导出当前账本的全部记账记录（CSV）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExportSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSecuritySection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('数据与安全'),
        subtitle: const Text('导入导出、备份与恢复'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showDataSecuritySheet(context, cs),
      ),
    );
  }

  Widget _buildDangerSection(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined, color: Colors.red),
            title: Text(
              '危险操作',
              style: TextStyle(color: Colors.red),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text(
              '清空全部数据',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('清除本地存储的账本、记录、账户等数据（不可恢复）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmClearAll(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCategorySection(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('预算与分类'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.trending_down_outlined),
            title: const Text(AppStrings.budget),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/budget'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text(AppStrings.categoryManager),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/category-manager'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitSection(
    BuildContext context,
    ReminderProvider reminderProvider,
  ) {
    final time = reminderProvider.timeOfDay;
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.alarm_outlined),
            title: Text('记账习惯与提醒'),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: reminderProvider.enabled,
            title: const Text('开启每天记账提醒'),
            subtitle: Text('每天固定时间提醒你打开「指尖记账」，坚持好习惯'),
            onChanged: (v) => reminderProvider.setEnabled(v),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('提醒时间'),
            subtitle: Text(timeLabel),
            onTap: () => _pickReminderTime(context, reminderProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpAboutSectionLegacy(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppStrings.version),
            subtitle: Text('指尖记账'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDataSecuritySheet(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入 CSV 数据'),
                subtitle: const Text('从 CSV 文件导入记账记录'),
                onTap: () {
                  Navigator.pop(ctx);
                  _importCsv(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('导出 CSV 数据'),
                subtitle: const Text('导出当前账本的全部记账记录'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showExportSheet(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.cloud_download_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('导出 JSON 备份'),
                subtitle: const Text('完整备份当前账本记录，用于迁移或恢复'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAllJson(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.cloud_upload_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('导入 JSON 备份'),
                subtitle: const Text('从之前导出的备份包中恢复记录'),
                onTap: () {
                  Navigator.pop(ctx);
                  _importRecords(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('导出为 CSV'),
                subtitle: const Text('适合在 Excel / 表格中查看'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAllCsv(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAllCsv(BuildContext context) async {
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();

    final bookId = bookProvider.activeBookId;
    final records = recordProvider.recordsForBook(bookId);
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前账本暂无记录')),
        );
      }
      return;
    }

    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };
    final bookMap = {
      for (final b in bookProvider.books) b.id: b,
    };
    final accountMap = {
      for (final a in accountProvider.accounts) a.id: a,
    };

    final csv = buildCsvForRecords(
      records,
      categoriesByKey: categoryMap,
      booksById: bookMap,
      accountsById: accountMap,
    );

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final safeBookId = bookId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final fileName = 'remark_records_all_${safeBookId}_$dateStr.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv, encoding: utf8);

    if (!context.mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '指尖记账导出 CSV',
      text: '指尖记账导出的全部记录 CSV，可在表格中查看分析。',
    );
  }

  Future<void> _exportAllJson(BuildContext context) async {
    final recordProvider = context.read<RecordProvider>();
    final bookProvider = context.read<BookProvider>();

    final bookId = bookProvider.activeBookId;
    final records = recordProvider.recordsForBook(bookId);
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前账本暂无记录')),
        );
      }
      return;
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    final start = records.first.date;
    final end = records.last.date;
    final jsonText = buildJsonPackageForRecords(
      records: records,
      bookId: bookId,
      start: start,
      end: end,
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'remark_records_all_${bookId}_${DateTime.now().toIso8601String()}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonText, encoding: utf8);

    if (!context.mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '指尖记账导出 JSON 数据包',
      text: '指尖记账导出的 JSON 备份，可用于导入或迁移。',
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
      final bundle = parseRecordsJsonPackage(content);

      final imported = bundle.records;
      if (imported.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份中没有任何记录')),
          );
        }
        return;
      }

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('导入记录'),
              content: Text('将导入约 ${imported.length} 条记录，可能会与当前数据合并。是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(AppStrings.ok),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final bookProvider = context.read<BookProvider>();

      await Future.wait([
        if (!recordProvider.loaded) recordProvider.load(),
        if (!accountProvider.loaded) accountProvider.load(),
        if (!categoryProvider.loaded) categoryProvider.load(),
        if (!bookProvider.loaded) bookProvider.load(),
      ]);

      final ImportResult summary = await recordProvider.importRecords(
        imported,
        activeBookId: bookProvider.activeBookId,
        accountProvider: accountProvider,
      );

      if (context.mounted) {
        final text =
            '导入完成：成功 ${summary.successCount} 条，失败 ${summary.failureCount} 条';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件格式不正确，无法导入')),
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

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final file = File(path);
      final content = await file.readAsString(encoding: utf8);

      final recordProvider = context.read<RecordProvider>();
      final accountProvider = context.read<AccountProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final bookProvider = context.read<BookProvider>();

      await Future.wait([
        if (!recordProvider.loaded) recordProvider.load(),
        if (!accountProvider.loaded) accountProvider.load(),
        if (!categoryProvider.loaded) categoryProvider.load(),
        if (!bookProvider.loaded) bookProvider.load(),
      ]);

      // 构建查找映射
      final categoriesByName = {
        for (final c in categoryProvider.categories) c.name: c,
      };
      final booksByName = {
        for (final b in bookProvider.books) b.name: b,
      };
      final accountsByName = {
        for (final a in accountProvider.accounts) a.name: a,
      };

      // 获取默认值
      final defaultBookId = bookProvider.activeBookId;
      final defaultAccount = accountProvider.accounts.firstWhere(
        (a) => a.name == '现金',
        orElse: () => accountProvider.accounts.first,
      );
      final defaultAccountId = defaultAccount.id;
      final defaultCategory = categoryProvider.categories.firstWhere(
        (c) => !c.isExpense,
        orElse: () => categoryProvider.categories.first,
      );
      final defaultCategoryKey = defaultCategory.key;

      // 解析CSV
      final imported = parseCsvToRecords(
        content,
        categoriesByName: categoriesByName,
        booksByName: booksByName,
        accountsByName: accountsByName,
        defaultBookId: defaultBookId,
        defaultAccountId: defaultAccountId,
        defaultCategoryKey: defaultCategoryKey,
      );

      if (imported.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV文件中没有有效的记录')),
          );
        }
        return;
      }

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('导入记录'),
              content: Text('将导入约 ${imported.length} 条记录，可能会与当前数据合并。是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(AppStrings.ok),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final ImportResult summary = await recordProvider.importRecords(
        imported,
        activeBookId: defaultBookId,
        accountProvider: accountProvider,
      );

      if (context.mounted) {
        final text =
            '导入完成：成功 ${summary.successCount} 条，失败 ${summary.failureCount} 条';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV文件格式不正确：${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    ReminderProvider provider,
  ) async {
    final current = provider.timeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) {
      await provider.setTime(picked);
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            title: const Text(
              '清空全部数据',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '此操作将永久删除：',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('• 所有账本'),
                Text('• 所有记账记录'),
                Text('• 所有账户信息'),
                Text('• 所有分类设置'),
                SizedBox(height: 12),
                Text(
                  '⚠️ 此操作不可撤销，请谨慎操作！',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(AppStrings.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 简单提示用户重启应用以重新加载默认数据。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已清空，重新打开应用后将生效')),
      );
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
            decoration:
                const InputDecoration(hintText: AppStrings.bookNameHint),
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
            decoration:
                const InputDecoration(hintText: AppStrings.bookNameHint),
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

  Widget _buildHelpAboutSection(BuildContext context) {
    return const Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('帮助与关于'),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppStrings.version),
            subtitle: Text('指尖记账'),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('该功能将在后续版本中完善，敬请期待。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }
}
