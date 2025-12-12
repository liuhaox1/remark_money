import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_entry.dart';

class ChartLine extends StatelessWidget {
  const ChartLine({
    super.key,
    required this.entries,
  });

  final List<ChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    double maxValue = 0;
    double minValue = 0; // 确保最小值至少为0
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final value = math.max(0.0, entry.value).toDouble(); // 确保值不为负数并转换为double
      maxValue = math.max(maxValue, value);
      minValue = math.min(minValue, value);
      spots.add(FlSpot(i.toDouble(), value));
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
    final color = entries.isNotEmpty ? entries.first.color : cs.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
      child: LineChart(
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
                      style: TextStyle(
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
                      style: TextStyle(
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
                  return FlDotCirclePainter(
                    radius: 3.5,
                    color: color,
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
          ],
          minX: 0,
          maxX: entries.isEmpty ? 0 : math.max(0, (entries.length - 1).toDouble()), // 确保X轴范围覆盖所有数据点，30天数据：0-29
          minY: math.min(0, minValue), // 如果数据中有负数，允许显示；否则为0
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: false,
          ),
        ),
      ),
    );
  }
}

