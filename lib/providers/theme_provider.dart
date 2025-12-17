import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/brand_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  AppThemeStyle _style = AppThemeStyle.ocean;
  AppVisualTone _tone = AppVisualTone.luxe;

  ThemeMode get mode => _mode;
  AppThemeStyle get style => _style;
  AppVisualTone get tone => _tone;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode');
    final styleStr = prefs.getString('theme_style');
    final toneStr = prefs.getString('theme_tone');

    if (modeStr != null) {
      _mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == modeStr,
        orElse: () => ThemeMode.light,
      );
    }
    if (styleStr != null) {
      _style = AppThemeStyle.values.firstWhere(
        (e) => e.toString() == styleStr,
        orElse: () => AppThemeStyle.ocean,
      );
    }
    if (toneStr != null) {
      _tone = AppVisualTone.values.firstWhere(
        (e) => e.toString() == toneStr,
        orElse: () => AppVisualTone.luxe,
      );
    }

    // 产品策略：不再提供“标准”档，统一使用更立体的视觉质感。
    if (_tone != AppVisualTone.luxe) {
      _tone = AppVisualTone.luxe;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  Future<void> setStyle(AppThemeStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_style', style.toString());
  }

  Future<void> setTone(AppVisualTone tone) async {
    // 保留接口兼容历史调用，但只允许更立体档
    if (_tone == AppVisualTone.luxe) return;
    _tone = AppVisualTone.luxe;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_tone', _tone.toString());
  }
}
