import 'package:flutter/material.dart';

import '../theme/ios_tokens.dart';
import 'app_top_bar.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.leading,
    this.showBack = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: extendBody,
      backgroundColor: cs.surface,
      appBar: title == null
          ? null
          : AppTopBar(
              title: title!,
              actions: actions,
              leading: leading,
              showBack: showBack,
            ),
      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

