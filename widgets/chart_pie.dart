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

    final sections = entries
        .map(
          (entry) => PieChartSectionData(
            color: entry.color,
            value: entry.value,
            radius: 60,
            title: "${(entry.value / total * 100).toStringAsFixed(1)}%",
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        )
        .toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: sections,
      ),
    );
  }
}
