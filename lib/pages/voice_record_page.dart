import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../services/speech_service.dart';
import '../services/voice_record_parser.dart';
import '../utils/error_handler.dart';
import 'add_record_page.dart';

/// 语音记账页面
class VoiceRecordPage extends StatefulWidget {
  const VoiceRecordPage({super.key});

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage> {
  final SpeechService _speechService = SpeechService();
  String _recognizedText = '';
  String _statusText = '点击按钮开始语音记账';
  bool _isListening = false;
  ParsedRecord? _parsedRecord;
  Category? _matchedCategory;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _speechService.dispose();
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
    if (_isListening) return;

    // 检查权限
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
      _recognizedText = '';
      _statusText = '正在聆听...';
      _parsedRecord = null;
      _matchedCategory = null;
    });

    await _speechService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
            // 实时解析
            _parsedRecord = VoiceRecordParser.parse(text);
            if (_parsedRecord != null && _parsedRecord!.categoryHint.isNotEmpty) {
              final categories = context.read<CategoryProvider>().categories;
              _matchedCategory = VoiceRecordParser.matchCategory(
                _parsedRecord!.categoryHint,
                categories,
              );
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusText = '识别出错: $error';
          });
          // 显示详细错误信息，特别是 Windows 平台的提示
          ErrorHandler.showError(context, error);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            if (_recognizedText.isEmpty) {
              _statusText = '未识别到内容，请重试';
            } else {
              _statusText = '识别完成';
            }
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusText = '识别完成';
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_parsedRecord == null) {
      ErrorHandler.showWarning(context, '请先进行语音识别');
      return;
    }

    final recordProvider = context.read<RecordProvider>();
    final accountProvider = context.read<AccountProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    final fallbackAccount =
        await accountProvider.ensureDefaultWallet(bookId: bookProvider.activeBookId);

    // 使用匹配的分类，如果没有匹配则使用默认分类
    String? categoryKey = _matchedCategory?.key;
    if (categoryKey == null) {
      // 使用默认分类
      final defaultCategory = categoryProvider.categories.firstWhere(
        (c) => c.isExpense == _parsedRecord!.isExpense,
        orElse: () => categoryProvider.categories.first,
      );
      categoryKey = defaultCategory.key;
    }

    try {
      await recordProvider.addRecord(
        amount: _parsedRecord!.amount,
        remark: _parsedRecord!.remark.isEmpty
            ? '语音记账'
            : _parsedRecord!.remark,
        date: DateTime.now(),
        categoryKey: categoryKey,
        bookId: bookProvider.activeBookId,
        accountId: fallbackAccount.id,
        direction: _parsedRecord!.isExpense
            ? TransactionDirection.out
            : TransactionDirection.income,
        includeInStats: true,
        accountProvider: accountProvider,
      );

      if (mounted) {
        ErrorHandler.showSuccess(context, '记账成功');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    }
  }

  Future<void> _editRecord() async {
    if (_parsedRecord == null) {
      ErrorHandler.showWarning(context, '请先进行语音识别');
      return;
    }

    // 跳转到编辑页面，预填充数据
    final accountProvider = context.read<AccountProvider>();
    final bookProvider = context.read<BookProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    final fallbackAccount =
        await accountProvider.ensureDefaultWallet(bookId: bookProvider.activeBookId);

    String? categoryKey = _matchedCategory?.key;
    if (categoryKey == null) {
      final defaultCategory = categoryProvider.categories.firstWhere(
        (c) => c.isExpense == _parsedRecord!.isExpense,
        orElse: () => categoryProvider.categories.first,
      );
      categoryKey = defaultCategory.key;
    }

    // 创建临时记录用于编辑
    final tempRecord = Record(
      id: 'temp_voice_${DateTime.now().millisecondsSinceEpoch}',
      amount: _parsedRecord!.amount,
      remark: _parsedRecord!.remark.isEmpty
          ? '语音记账'
          : _parsedRecord!.remark,
      date: DateTime.now(),
      categoryKey: categoryKey,
      bookId: bookProvider.activeBookId,
      accountId: fallbackAccount.id,
      direction: _parsedRecord!.isExpense
          ? TransactionDirection.out
          : TransactionDirection.income,
      includeInStats: true,
    );

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecordPage(
          initialRecord: tempRecord,
          isExpense: _parsedRecord!.isExpense,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音记账'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // 状态提示
              Text(
                _statusText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // 语音按钮
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? cs.error
                        : cs.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? cs.error : cs.primary)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    size: 60,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 识别文本显示
              if (_recognizedText.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _recognizedText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // 解析结果展示
              if (_parsedRecord != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _parsedRecord!.isExpense
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: _parsedRecord!.isExpense
                                ? cs.error
                                : cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _parsedRecord!.isExpense ? '支出' : '收入',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: _parsedRecord!.isExpense
                                      ? cs.error
                                      : cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '金额：¥${_parsedRecord!.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_parsedRecord!.remark.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '备注：${_parsedRecord!.remark}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onPrimaryContainer),
                        ),
                      ],
                      if (_matchedCategory != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '分类：${_matchedCategory!.name}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onPrimaryContainer),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _startListening,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('重新识别'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _editRecord,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('编辑'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveRecord,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ] else if (_recognizedText.isNotEmpty) ...[
                // 识别到文本但解析失败
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: cs.onErrorContainer),
                      const SizedBox(height: 8),
                      Text(
                        '未能识别到金额，请说清楚金额，例如："支出50元吃饭"',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // 使用提示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用提示',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    _buildTip('支出50元吃饭'),
                    _buildTip('收入1000工资'),
                    _buildTip('今天花了30块打车'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
