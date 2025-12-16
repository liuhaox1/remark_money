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

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + 10 + tabBar.preferredSize.height);

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
          child: Column(
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
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: cs.onSurface, size: 18),
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
                child: tabBar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
