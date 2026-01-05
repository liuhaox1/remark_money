import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../theme/ios_tokens.dart';
import '../providers/book_provider.dart';
import '../services/qa_seed_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass.dart';

class UiLabPage extends StatelessWidget {
  const UiLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'UI Lab',
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppSpacing.page.copyWith(
            top: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          children: [
            if (kDebugMode) ...[
              _Section(
                title: 'QA 工具（仅 Debug）',
                child: _QaToolsCard(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              'iOS 极简高级预览（不影响现有页面）',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '后续每个页面改造前，先在这里对齐排版/色彩/组件手感，再逐页迁移。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.72),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: '质感开关（全局生效）',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '更立体（阴影/玻璃效果更明显）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Glass',
              child: Glass(
                padding: AppSpacing.card,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '玻璃拟态容器（暗/亮自动保证对比度）',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        'NEW',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Cards',
              child: Column(
                children: [
                  _MetricCard(
                    title: '本月结余',
                    primaryValue: '-1.1万',
                    secondaryLeft: '收入 0.00',
                    secondaryRight: '支出 1.1万',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ListCard(
                    title: '最近记录',
                    items: const [
                      _ListRowData('餐饮', '-88.00'),
                      _ListRowData('出行', '-33.00'),
                      _ListRowData('工资收入', '+7.8万'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Buttons',
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('主按钮'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {},
                      child: const Text('次按钮'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('边框'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.75),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _QaToolsCard extends StatefulWidget {
  @override
  State<_QaToolsCard> createState() => _QaToolsCardState();
}

class _QaToolsCardState extends State<_QaToolsCard> {
  bool _running = false;
  String? _last;

  Future<void> _runSeed({required bool wipe}) async {
    if (_running) return;
    setState(() {
      _running = true;
      _last = null;
    });
    try {
      final report = await QaSeedService.seed(
        context,
        options: QaSeedOptions(
          wipeExistingRecordsInBook: wipe,
        ),
      );
      if (!mounted) return;
      setState(() {
        _last =
            'book=${report.bookId}, accounts+${report.createdAccounts}, tags+${report.createdTags}, records+${report.createdRecords}';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已完成造数：$_last')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('造数失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBookId = context.watch<BookProvider>().activeBookId;

    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '一键生成 QA 数据集（用于账单/统计/导出/同步回归）',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '当前账本：$activeBookId（将创建/切换到 qa-book）',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
          ),
          if (_last != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '上次：$_last',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _running ? null : () => _runSeed(wipe: false),
                  child: Text(_running ? '处理中…' : '追加生成'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _running ? null : () => _runSeed(wipe: true),
                  child: const Text('清空后重建'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.primaryValue,
    required this.secondaryLeft,
    required this.secondaryRight,
  });

  final String title;
  final String primaryValue;
  final String secondaryLeft;
  final String secondaryRight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.85)),
        boxShadow: AppShadows.soft(cs.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withOpacity(0.70),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            primaryValue,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  secondaryLeft,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  secondaryRight,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListRowData {
  const _ListRowData(this.title, this.value);
  final String title;
  final String value;
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.items});
  final String title;
  final List<_ListRowData> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < items.length; i++) ...[
            _ListRow(item: items[i]),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Divider(
                  height: 1,
                  color: cs.outlineVariant.withOpacity(0.85),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.item});
  final _ListRowData item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = item.value.trim().startsWith('+');
    final valueColor = isPositive ? cs.tertiary : cs.error;
    return Row(
      children: [
        Expanded(
          child: Text(
            item.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          item.value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}
