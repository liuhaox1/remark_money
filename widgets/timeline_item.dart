import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/record.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.record,
    required this.leftSide,
    this.category,
  });

  final Record record;
  final bool leftSide; // 兼容旧参数，当前布局不再左右交错
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final title = category?.name ?? '未分类';
    final isExpense = record.isExpense;
    final Color color =
        isExpense ? Colors.redAccent : Colors.green.shade600;
    final icon = category?.icon ?? Icons.category_outlined;
    final amountValue = record.absAmount;
    final sign = isExpense ? '-' : '+';
    final amountStr = '$sign${amountValue.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

