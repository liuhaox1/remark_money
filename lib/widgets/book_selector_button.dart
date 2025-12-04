import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/book_provider.dart';
import '../providers/record_provider.dart';
import '../utils/error_handler.dart';

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
    final activeName =
        bookProvider.activeBook?.name ?? AppStrings.defaultBook;

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
            Icon(
              Icons.menu_book_outlined,
              size: compact ? 16 : 18,
              color: cs.primary,
            ),
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
        final activeName =
            bp.activeBook?.name ?? AppStrings.defaultBook;
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
                            AppStrings.selectBook,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.currentBookLabel(activeName),
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
                      tooltip: AppStrings.addBook,
                      onPressed: () => _showAddBookDialog(ctx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: AppStrings.close,
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
                        ? AppStrings.monthExpenseWithCount(
                            monthExpense,
                            recordCount,
                          )
                        : AppStrings.noDataThisMonth;
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
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                ),
                                tooltip: AppStrings.renameBook,
                                onPressed: () => _showRenameBookDialog(
                                  ctx,
                                  book.id,
                                  book.name,
                                ),
                              ),
                              if (books.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: AppStrings.deleteBook,
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .addBook(controller.text.trim());
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text(AppStrings.save),
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              await context
                  .read<BookProvider>()
                  .renameBook(id, controller.text.trim());
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text(AppStrings.save),
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
        title: const Text(AppStrings.deleteBook),
        content: const Text(AppStrings.confirmDeleteBook),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<BookProvider>().deleteBook(id);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ErrorHandler.showSuccess(context, '账本已删除');
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ErrorHandler.handleAsyncError(context, e);
                }
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
