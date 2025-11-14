import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../utils/date_utils.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.record,
    required this.leftSide,
    this.category,
  });

  final Record record;
  final bool leftSide; // 保留参数以兼容旧调用，但当前布局不再交错左右
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
    final dateText = DateUtilsX.ymd(record.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountStr,
                    style: const TextStyle(
                      fontSize: 15,
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

