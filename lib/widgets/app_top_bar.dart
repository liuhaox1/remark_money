import 'package:flutter/material.dart';

import '../theme/ios_tokens.dart';
import 'glass.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: AppBar(
            titleSpacing: 0,
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: leading ??
                (showBack && Navigator.of(context).canPop()
                    ? IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: cs.onSurface, size: 18),
                      )
                    : null),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            actions: actions,
          ),
        ),
      ),
    );
  }
}

