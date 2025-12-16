import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_entry.dart';

class ChartLine extends StatelessWidget {
  const ChartLine({
    super.key,
    required this.entries,
    this.compareEntries,
    this.budgetY,
    this.avgY,
    this.highlightIndices,
    this.bottomLabelBuilder,
  });

  final List<ChartEntry> entries;
  final List<ChartEntry>? compareEntries;
  final double? budgetY;
  final double? avgY;
  final Set<int>? highlightIndices;
  final String? Function(int index, ChartEntry entry)? bottomLabelBuilder;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    List<FlSpot> buildSpots(List<ChartEntry> list) {
      final result = <FlSpot>[];
      for (var i = 0; i < list.length; i++) {
        final value = math.max(0.0, list[i].value).toDouble();
        result.add(FlSpot(i.toDouble(), value));
      }
      return result;
    }

    final spots = buildSpots(entries);
    final compareSpots =
        compareEntries != null && compareEntries!.isNotEmpty
            ? buildSpots(compareEntries!)
            : null;

    double maxValue = 0;
    double minValue = 0; // 确保最小值至少为0
    for (final s in spots) {
      maxValue = math.max(maxValue, s.y);
      minValue = math.min(minValue, s.y);
    }
    if (compareSpots != null) {
      for (final s in compareSpots) {
        maxValue = math.max(maxValue, s.y);
        minValue = math.min(minValue, s.y);
      }
    }
    if (budgetY != null) {
      maxValue = math.max(maxValue, budgetY!);
    }

    // 计算合适的Y轴最大值
    double maxY;
    if (maxValue <= 0) {
      maxY = 1.0;
    } else {
      final rawMax = maxValue * 1.15; // 留一点顶部空间
      double step;
      if (maxValue <= 20) {
        step = 5;
      } else if (maxValue <= 100) {
        step = 20;
      } else if (maxValue <= 500) {
        step = 100;
      } else {
        step = 200;
      }
      maxY = (rawMax / step).ceil() * step;
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = entries.first.color;
    final compareColor = cs.outline;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
      child: LineChart(
        duration: Duration.zero,
        curve: Curves.linear,
        LineChartData(
          clipData: FlClipData.none(), // 不裁剪数据，确保所有点都显示
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: true,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: cs.outline.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toStringAsFixed(0),
                      style: tt.labelSmall?.copyWith(
                        fontSize: 10,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1, // 每个点都尝试显示标签
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  if (bottomLabelBuilder != null) {
                    final label = bottomLabelBuilder!(index, entries[index]);
                    if (label == null || label.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      label,
                      style: tt.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    );
                  }

                  final day = index + 1;
                  // 显示关键日期：1, 5, 10, 15, 20, 25, 30 等，以及最后一天
                  if (day == 1 || 
                      day == 5 || 
                      day == 10 || 
                      day == 15 || 
                      day == 20 || 
                      day == 25 || 
                      day == 30 ||
                      day == entries.length || // 显示最后一天
                      (entries.length <= 7 && day <= entries.length)) {
                    return Text(
                      day.toString(),
                      style: tt.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isHighlight =
                      highlightIndices != null &&
                          highlightIndices!.contains(index);
                  return FlDotCirclePainter(
                    radius: isHighlight ? 5 : 3.5,
                    color: isHighlight ? cs.error : color,
                    strokeWidth: 2,
                    strokeColor: cs.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.15),
              ),
            ),
            if (compareSpots != null)
              LineChartBarData(
                spots: compareSpots,
                isCurved: false,
                color: compareColor,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          minX: 0,
          maxX: entries.isEmpty ? 0 : math.max(0, (entries.length - 1).toDouble()), // 确保X轴范围覆盖所有数据点，30天数据：0-29
          minY: math.min(0, minValue), // 如果数据中有负数，允许显示；否则为0
          maxY: maxY,
          extraLinesData: (budgetY != null || avgY != null)
              ? ExtraLinesData(
                  horizontalLines: [
                    if (budgetY != null)
                      HorizontalLine(
                        y: budgetY!,
                        color: cs.primary.withOpacity(0.6),
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          style: tt.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          labelResolver: (_) => '预算',
                        ),
                      ),
                    if (avgY != null)
                      HorizontalLine(
                        y: avgY!,
                        color: cs.outline.withOpacity(0.6),
                        strokeWidth: 1,
                        dashArray: [3, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          style: tt.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                          labelResolver: (_) => '均值',
                        ),
                      ),
                  ],
                )
              : null,
          lineTouchData: LineTouchData(
            enabled: false,
          ),
        ),
      ),
    );
  }
}
