import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../utils/error_handler.dart';
import '../widgets/app_top_bar.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final content = _contentCtrl.text;
    if (content.trim().isEmpty) {
      ErrorHandler.showWarning(context, '请填写反馈内容');
      return;
    }

    setState(() => _submitting = true);
    try {
      ErrorHandler.showInfo(context, '正在提交...');
      await FeedbackService().submit(
        content: content,
        contact: _contactCtrl.text,
      );
      if (!mounted) return;
      ErrorHandler.showSuccess(context, '提交成功，感谢反馈！');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleAsyncError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: '意见反馈'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '反馈内容',
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentCtrl,
                      minLines: 6,
                      maxLines: 10,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: '请输入你的建议或遇到的问题（必填）',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '联系方式（可选）',
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactCtrl,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: '手机号 / 微信 / 邮箱，方便我们联系你',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中...' : '提交'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

