import 'package:flutter/material.dart';

import '../models/period_type.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.label,
    this.onTap,
    this.onPrev,
    this.onNext,
    this.periodType,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final PeriodType? periodType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPrev != null)
          _IconCircleButton(
            icon: Icons.chevron_left,
            onTap: onPrev,
          ),
        if (onPrev != null) const SizedBox(width: 6),
        Flexible(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForPeriod(),
                    size: compact ? 16 : 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
        ),
        if (onNext != null) const SizedBox(width: 6),
        if (onNext != null)
          _IconCircleButton(
            icon: Icons.chevron_right,
            onTap: onNext,
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? cs.surface : Colors.white,
        border: Border.all(color: cs.primary.withOpacity(0.18)),
      ),
      child: child,
    );
  }

  IconData _iconForPeriod() {
    switch (periodType) {
      case PeriodType.week:
        return Icons.calendar_view_week;
      case PeriodType.year:
        return Icons.event;
      case PeriodType.month:
      default:
        return Icons.calendar_today;
    }
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
    );
  }
}
