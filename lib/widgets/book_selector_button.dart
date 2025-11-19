import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/book_provider.dart';
import '../providers/record_provider.dart';

class BookSelectorButton extends StatelessWidget {
  const BookSelectorButton({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bookProvider = context.watch<BookProvider>();
    final activeName = bookProvider.activeBook?.name ?? '默认账本';

    return InkWell(
      onTap: () => _showBookPicker(context),
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? cs.surface : Colors.white,
          border: Border.all(color: cs.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: compact ? 16 : 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activeName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: compact ? 14 : 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final recordProvider = ctx.read<RecordProvider>();
        final bp = ctx.watch<BookProvider>();
        final books = bp.books;
        final activeId = bp.activeBookId;
        final activeName = bp.activeBook?.name ?? '默认账本';
        final now = DateTime.now();
        final month = DateTime(now.year, now.month, 1);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '选择账本',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前：$activeName',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '新建账本',
                      onPressed: () => _showAddBookDialog(ctx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...books.map(
                  (book) {
                    final selected = book.id == activeId;
                    final recordCount =
                        recordProvider.recordsForBook(book.id).length;
                    final monthExpense =
                        recordProvider.monthExpense(month, book.id);
                    final subtitle = recordCount > 0
                        ? '本月支出 ${monthExpense.toStringAsFixed(2)} · 共 $recordCount 笔'
                        : '本月暂无记账';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: selected
                            ? cs.primary.withOpacity(0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: RadioListTile<String>(
                          value: book.id,
                          groupValue: activeId,
                          onChanged: (value) async {
                            if (value != null) {
                              await bp.selectBook(value);
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                          title: Text(book.name),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                            ),
                          ),
                          secondary: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: '重命名账本',
                                onPressed: () => _showRenameBookDialog(
                                    ctx, book.id, book.name),
                              ),
                              if (books.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  tooltip: '删除账本',
                                  onPressed: () =>
                                      _confirmDeleteBook(ctx, book.id),
                                ),
                            ],
                          ),
                          activeColor: cs.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .addBook(controller.text.trim());
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('保存'),
          ),
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
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .renameBook(id, controller.text.trim());
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBook(
    BuildContext context,
    String id,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('删除账本'),
        content: const Text('删除后不可恢复，确认删除该账本吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await context.read<BookProvider>().deleteBook(id);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
