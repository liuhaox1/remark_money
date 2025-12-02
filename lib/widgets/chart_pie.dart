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

    final sections = <PieChartSectionData>[];
    for (final entry in entries) {
      final color = entry.color;
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          radius: 45, // 半径45，直径90，加上fl_chart默认padding约16px，总宽度约106px，在120px容器内安全
          title: '',
          borderSide: BorderSide.none,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8), // 添加padding确保不超出
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 22, // 中心空白半径，保持比例
          sections: sections,
        ),
      ),
    );
  }
}
