import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_bar.dart';

class ChartPie extends StatelessWidget {
  const ChartPie({
    super.key,
    required this.entries,
  });

  final List<ChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final palette = <Color>[
      const Color(0xFF3B82F6), // 蓝
      const Color(0xFFF59E0B), // 橙
      const Color(0xFF10B981), // 绿
      const Color(0xFFE11D48), // 红
      const Color(0xFF8B5CF6), // 紫
      const Color(0xFF06B6D4), // 青
      const Color(0xFF84CC16), // 黄绿
    ];

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final color = palette[i % palette.length];
      final percent = entry.value / total * 100;
      final showLabel = percent >= 3; // 太小的切片不展示标题，避免重叠
      final textColor =
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black87;
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          radius: 60,
          title: showLabel ? "${percent.toStringAsFixed(1)}%" : '',
          titleStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          titlePositionPercentageOffset: showLabel ? 1.15 : 0.6,
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.7),
            width: 1.2,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 44,
        sections: sections,
      ),
    );
  }
}
