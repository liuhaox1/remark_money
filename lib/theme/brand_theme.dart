import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeStyle {
  ocean,
  amber,
  graphite,
  mint,
  rose,
  violet,
  coral,
}

enum AppVisualTone {
  minimal,
  luxe,
}

@immutable
class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.headerGradient,
    required this.headerShadow,
    required this.glassFill,
    required this.glassBorder,
    required this.glassBlurSigma,
    required this.cardShadow,
    required this.success,
    required this.danger,
  });

  final Gradient headerGradient;
  final List<BoxShadow> headerShadow;
  final Color glassFill;
  final Color glassBorder;
  final double glassBlurSigma;
  final List<BoxShadow> cardShadow;
  final Color success;
  final Color danger;

  @override
  BrandTheme copyWith({
    Gradient? headerGradient,
    List<BoxShadow>? headerShadow,
    Color? glassFill,
    Color? glassBorder,
    double? glassBlurSigma,
    List<BoxShadow>? cardShadow,
    Color? success,
    Color? danger,
  }) {
    return BrandTheme(
      headerGradient: headerGradient ?? this.headerGradient,
      headerShadow: headerShadow ?? this.headerShadow,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      cardShadow: cardShadow ?? this.cardShadow,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  BrandTheme lerp(ThemeExtension<BrandTheme>? other, double t) {
    if (other is! BrandTheme) return this;
    return BrandTheme(
      headerGradient: other.headerGradient,
      headerShadow: other.headerShadow,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassBlurSigma: glassBlurSigma + (other.glassBlurSigma - glassBlurSigma) * t,
      cardShadow: other.cardShadow,
      success: Color.lerp(success, other.success, t) ?? success,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
    );
  }
}

class AppTheme {
  static ThemeData light(AppThemeStyle style, AppVisualTone tone) =>
      _build(Brightness.light, style, tone);

  static ThemeData dark(AppThemeStyle style, AppVisualTone tone) =>
      _build(Brightness.dark, style, tone);

  static ThemeData _build(
    Brightness brightness,
    AppThemeStyle style,
    AppVisualTone tone,
  ) {
    final isDark = brightness == Brightness.dark;
    final seed = switch (style) {
      AppThemeStyle.ocean => const Color(0xFF2F6BFF),
      AppThemeStyle.amber => const Color(0xFFB66A2E),
      AppThemeStyle.graphite => const Color(0xFF6B7280),
      AppThemeStyle.mint => const Color(0xFF14B8A6),
      AppThemeStyle.rose => const Color(0xFFDB2777),
      AppThemeStyle.violet => const Color(0xFF7C3AED),
      AppThemeStyle.coral => const Color(0xFFFF6B4A),
    };

    Color tint(Color base, double amount) {
      return Color.lerp(base, seed, amount) ?? base;
    }

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ).copyWith(
        surface: tint(
          isDark ? const Color(0xFF0B0D10) : const Color(0xFFF5F6F8),
          isDark ? 0.06 : 0.02,
        ),
        surfaceContainerHighest:
            tint(isDark ? const Color(0xFF12151B) : const Color(0xFFFFFFFF), isDark ? 0.05 : 0.012),
        surfaceContainer: tint(
          isDark ? const Color(0xFF0F1217) : const Color(0xFFF0F2F5),
          isDark ? 0.07 : 0.025,
        ),
        outlineVariant: isDark ? const Color(0xFF252A33) : const Color(0xFFE3E5EA),
        tertiary: const Color(0xFF10B981),
        error: const Color(0xFFEF4444),
      ),
    );

    final cs = base.colorScheme;

    final textThemeBase = GoogleFonts.notoSansScTextTheme(base.textTheme);

    final textTheme = textThemeBase.copyWith(
      titleLarge: textThemeBase.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: textThemeBase.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: textThemeBase.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: textThemeBase.bodyLarge?.copyWith(
        height: 1.28,
      ),
      bodyMedium: textThemeBase.bodyMedium?.copyWith(
        height: 1.28,
      ),
      labelLarge: textThemeBase.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    final cardTheme = CardTheme(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(isDark ? 0.7 : 0.85)),
      ),
      margin: EdgeInsets.zero,
    );

    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: cs.onSurface.withOpacity(0.55),
      ),
    );

    final chipTheme = ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      disabledColor: cs.surfaceContainerHighest.withOpacity(0.7),
      selectedColor: cs.primary.withOpacity(isDark ? 0.28 : 0.14),
      secondarySelectedColor: cs.primary.withOpacity(isDark ? 0.28 : 0.14),
      labelStyle: textTheme.labelMedium?.copyWith(color: cs.onSurface),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: cs.primary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.9)),
      ),
    );

    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.95)),
        textStyle: textTheme.labelLarge,
      ),
    );

    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge,
        foregroundColor: cs.primary,
      ),
    );

    final appBarTheme = AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    );

    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );

    final navTheme = NavigationBarThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      indicatorColor: cs.primary.withOpacity(isDark ? 0.26 : 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? cs.onSurface : cs.onSurface.withOpacity(0.65),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? cs.onSurface : cs.onSurface.withOpacity(0.6),
          size: 22,
        );
      }),
    );

    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(
              cs.surfaceContainerHighest,
              cs.primary,
              isDark ? 0.10 : 0.06,
            ) ??
            cs.surfaceContainerHighest,
        Color.lerp(
              cs.surfaceContainerHigh,
              cs.primary,
              isDark ? 0.06 : 0.03,
            ) ??
            cs.surfaceContainerHigh,
      ],
    );

    final headerShadow = [
      BoxShadow(
        color: cs.primary.withOpacity(isDark ? 0.16 : 0.12),
        blurRadius: tone == AppVisualTone.luxe ? 26 : 18,
        offset: Offset(0, tone == AppVisualTone.luxe ? 14 : 10),
      ),
    ];

    final cardShadow = [
      BoxShadow(
        color: cs.shadow.withOpacity(isDark ? 0.22 : (tone == AppVisualTone.luxe ? 0.12 : 0.08)),
        blurRadius: tone == AppVisualTone.luxe ? 22 : 14,
        offset: Offset(0, tone == AppVisualTone.luxe ? 14 : 10),
      ),
    ];

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surface,
      cardTheme: cardTheme,
      inputDecorationTheme: inputTheme,
      chipTheme: chipTheme,
      filledButtonTheme: filledButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme,
      appBarTheme: appBarTheme,
      bottomSheetTheme: bottomSheetTheme,
      navigationBarTheme: navTheme,
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(isDark ? 0.7 : 0.9),
        thickness: 1,
        space: 1,
      ),
      extensions: [
        BrandTheme(
          headerGradient: headerGradient,
          headerShadow: headerShadow,
          glassFill: cs.surfaceContainerHighest.withOpacity(isDark ? 0.72 : 0.78),
          glassBorder: cs.outlineVariant.withOpacity(isDark ? 0.65 : 0.85),
          glassBlurSigma: tone == AppVisualTone.luxe ? 22 : 14,
          cardShadow: cardShadow,
          success: cs.tertiary,
          danger: cs.error,
        ),
      ],
    );
  }
}
