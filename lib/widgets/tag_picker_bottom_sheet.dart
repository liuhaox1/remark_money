import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tag.dart';
import '../providers/book_provider.dart';
import '../providers/tag_provider.dart';

class TagPickerBottomSheet extends StatefulWidget {
  const TagPickerBottomSheet({
    super.key,
    required this.initialSelectedIds,
    required this.onChanged,
  });

  final Set<String> initialSelectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<TagPickerBottomSheet> createState() => _TagPickerBottomSheetState();
}

class _TagPickerBottomSheetState extends State<TagPickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged(_selected);
    });
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tagProvider = context.watch<TagProvider>();
    final bookId = context.watch<BookProvider>().activeBookId;

    final allTags = tagProvider.tags;
    final list = tagProvider.search(_query);

    final q = _query.trim();
    final hasExact = q.isNotEmpty &&
        allTags.any((t) => t.bookId == bookId && t.name.toLowerCase() == q.toLowerCase());

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      '标签',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildSelectedPreview(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: '搜索或创建标签',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (q.isNotEmpty && !hasExact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final created = await context.read<TagProvider>().createTag(
                              bookId: bookId,
                              name: q,
                            );
                        setState(() => _selected.add(created.id));
                        widget.onChanged(_selected);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text('创建“$q”'),
                    ),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor.withOpacity(0.12),
                        ),
                        itemBuilder: (_, idx) {
                          final tag = list[idx];
                          final checked = _selected.contains(tag.id);
                          final dot = tag.colorValue == null
                              ? cs.primary
                              : Color(tag.colorValue!);
                          return ListTile(
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(tag.name),
                            trailing: checked
                                ? Icon(Icons.check_rounded, color: cs.primary)
                                : const SizedBox(width: 24),
                            onTap: () {
                              setState(() {
                                if (checked) {
                                  _selected.remove(tag.id);
                                } else {
                                  _selected.add(tag.id);
                                }
                              });
                              widget.onChanged(_selected);
                            },
                            onLongPress: () => _openTagActions(context, tag),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tags = context.watch<TagProvider>().tags;
    final selected = _selected
        .map((id) => tags.where((t) => t.id == id).toList())
        .expand((x) => x)
        .toList();

    if (selected.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined,
                size: 18, color: cs.onSurface.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text(
              '未选择标签',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.65),
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: -6,
        children: [
          for (final tag in selected)
            InputChip(
              label: Text(tag.name),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: cs.outlineVariant),
              backgroundColor: tag.colorValue == null
                  ? cs.surfaceContainerHighest.withOpacity(0.35)
                  : Color(tag.colorValue!).withOpacity(0.14),
              onDeleted: () {
                setState(() => _selected.remove(tag.id));
                widget.onChanged(_selected);
              },
              deleteIconColor: cs.onSurface.withOpacity(0.6),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim();
    final text = q.isEmpty ? '还没有标签' : '没有匹配的标签';
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.65),
            ),
      ),
    );
  }

  Future<void> _openTagActions(BuildContext context, Tag tag) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('重命名'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _promptRename(tag);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('删除', style: TextStyle(color: cs.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<TagProvider>().deleteTag(tag);
                  setState(() => _selected.remove(tag.id));
                  widget.onChanged(_selected);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptRename(Tag tag) async {
    final ctrl = TextEditingController(text: tag.name);
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('重命名标签'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入标签名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
              onPressed: () async {
                final name = ctrl.text.trim();
                Navigator.pop(ctx);
                await context.read<TagProvider>().renameTag(tag, name);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
  }
}

