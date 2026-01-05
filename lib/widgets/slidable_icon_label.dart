import 'package:flutter/material.dart';

class SlidableIconLabel extends StatelessWidget {
  const SlidableIconLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        // Windows/小尺寸下，Slidable action 区域高度可能只有 ~24px；
        // 此时显示“图标+文字”会必然溢出，降级为仅图标以保证不报错。
        final showLabel = maxHeight >= 36;
        final iconSize = maxHeight.isFinite
            ? maxHeight.clamp(16.0, showLabel ? 20.0 : 22.0)
            : 20.0;

        if (!showLabel) {
          return Center(
            child: Icon(icon, color: color, size: iconSize),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
