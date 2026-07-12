import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyTheme = 'theme';
  static const String keyFontScale = 'font_scale';
  static const String keySeedColor = 'seed_color';
  static const String keyOnboardingComplete = 'onboarding_complete';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  ThemeMode get themeMode {
    final value = _prefs.getString(keyTheme);
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await _prefs.setString(keyTheme, value);
  }

  double get fontScale => _prefs.getDouble(keyFontScale) ?? 1.0;

  Future<void> setFontScale(double scale) async {
    await _prefs.setDouble(keyFontScale, scale);
  }

  Color get seedColor {
    final stored = _prefs.getInt(keySeedColor);
    return stored != null ? Color(stored) : const Color(0xFF1A73E8);
  }

  Future<void> setSeedColor(Color color) async {
    await _prefs.setInt(keySeedColor, color.value);
  }

  bool get hasCompletedOnboarding => _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(keyOnboardingComplete, true);
  }
}
