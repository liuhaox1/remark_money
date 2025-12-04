import 'package:flutter/material.dart';

/// 文本样式扩展工具类
/// 提供统一的文本样式访问方法，确保整个应用的字体样式一致
extension TextStyleExtensions on BuildContext {
  /// 获取当前主题的文本主题
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// 标题大 - 28px, w800
  TextStyle get headlineLargeStyle => textTheme.headlineLarge!;

  /// 标题中 - 24px, w700
  TextStyle get headlineMediumStyle => textTheme.headlineMedium!;

  /// 标题小 - 18px, w700
  TextStyle get titleLargeStyle => textTheme.titleLarge!;

  /// 标题中等 - 16px, w600
  TextStyle get titleMediumStyle => textTheme.titleMedium!;

  /// 标题小 - 14px, w500
  TextStyle get titleSmallStyle => textTheme.titleSmall!;

  /// 正文大 - 14px, w500
  TextStyle get bodyLargeStyle => textTheme.bodyLarge!;

  /// 正文中 - 12px, w500
  TextStyle get bodyMediumStyle => textTheme.bodyMedium!;

  /// 正文小 - 11px, w500
  TextStyle get bodySmallStyle => textTheme.bodySmall!;

  /// 标签大 - 12px, w500
  TextStyle get labelLargeStyle => textTheme.labelLarge!;

  /// 标签中 - 11px, w500
  TextStyle get labelMediumStyle => textTheme.labelMedium!;
}

/// 文本样式工具类
/// 提供静态方法用于创建统一的文本样式
class AppTextStyles {
  /// 根据主题获取文本样式
  static TextStyle getHeadlineLarge(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!;

  static TextStyle getHeadlineMedium(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;

  static TextStyle getTitleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;

  static TextStyle getTitleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;

  static TextStyle getTitleSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  static TextStyle getBodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;

  static TextStyle getBodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle getBodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  static TextStyle getLabelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;

  static TextStyle getLabelMedium(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!;

  /// 创建带颜色的文本样式
  static TextStyle withColor(BuildContext context, TextStyle style, Color color) =>
      style.copyWith(color: color);

  /// 创建带字重的文本样式
  static TextStyle withWeight(BuildContext context, TextStyle style, FontWeight weight) =>
      style.copyWith(fontWeight: weight);

  /// 创建带字体大小的文本样式
  static TextStyle withSize(BuildContext context, TextStyle style, double size) =>
      style.copyWith(fontSize: size);
}

