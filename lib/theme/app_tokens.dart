import 'package:flutter/material.dart';

/// 全局 Design Token：颜色 / 文本样式等
class AppColors {
  /// 主色：跟随当前主题的 primary
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 正向金额（结余/收入为正）
  static const Color success = Color(0xFF13A067);

  /// 负向金额（结余/支出为主）
  static const Color danger = Color(0xFFF24848);

  /// 金额为 0 或无数据
  static const Color zero = Color(0xFFB0B0B0);

  /// 主体文字颜色
  static const Color textMain = Color(0xFF222222);

  /// 次级文字颜色
  static const Color textSecondary = Color(0xFF777777);

  /// 分割线 / 边框
  static const Color divider = Color(0xFFE6E2DD);

  /// 根据金额返回语义颜色
  static Color amount(double value) {
    if (value > 0) return success;
    if (value < 0) return danger;
    return zero;
  }

  /// 正向浅色背景（用于盈余高亮）
  static Color positiveBg() => success.withOpacity(0.08);

  /// 负向浅色背景（用于亏损高亮）
  static Color negativeBg() => danger.withOpacity(0.08);
}

class AppTextStyles {
  // 数字/大标题（计数、金额总览）
  static TextStyle display(Color color) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // 模块标题 / 一级标题
  static TextStyle headline(Color color) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );

  // 列表主行 / 卡片主文案
  static TextStyle title(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // 副标题 / 说明文字
  static TextStyle body(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // 次要信息 / 标签 / 导航文字
  static TextStyle caption(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // 极小提示（少用）
  static TextStyle tiny(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

