import 'package:flutter/material.dart';

import 'number_pad.dart';

Future<void> showNumberPadBottomSheet(
  BuildContext context, {
  required TextEditingController controller,
  bool allowDecimal = true,
  int? maxLength,
  bool formatFixed2OnClose = false,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => NumberPad(
      controller: controller,
      allowDecimal: allowDecimal,
      maxLength: maxLength,
    ),
  );

  if (!formatFixed2OnClose) return;
  final raw = controller.text.trim();
  if (raw.isEmpty) return;
  final normalized = raw.startsWith('.') ? '0$raw' : raw;
  final value = double.tryParse(normalized);
  if (value == null) return;
  final text = value.toStringAsFixed(2);
  controller.value = controller.value.copyWith(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
    composing: TextRange.empty,
  );
}
