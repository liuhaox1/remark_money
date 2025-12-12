import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../theme/app_tokens.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.record,
    required this.leftSide,
    this.category,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  final Record record;
  final bool leftSide; // legacy param, layout no longer alternates
  final Category? category;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = category?.name ?? AppStrings.unknown;
    final isExpense = record.isExpense;
    final Color color = isExpense ? AppColors.danger : AppColors.success;
    final icon = category?.icon ?? Icons.category_outlined;
    final amountValue = record.absAmount;
    final sign = isExpense ? '-' : '+';
    final amountStr = '$sign${_NumberFormatter.format(amountValue)}';
    final primaryColor = AppColors.primary(context);
    final amountColor = cs.onSurface;

    final row = Row(
      children: [
        if (selectionMode)
          GestureDetector(
            onTap: () => onSelectedChanged?.call(!selected),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? primaryColor
                      : cs.outlineVariant.withOpacity(0.6),
                ),
                color: selected ? primaryColor : Colors.transparent,
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: cs.onPrimary,
                    )
                  : null,
            ),
          )
        else
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
            child: Icon(icon, color: cs.onPrimary, size: 13),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap:
                selectionMode ? () => onSelectedChanged?.call(!selected) : onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: amountColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (selectionMode || onDelete == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Slidable(
        key: key ?? ValueKey(record.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: AppColors.danger,
              foregroundColor: cs.onError,
              label: AppStrings.delete,
            ),
          ],
        ),
        child: row,
      ),
    );
  }
}

class _NumberFormatter {
  static String format(double value) {
    final absValue = value.abs();
    if (absValue >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}${AppStrings.unitYi}';
    } else if (absValue >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${AppStrings.unitWan}';
    } else {
      return value.toStringAsFixed(2);
    }
  }
}
