import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/tag_provider.dart';
import '../repository/category_repository.dart';
import '../services/speech_service.dart';
import '../services/voice_category_alias_service.dart';
import '../services/voice_record_parser.dart';
import '../services/sync_engine.dart';
import '../utils/error_handler.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../widgets/number_pad_sheet.dart';
import '../widgets/tag_picker_bottom_sheet.dart';

/// 语音记账页
///
/// 流程：
/// 1) 先说话，语音转文字（可编辑）
/// 2) 点击“发送”后解析文本（支持多条）
/// 3) 预览无误后批量保存
class VoiceRecordPage extends StatefulWidget {
  const VoiceRecordPage({super.key});

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage> {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _inputCtrl = TextEditingController();

  bool _isListening = false;
  bool _isSaving = false;
  String _statusText = '先说一句话（可多句），识别成文字后点击“发送”解析';
  String? _initError;
  List<_VoiceDraftItem> _drafts = const [];
  bool _ensuringMeta = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _speechService.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    final initialized = await _speechService.initialize();
    if (!initialized && mounted) {
      setState(() {
        _initError = _speechService.lastError ?? '需要麦克风权限才能使用语音记账';
        _statusText = _initError!;
      });
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isSaving) return;

    final hasPermission = await _speechService.checkPermission();
    if (!hasPermission) {
      final initialized = await _speechService.initialize();
      if (!initialized) {
        if (mounted) {
          ErrorHandler.showError(
            context,
            _speechService.lastError ?? '需要麦克风权限才能使用语音记账',
          );
        }
        return;
      }
    }

    setState(() {
      _isListening = true;
      _drafts = const [];
      _statusText = '正在聆听…';
      _inputCtrl.text = '';
    });

    await _speechService.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _inputCtrl.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _statusText = '识别出错：$error';
        });
        ErrorHandler.showError(context, error);
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          if (_inputCtrl.text.trim().isEmpty) {
            _statusText = '未识别到内容，请重试';
          } else {
            _statusText = '识别完成，可编辑后点击“发送”解析';
          }
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusText = '识别已停止，可编辑后点击“发送”解析';
    });
  }

  Future<void> _parseText() async {
    if (_isSaving) return;
    if (_isListening) {
      await _stopListening();
      if (!mounted) return;
    }

    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      ErrorHandler.showWarning(context, '请先说一句话或输入文本');
      return;
    }

    final bookId = context.read<BookProvider>().activeBookId;
    final ready = await _ensureMetaReadyForBook(bookId);
    if (!ready || !mounted) return;

    final parsed = VoiceRecordParser.parseMany(text);
    if (!mounted) return;
    if (parsed.isEmpty) {
      setState(() {
        _drafts = const [];
        _statusText = '未识别到金额，请尝试包含金额（如：吃饭30）';
      });
      ErrorHandler.showWarning(context, '未识别到金额');
      return;
    }

    final categoryProvider = context.read<CategoryProvider>();
    final categories = categoryProvider.categories;
    final accountProvider = context.read<AccountProvider>();
    final aliases = await VoiceCategoryAliasService.instance.loadAliases(bookId);

    final fallbackAccount = await accountProvider.ensureDefaultWallet(bookId: bookId);
    final drafts = parsed.map((item) {
      final normalizedHint = VoiceCategoryAliasService.instance.normalizePhrase(item.categoryHint);
      final aliasedKey = normalizedHint.isEmpty ? null : aliases[normalizedHint];
      final categoryKey = aliasedKey != null
          ? aliasedKey
          : _resolveCategory(item, categories).key;
      final remarkBase = item.remark.trim();
      final remark = remarkBase.isEmpty
          ? item.categoryHint.trim().isEmpty
              ? '语音记账'
              : item.categoryHint.trim()
          : remarkBase;
      return _VoiceDraftItem(
        amount: item.amount,
        isExpense: item.isExpense,
        remark: remark,
        categoryKey: categoryKey,
        date: item.date,
        accountId: fallbackAccount.id,
        tagIds: const {},
        categoryHint: item.categoryHint,
      );
    }).toList(growable: false);

    setState(() {
      _drafts = drafts;
      _statusText = '解析完成：共 ${drafts.length} 条（点一条可编辑）';
    });

    if (drafts.length == 1 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _drafts.isEmpty) return;
        _editDraft(0);
      });
    }
  }

  Future<bool> _ensureMetaReadyForBook(String bookId) async {
    if (_ensuringMeta) return false;
    if (int.tryParse(bookId) == null) return true;

    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();
    final needs =
        categoryProvider.categories.isEmpty ||
        accountProvider.accounts.where((a) => a.bookId == bookId).isEmpty;
    if (!needs) return true;

    _ensuringMeta = true;
    try {
      await _runBlockingMetaSync('正在同步账本数据...', () async {
        final ok = await SyncEngine().ensureMetaReady(
          context,
          bookId,
          requireCategories: true,
          requireAccounts: true,
          requireTags: false,
          reason: 'meta_ensure',
        );
        if (!ok && mounted) {
          ErrorHandler.showError(context, '同步失败，请稍后重试');
        }
      });
      if (!mounted) return false;
      return true;
    } finally {
      _ensuringMeta = false;
    }
  }

  Future<void> _runBlockingMetaSync(
    String message,
    Future<void> Function() action,
  ) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
    try {
      await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _clearAll() {
    if (_isSaving) return;
    setState(() {
      _inputCtrl.text = '';
      _drafts = const [];
      _statusText = '先说一句话（可多句），识别成文字后点击“发送”解析';
    });
  }

  void _removeItem(int index) {
    setState(() {
      final next = [..._drafts]..removeAt(index);
      _drafts = next;
      _statusText = next.isEmpty ? '没有可保存的记录' : '解析完成：共 ${next.length} 条（点一条可编辑）';
    });
  }

  Category _resolveCategory(ParsedRecordItem item, List<Category> categories) {
    if (categories.isEmpty) {
      return Category(
        key: item.isExpense ? CategoryRepository.uncategorizedExpenseKey : 'top_income_other',
        name: '其他',
        icon: Icons.category_outlined,
        isExpense: item.isExpense,
      );
    }

    final matched = item.categoryHint.trim().isEmpty
        ? null
        : VoiceRecordParser.matchCategory(item.categoryHint, categories);
    if (matched != null) return matched;

    // 无法匹配时优先落到“未分类”，避免误判到“餐饮”等高频分类。
    final fallbackKey =
        item.isExpense ? CategoryRepository.uncategorizedExpenseKey : 'top_income_other';
    return categories.firstWhere(
      (c) => c.key == fallbackKey,
      orElse: () => categories.firstWhere(
        (c) => c.isExpense == item.isExpense,
        orElse: () => categories.first,
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_isSaving) return;
    if (_drafts.isEmpty) {
      ErrorHandler.showWarning(context, '请先点击“发送”解析');
      return;
    }

    setState(() => _isSaving = true);

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final bookProvider = context.read<BookProvider>();
    final tagProvider = context.read<TagProvider>();
    final bookId = bookProvider.activeBookId;

    try {
      var saved = 0;
      for (final draft in _drafts) {
        final created = await recordProvider.addRecord(
          amount: draft.amount,
          remark: draft.remark.trim().isEmpty ? '语音记账' : draft.remark.trim(),
          date: draft.date,
          categoryKey: draft.categoryKey,
          bookId: bookId,
          accountId: draft.accountId,
          direction:
              draft.isExpense ? TransactionDirection.out : TransactionDirection.income,
          includeInStats: true,
          accountProvider: accountProvider,
        );

        if (draft.tagIds.isNotEmpty) {
          await tagProvider.setTagsForRecord(
            created.id,
            draft.tagIds.toList(),
            record: created,
          );
        }

        saved += 1;
      }

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已保存 $saved 条记录');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e, onRetry: _saveAll);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音记账'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _statusText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.75),
                    ),
                  ),
                  if ((_initError ?? '').contains('权限') ||
                      (_initError ?? '').contains('麦克风'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _speechService.openSystemSettings();
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('去系统设置开启权限'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildInputCard(context),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : (_isListening ? _stopListening : _startListening),
                          icon: Icon(_isListening ? Icons.stop : Icons.mic),
                          label: Text(_isListening ? '停止' : '说一句话'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _parseText,
                          icon: const Icon(Icons.send),
                          label: const Text('发送'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: '清空',
                        onPressed: (_isSaving || _isListening) ? null : _clearAll,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_drafts.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '预览（${_drafts.length} 条）',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (_isSaving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _drafts[index];
                          final resolvedCategory = categories.firstWhere(
                            (c) => c.key == item.categoryKey,
                            orElse: () => Category(
                              key: item.categoryKey,
                              name: '其他',
                              icon: Icons.category_outlined,
                              isExpense: item.isExpense,
                            ),
                          );
                          final remark =
                              item.remark.trim().isEmpty ? '语音记账' : item.remark.trim();
                          final dateStr =
                              '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
                          final amountColor = item.isExpense ? cs.error : cs.tertiary;

                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: _isSaving ? null : () => _editDraft(index),
                              leading: Icon(
                                item.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                color: amountColor,
                              ),
                              title: Text(
                                remark,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('$dateStr · ${resolvedCategory.name}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.isExpense ? '-' : '+'}${item.amount.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: amountColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '移除',
                                    onPressed: _isSaving ? null : () => _removeItem(index),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isSaving ? null : _saveAll,
                      child: Text('保存 ${_drafts.length} 条'),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Expanded(child: _buildTips(context)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editDraft(int index) async {
    if (_isSaving) return;
    if (index < 0 || index >= _drafts.length) return;

    final initial = _drafts[index];
    final amountCtrl = TextEditingController(text: initial.amount.toStringAsFixed(2));
    final remarkCtrl = TextEditingController(text: initial.remark);
    var isExpense = initial.isExpense;
    var categoryKey = initial.categoryKey;
    var date = initial.date;
    var accountId = initial.accountId;
    var tagIds = Set<String>.from(initial.tagIds);

    try {
      final result = await showModalBottomSheet<_VoiceDraftItem>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          final tt = Theme.of(ctx).textTheme;
          final categories = ctx.read<CategoryProvider>().categories;
          final accounts = ctx.read<AccountProvider>().accounts;

          String categoryName() {
            final c = categories.firstWhere(
              (c) => c.key == categoryKey,
              orElse: () => Category(
                key: categoryKey,
                name: '请选择分类',
                icon: Icons.category_outlined,
                isExpense: isExpense,
              ),
            );
            return c.name;
          }

          String accountName() {
            final found = accounts.where((a) => a.id == accountId).toList();
            if (found.isNotEmpty) return found.first.name;
            return '默认钱包';
          }

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '编辑确认',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final raw = amountCtrl.text.trim();
                                final normalized = raw.startsWith('.') ? '0$raw' : raw;
                                final amount = double.tryParse(normalized);
                                if (amount == null || amount <= 0) {
                                  ErrorHandler.showWarning(ctx, '请输入正确金额');
                                  return;
                                }
                                if (categoryKey.trim().isEmpty) {
                                  ErrorHandler.showWarning(ctx, '请选择分类');
                                  return;
                                }
                                Navigator.pop(
                                  ctx,
                                  _VoiceDraftItem(
                                    amount: amount,
                                    isExpense: isExpense,
                                    remark: remarkCtrl.text.trim(),
                                    categoryKey: categoryKey,
                                    date: date,
                                    accountId: accountId,
                                    tagIds: tagIds,
                                    categoryHint: initial.categoryHint,
                                  ),
                                );
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              _VoiceEditRow(
                                label: '类型',
                                value: isExpense ? '支出' : '收入',
                                onTap: () => setModalState(() => isExpense = !isExpense),
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              _VoiceEditRow(
                                label: '分类',
                                value: categoryName(),
                                onTap: () async {
                                  final picked = await _pickCategoryKey(
                                    ctx,
                                    isExpense: isExpense,
                                    currentKey: categoryKey,
                                  );
                                  if (picked == null) return;
                                  setModalState(() => categoryKey = picked);
                                },
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              _VoiceEditRow(
                                label: '日期',
                                value: '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: date,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked == null) return;
                                  setModalState(() {
                                    date = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      date.hour,
                                      date.minute,
                                    );
                                  });
                                },
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              _VoiceEditRow(
                                label: '金额',
                                value: amountCtrl.text.trim().isEmpty ? '请输入金额' : amountCtrl.text.trim(),
                                onTap: () async {
                                  await showNumberPadBottomSheet(
                                    ctx,
                                    controller: amountCtrl,
                                    allowDecimal: true,
                                    formatFixed2OnClose: true,
                                  );
                                  setModalState(() {});
                                },
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              _VoiceEditRow(
                                label: '账户',
                                value: accountName(),
                                onTap: () async {
                                  final selectedId = await showAccountSelectBottomSheet(
                                    ctx,
                                    accounts,
                                    selectedAccountId: accountId,
                                  );
                                  if (selectedId == null) return;
                                  setModalState(() => accountId = selectedId);
                                },
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              _VoiceEditRow(
                                label: '标签',
                                value: tagIds.isEmpty ? '未选择标签' : '已选 ${tagIds.length} 个',
                                onTap: () async {
                                  await showModalBottomSheet<void>(
                                    context: ctx,
                                    useRootNavigator: true,
                                    isScrollControlled: true,
                                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                                    builder: (_) => TagPickerBottomSheet(
                                      initialSelectedIds: tagIds,
                                      onChanged: (ids) => setModalState(() => tagIds = ids),
                                    ),
                                  );
                                },
                              ),
                              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.3)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                                child: TextField(
                                  controller: remarkCtrl,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: '备注',
                                    hintText: '选填',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted || result == null) return;
      setState(() {
        final next = [..._drafts];
        next[index] = result;
        _drafts = next;
      });

      final hint = initial.categoryHint.trim();
      if (hint.isNotEmpty && result.categoryKey != initial.categoryKey) {
        final bookId = context.read<BookProvider>().activeBookId;
        await VoiceCategoryAliasService.instance.saveAlias(
          bookId,
          phrase: hint,
          categoryKey: result.categoryKey,
        );
      }
    } finally {
      amountCtrl.dispose();
      remarkCtrl.dispose();
    }
  }

  Future<String?> _pickCategoryKey(
    BuildContext context, {
    required bool isExpense,
    required String currentKey,
  }) async {
    final categories = context
        .read<CategoryProvider>()
        .categories
        .where((c) => c.isExpense == isExpense)
        .toList();
    if (categories.isEmpty) return null;

    final parents = categories.where((c) => c.parentKey == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final byParent = <String, List<Category>>{};
    for (final c in categories) {
      final p = c.parentKey;
      if (p == null) continue;
      byParent.putIfAbsent(p, () => []).add(c);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    String? initialParentKey;
    final current = categories.where((c) => c.key == currentKey).toList();
    if (current.isNotEmpty) {
      initialParentKey = current.first.parentKey ?? current.first.key;
    }
    initialParentKey ??= parents.isEmpty ? null : parents.first.key;

    return await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        var parentKey = initialParentKey;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final leftWidth = 120.0;
            final height = MediaQuery.of(ctx).size.height * 0.72;
            final children = parentKey == null
                ? const <Category>[]
                : (byParent[parentKey!] ?? const <Category>[]);
            return SizedBox(
              height: height,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '选择分类',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: leftWidth,
                          child: ListView.builder(
                            itemCount: parents.length,
                            itemBuilder: (ctx, i) {
                              final p = parents[i];
                              final selected = p.key == parentKey;
                              return InkWell(
                                onTap: () => setModalState(() => parentKey = p.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  color: selected
                                      ? cs.primary.withOpacity(0.12)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Icon(
                                        p.icon,
                                        size: 18,
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurface.withOpacity(0.75),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: selected
                                                ? cs.primary
                                                : cs.onSurface.withOpacity(0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: children.isEmpty
                                ? Center(
                                    child: Text(
                                      '没有二级分类，点击左侧直接选择',
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final c in children)
                                        InkWell(
                                          onTap: () => Navigator.pop(ctx, c.key),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: c.key == currentKey
                                                  ? cs.primary.withOpacity(0.12)
                                                  : cs.surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: c.key == currentKey
                                                    ? cs.primary.withOpacity(0.35)
                                                    : cs.outlineVariant
                                                        .withOpacity(0.35),
                                              ),
                                            ),
                                            child: Text(
                                              c.name,
                                              style: tt.bodyMedium?.copyWith(
                                                color: cs.onSurface,
                                                fontWeight: c.key == currentKey
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _inputCtrl,
        enabled: !_isListening && !_isSaving,
        maxLines: 5,
        minLines: 3,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '例如：我今天吃饭花了30，喝水花50\n也支持：昨天工资5000，买咖啡18\n或：12月17日 买咖啡 18',
        ),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildTips(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const tips = [
      '我今天吃饭花了30，喝水花50',
      '昨天工资5000，买咖啡18',
      '12月17日 买咖啡 18',
      '前天打车花了25',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('使用提示', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: cs.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            '提示：解析结果会先预览，确认无误再保存。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceDraftItem {
  const _VoiceDraftItem({
    required this.amount,
    required this.isExpense,
    required this.remark,
    required this.categoryKey,
    required this.date,
    required this.accountId,
    required this.tagIds,
    required this.categoryHint,
  });

  final double amount;
  final bool isExpense;
  final String remark;
  final String categoryKey;
  final DateTime date;
  final String accountId;
  final Set<String> tagIds;
  final String categoryHint;
}

class _VoiceEditRow extends StatelessWidget {
  const _VoiceEditRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: tt.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: tt.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: value.contains('请选择') || value.contains('请输入')
                      ? cs.onSurface.withOpacity(0.45)
                      : cs.onSurface.withOpacity(0.82),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurface.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }
}
