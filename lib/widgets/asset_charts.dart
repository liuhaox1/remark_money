import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/record_provider.dart';
import '../providers/book_provider.dart';
import '../theme/app_tokens.dart';
import '../l10n/app_strings.dart';
import '../pages/account_detail_page.dart';

/// 资产趋势图和占比图组件
class AssetCharts extends StatelessWidget {
  const AssetCharts({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final recordProvider = context.watch<RecordProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;

    final accounts = accountProvider.accounts
        .where((a) => a.includeInOverview && a.kind == AccountKind.asset)
        .toList();

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 趋势图
        _buildTrendChart(context, recordProvider, bookId),
        const SizedBox(height: 12),
        // 占比图
        _buildDistributionChart(context, accounts),
      ],
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    RecordProvider recordProvider,
    String bookId,
  ) {
    return _TrendChartWidget(
      recordProvider: recordProvider,
      bookId: bookId,
    );
  }

  Widget _buildDistributionChart(
    BuildContext context,
    List<Account> accounts,
  ) {
    final cs = Theme.of(context).colorScheme;
    // 只计算正余额的账户
    final positiveAccounts = accounts
        .where((a) => a.currentBalance > 0)
        .toList();

    if (positiveAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalAssets = positiveAccounts.fold<double>(
      0,
      (sum, a) => sum + a.currentBalance,
    );

    if (totalAssets <= 0) {
      return const SizedBox.shrink();
    }

    // 按余额排序，取前5个
    final topAccounts = positiveAccounts.toList()
      ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
    final displayAccounts = topAccounts.take(5).toList();
    final othersAmount = topAccounts
        .skip(5)
        .fold<double>(0, (sum, a) => sum + a.currentBalance);

    final colors = [
      AppColors.success,
      const Color(0xFF1677FF),
      const Color(0xFFFF9500),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产构成',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: [
                            ...displayAccounts.asMap().entries.map((e) {
                              final account = e.value;
                              final percentage =
                                  (account.currentBalance / totalAssets * 100);
                              return PieChartSectionData(
                                value: account.currentBalance,
                                title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
                                color: colors[e.key % colors.length],
                                radius: 40,
                                titleStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimary,
                                    ),
                              );
                            }),
                            if (othersAmount > 0)
                              PieChartSectionData(
                                value: othersAmount,
                                title: (othersAmount / totalAssets * 100) > 5 ? '其他' : '',
                                color: cs.outlineVariant,
                                radius: 40,
                                titleStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimary,
                                    ),
                              ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${displayAccounts.length + (othersAmount > 0 ? 1 : 0)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          Text(
                            '账户',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ...displayAccounts.asMap().entries.map((e) {
                        final account = e.value;
                        final percentage =
                            (account.currentBalance / totalAssets * 100);
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountDetailPage(accountId: account.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: colors[e.key % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              height: 1.2,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatAmount(account.currentBalance),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                              fontWeight: FontWeight.w500,
                                              height: 1.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (othersAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: cs.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '其他',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatAmount(othersAmount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                            fontWeight: FontWeight.w500,
                                            height: 1.2,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(othersAmount / totalAssets * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化金额显示（支持万、亿单位）
  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    }
    return value.toStringAsFixed(2);
  }
}

/// 带交互功能的趋势图组件
class _TrendChartWidget extends StatefulWidget {
  const _TrendChartWidget({
    required this.recordProvider,
    required this.bookId,
  });

  final RecordProvider recordProvider;
  final String bookId;

  @override
  State<_TrendChartWidget> createState() => _TrendChartWidgetState();
}

class _TrendChartWidgetState extends State<_TrendChartWidget> {
  int? _touchedIndex;
  List<_DayNetWorth>? _cachedData;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final now = DateTime.now();
    final last30Days = List.generate(30, (i) {
      return now.subtract(Duration(days: 29 - i));
    });

    // 使用缓存优化性能
    if (_cachedData == null || _cachedData!.length != last30Days.length) {
      _cachedData = _calculateNetWorthData(
        accountProvider,
        widget.recordProvider,
        widget.bookId,
        last30Days,
      );
    }

    final spots = _cachedData!
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.netWorth))
        .toList();

    if (spots.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '近30天净资产趋势',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final minY = () {
      final min = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      final range = max - min;
      if (range < max * 0.01) {
        final result = min - max * 0.1;
        return result < 0 ? 0.0 : result;
      }
      final result = min - range * 0.1;
      return result < 0 ? 0.0 : result;
    }();

    final maxY = () {
      final min = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      final range = max - min;
      if (range < max * 0.01) {
        return max * 1.1;
      }
      return max + range * 0.1;
    }();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '近30天净资产趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (_touchedIndex != null)
                  Text(
                    _formatDate(_cachedData![_touchedIndex!].date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_touchedIndex != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '净资产: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    Text(
                      _formatAmount(_cachedData![_touchedIndex!].netWorth),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 7,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _cachedData!.length) {
                            return const Text('');
                          }
                          final date = _cachedData![index].date;
                          // 只显示月初和月中
                          if (date.day == 1 || date.day == 15) {
                            return Text(
                              '${date.month}/${date.day}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.6),
                                  ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatAmount(value),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.6),
                                ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: _touchedIndex != null,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppColors.success,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= _cachedData!.length) {
                            return null;
                          }
                          // 使用Future.microtask延迟setState调用，避免在构建过程中触发
                          Future.microtask(() {
                            if (mounted && _touchedIndex != index) {
                              setState(() {
                                _touchedIndex = index;
                              });
                            }
                          });
                          return LineTooltipItem(
                            '',
                            Theme.of(context).textTheme.bodySmall!,
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    getTouchLineStart: (data, index) => 0,
                    getTouchLineEnd: (data, index) => double.infinity,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (event is FlTapUpEvent || event is FlPanEndEvent) {
                        // 触摸结束时清除选中状态
                        Future.microtask(() {
                          if (mounted) {
                            setState(() {
                              _touchedIndex = null;
                            });
                          }
                        });
                      } else if (event is FlPanStartEvent || event is FlPanUpdateEvent) {
                        // 触摸时更新选中状态
                        if (touchResponse != null && touchResponse.lineBarSpots != null) {
                          final spot = touchResponse.lineBarSpots!.first;
                          final index = spot.x.toInt();
                          if (index >= 0 && index < _cachedData!.length) {
                            Future.microtask(() {
                              if (mounted && _touchedIndex != index) {
                                setState(() {
                                  _touchedIndex = index;
                                });
                              }
                            });
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DayNetWorth> _calculateNetWorthData(
    AccountProvider accountProvider,
    RecordProvider recordProvider,
    String bookId,
    List<DateTime> days,
  ) {
    final result = <_DayNetWorth>[];
    
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
      
      // 获取该日期及之前的所有记录
      final records = recordProvider.recordsForBook(bookId)
          .where((r) => r.date.isBefore(dayEnd.add(const Duration(seconds: 1))))
          .toList();

      // 计算该日期的净资产
      double dayNetWorth = 0;
      final accountBalances = <String, double>{};
      
      // 初始化账户余额（使用初始余额）
      for (final account in accountProvider.accounts) {
        accountBalances[account.id] = account.initialBalance;
      }
      
      // 应用所有记录到该日期
      for (final record in records) {
        final currentBalance = accountBalances[record.accountId] ?? 0.0;
        final delta = record.isIncome ? record.amount : -record.amount;
        accountBalances[record.accountId] = currentBalance + delta;
      }
      
      // 计算净资产
      for (final account in accountProvider.accounts) {
        if (!account.includeInOverview) continue;
        final balance = accountBalances[account.id] ?? 0.0;
        if (account.kind == AccountKind.asset) {
          dayNetWorth += balance;
        } else if (account.kind == AccountKind.liability) {
          dayNetWorth -= balance.abs();
        }
      }
      
      result.add(_DayNetWorth(date: day, netWorth: dayNetWorth));
    }
    
    return result;
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _formatAmount(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    }
    return value.toStringAsFixed(2);
  }
}

class _DayNetWorth {
  final DateTime date;
  final double netWorth;

  _DayNetWorth({required this.date, required this.netWorth});
}
