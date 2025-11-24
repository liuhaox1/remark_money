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
          radius: 70,
          title: '',
          borderSide: BorderSide.none,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 38,
        sections: sections,
      ),
    );
  }
}
