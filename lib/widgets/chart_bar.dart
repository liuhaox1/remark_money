// ignore_for_file: prefer_const_constructors

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 简单的数据模型，承载图表显示所需的数据
class ChartEntry {
  const ChartEntry({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class ChartBar extends StatelessWidget {
  const ChartBar({
    super.key,
    required this.entries,
  });

  final List<ChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final barGroups = <BarChartGroupData>[];
    double maxValue = 0;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      maxValue = math.max(maxValue, entry.value);
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              width: 18,
              color: entry.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawHorizontalLine: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 42),
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
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                final entry = entries[index];
                return Transform.rotate(
                  angle: -0.7,
                  child: Text(
                    entry.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }
}
