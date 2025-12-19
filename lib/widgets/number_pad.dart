import 'package:flutter/material.dart';

class NumberPad extends StatefulWidget {
  const NumberPad({
    super.key,
    required this.controller,
    this.allowDecimal = true,
    this.maxLength,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final TextEditingController controller;
  final bool allowDecimal;
  final int? maxLength;
  final EdgeInsets headerPadding;

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  late String _expression;

  @override
  void initState() {
    super.initState();
    _expression = widget.controller.text.trim();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant NumberPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      _expression = widget.controller.text.trim();
      widget.controller.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final next = widget.controller.text.trim();
    if (next == _expression) return;
    setState(() => _expression = next);
  }

  void _setExpression(String next) {
    if (widget.maxLength != null && next.length > widget.maxLength!) return;
    setState(() => _expression = next);
    widget.controller.value = widget.controller.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );
  }

  void _onDigitTap(String digit) => _setExpression('$_expression$digit');

  void _onDotTap() {
    if (!widget.allowDecimal) return;
    if (_expression.contains('.')) return;
    if (_expression.isEmpty) {
      _setExpression('0.');
    } else {
      _setExpression('$_expression.');
    }
  }

  void _onBackspace() {
    if (_expression.isEmpty) return;
    _setExpression(_expression.substring(0, _expression.length - 1));
  }

  void _onClear() => _setExpression('');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;
    final keyBackground = cs.surfaceContainerHighest.withOpacity(0.25);

    Widget buildKey({
      required String label,
      VoidCallback? onTap,
      Color? background,
      Color? textColor,
      FontWeight fontWeight = FontWeight.w500,
      int flex = 1,
    }) {
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            color: background ?? keyBackground,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    color: textColor ?? cs.onSurface,
                    fontWeight: fontWeight,
                  ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottom > 0 ? 0 : 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.35),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: widget.headerPadding,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _expression.isEmpty ? '0' : _expression,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Row(
              children: [
                buildKey(label: '7', onTap: () => _onDigitTap('7')),
                buildKey(label: '8', onTap: () => _onDigitTap('8')),
                buildKey(label: '9', onTap: () => _onDigitTap('9')),
                buildKey(
                  label: '清空',
                  onTap: _onClear,
                  textColor: cs.onSurface.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '4', onTap: () => _onDigitTap('4')),
                buildKey(label: '5', onTap: () => _onDigitTap('5')),
                buildKey(label: '6', onTap: () => _onDigitTap('6')),
                buildKey(
                  label: '⌫',
                  onTap: _onBackspace,
                  textColor: cs.onSurface.withOpacity(0.75),
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '1', onTap: () => _onDigitTap('1')),
                buildKey(label: '2', onTap: () => _onDigitTap('2')),
                buildKey(label: '3', onTap: () => _onDigitTap('3')),
                buildKey(
                  label: widget.allowDecimal ? '.' : '',
                  onTap: widget.allowDecimal ? _onDotTap : null,
                  textColor: cs.onSurface.withOpacity(0.75),
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '0', flex: 3, onTap: () => _onDigitTap('0')),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

