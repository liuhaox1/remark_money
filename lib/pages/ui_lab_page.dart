import 'package:flutter/material.dart';

import '../theme/ios_tokens.dart';
import '../theme/brand_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass.dart';
import 'package:provider/provider.dart';

class UiLabPage extends StatelessWidget {
  const UiLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

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
                    child: SegmentedButton<AppVisualTone>(
                      segments: const [
                        ButtonSegment(
                          value: AppVisualTone.minimal,
                          label: Text('标准'),
                        ),
                        ButtonSegment(
                          value: AppVisualTone.luxe,
                          label: Text('增强质感'),
                        ),
                      ],
                      selected: {themeProvider.tone},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => themeProvider.setTone(v.first),
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
