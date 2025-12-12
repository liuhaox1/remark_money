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

