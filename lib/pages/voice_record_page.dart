import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../repository/category_repository.dart';
import '../services/speech_service.dart';
import '../services/voice_record_parser.dart';
import '../utils/error_handler.dart';

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
  List<ParsedRecordItem> _items = const [];

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
    final hasPermission = await _speechService.checkPermission();
    if (!hasPermission) {
      final granted = await _speechService.requestPermission();
      if (!granted && mounted) {
        setState(() {
          _statusText = '需要麦克风权限才能使用语音记账';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isSaving) return;

    final hasPermission = await _speechService.checkPermission();
    if (!hasPermission) {
      final granted = await _speechService.requestPermission();
      if (!granted) {
        if (mounted) {
          ErrorHandler.showError(context, '需要麦克风权限才能使用语音记账');
        }
        return;
      }
    }

    setState(() {
      _isListening = true;
      _items = const [];
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

    final parsed = VoiceRecordParser.parseMany(text);
    if (!mounted) return;
    if (parsed.isEmpty) {
      setState(() {
        _items = const [];
        _statusText = '未识别到金额，请尝试包含金额（如：吃饭30）';
      });
      ErrorHandler.showWarning(context, '未识别到金额');
      return;
    }

    setState(() {
      _items = parsed;
      _statusText = '解析完成：共 ${parsed.length} 条';
    });
  }

  void _clearAll() {
    if (_isSaving) return;
    setState(() {
      _inputCtrl.text = '';
      _items = const [];
      _statusText = '先说一句话（可多句），识别成文字后点击“发送”解析';
    });
  }

  void _removeItem(int index) {
    setState(() {
      final next = [..._items]..removeAt(index);
      _items = next;
      _statusText = next.isEmpty ? '没有可保存的记录' : '解析完成：共 ${next.length} 条';
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
    if (_items.isEmpty) {
      ErrorHandler.showWarning(context, '请先点击“发送”解析');
      return;
    }

    setState(() => _isSaving = true);

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final categories = categoryProvider.categories;
    final bookId = bookProvider.activeBookId;

    try {
      final fallbackAccount = await accountProvider.ensureDefaultWallet(bookId: bookId);

      var saved = 0;
      for (final item in _items) {
        final matched = item.categoryHint.trim().isEmpty
            ? null
            : VoiceRecordParser.matchCategory(item.categoryHint, categories);
        final categoryKey = _resolveCategory(item, categories).key;

        final remarkBase = item.remark.trim();
        final remark = remarkBase.isEmpty
            ? (matched?.name ?? item.categoryHint).trim().isEmpty
                ? '语音记账'
                : (matched?.name ?? item.categoryHint)
            : remarkBase;

        await recordProvider.addRecord(
          amount: item.amount,
          remark: remark,
          date: item.date,
          categoryKey: categoryKey,
          bookId: bookId,
          accountId: fallbackAccount.id,
          direction: item.isExpense ? TransactionDirection.out : TransactionDirection.income,
          includeInStats: true,
          accountProvider: accountProvider,
        );

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
                  if (_items.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '预览（${_items.length} 条）',
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
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final resolvedCategory = _resolveCategory(item, categories);
                          final matched = item.categoryHint.trim().isEmpty
                              ? null
                              : VoiceRecordParser.matchCategory(
                                  item.categoryHint,
                                  categories,
                                );
                          final title = (matched?.name ?? item.categoryHint).trim().isEmpty
                              ? (item.isExpense ? '支出' : '收入')
                              : (matched?.name ?? item.categoryHint);

                          final remark = item.remark.trim().isEmpty ? title : item.remark;
                          final dateStr =
                              '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
                          final amountColor = item.isExpense ? cs.error : cs.tertiary;

                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
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
                      child: Text('保存 ${_items.length} 条'),
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
