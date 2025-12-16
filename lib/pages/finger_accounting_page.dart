import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/app_scaffold.dart';

class FingerAccountingPage extends StatelessWidget {
  const FingerAccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: AppStrings.version,
      body: SizedBox.expand(),
    );
  }
}
