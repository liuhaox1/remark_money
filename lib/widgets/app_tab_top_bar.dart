import 'package:flutter/material.dart';

import '../theme/ios_tokens.dart';
import 'glass.dart';

class AppTabTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabTopBar({
    super.key,
    required this.title,
    required this.tabBar,
    this.actions,
    this.showBack = true,
  });

  final String title;
  final TabBar tabBar;
  final List<Widget>? actions;
  final bool showBack;

  double get _adjustedTabBarHeight {
    final h = tabBar.preferredSize.height;
    // TabBar 默认高度通常是 48；在某些布局（如 DeviceFrame/Windows）顶部区域高度较紧时会溢出。
    // 这里做一个轻微的高度压缩（48 -> 44），保证不溢出且视觉差异极小。
    return h > 44 ? (h - 4) : h;
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + 10 + _adjustedTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          0,
        ),
        child: Glass(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          padding: const EdgeInsets.only(bottom: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : null;
              final availableForTabs = maxH == null ? null : (maxH - kToolbarHeight);
              final tabHeight = availableForTabs == null
                  ? _adjustedTabBarHeight
                  : availableForTabs.clamp(0.0, _adjustedTabBarHeight);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        if (showBack && canPop)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: cs.onSurface,
                              size: 18,
                            ),
                          )
                        else
                          const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (actions != null) ...actions!,
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      height: tabHeight,
                      child: tabBar,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
