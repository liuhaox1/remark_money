import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/record.dart';
import '../theme/app_tokens.dart';

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
        isExpense ? AppColors.danger : AppColors.success;
    final icon = category?.icon ?? Icons.category_outlined;
    final amountValue = record.absAmount;
    final sign = isExpense ? '-' : '+';
    // 使用 NumberFormatter 来格式化数字显示
    final amountStr = '$sign${_NumberFormatter.format(amountValue)}';

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
                      color: AppColors.textMain,
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

// 添加 NumberFormatter 类以保持一致性
class _NumberFormatter {
  static String format(double value) {
    final absValue = value.abs();
    if (absValue >= 100000000) {
      // 1亿以上显示为 1.2亿
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (absValue >= 10000) {
      // 1万以上显示为 1.2万
      return '${(value / 10000).toStringAsFixed(1)}万';
    } else {
      // 普通数字显示，最多保留两位小数
      return value.toStringAsFixed(2);
    }
  }
}