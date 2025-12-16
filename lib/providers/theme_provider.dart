import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/brand_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  AppThemeStyle _style = AppThemeStyle.ocean;
  AppVisualTone _tone = AppVisualTone.minimal;

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
        orElse: () => AppVisualTone.minimal,
      );
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
    if (_tone == tone) return;
    _tone = tone;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_tone', tone.toString());
  }
}
