import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:remark_money/models/category.dart';
import 'package:remark_money/models/record.dart';
import 'package:remark_money/utils/date_utils.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.record,
    required this.leftSide,
    this.category,
  });

  final Record record;
  final bool leftSide;
  final Category? category;

  Color _pastelColor(String seed) {
    final hash = seed.codeUnits.fold(0, (a, b) => (a * 131 + b) & 0x7fffffff);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.22, hue, 0.45, 0.70).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final title = category?.name ?? "未分类";
    final color = _pastelColor(title);
    final icon = category?.icon ?? Icons.category_outlined;
    final amountValue = record.absAmount;
    final sign = record.isExpense ? '-' : '+';
    final amountStr = "$sign${amountValue.toStringAsFixed(2)}";
    final dateText = DateUtilsX.ymd(record.date);

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leftSide
            ? [
                Flexible(child: _buildAmount(amountStr)),
                const SizedBox(width: 8),
                Flexible(child: _buildText(context, title, dateText)),
              ]
            : [
                Flexible(child: _buildText(context, title, dateText)),
                const SizedBox(width: 8),
                Flexible(child: _buildAmount(amountStr)),
              ],
      ),
    );

    final dot = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: leftSide
                ? Align(alignment: Alignment.centerRight, child: card)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          dot,
          const SizedBox(width: 8),
          Expanded(
            child: !leftSide
                ? Align(alignment: Alignment.centerLeft, child: card)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildText(BuildContext context, String title, String dateText) {
    return Column(
      crossAxisAlignment:
          leftSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 3),
        Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(String amountStr) {
    return Text(
      amountStr,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
