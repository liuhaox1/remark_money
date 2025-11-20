import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class FingerAccountingPage extends StatelessWidget {
  const FingerAccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.version)),
      body: const SizedBox.expand(),
    );
  }
}
