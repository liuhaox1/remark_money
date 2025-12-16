import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';
import '../theme/ios_tokens.dart';

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.xl)),
    this.padding,
    this.blurSigma = 18,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets? padding;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<BrandTheme>();
    final fill = brand?.glassFill ?? cs.surfaceContainerHighest.withOpacity(0.78);
    final border = brand?.glassBorder ?? cs.outlineVariant.withOpacity(0.85);
    final sigma = brand?.glassBlurSigma ?? blurSigma;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: border, width: 1),
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}
