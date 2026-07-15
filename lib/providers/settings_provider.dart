import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/settings_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.dark);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final value = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await prefs.setString('theme_mode', value);
  }

  Future<void> loadThemeMode() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final value = prefs.getString('theme_mode') ?? 'system';
    switch (value) {
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'light':
        state = ThemeMode.light;
        break;
      default:
        state = ThemeMode.system;
    }
  }
}

final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, double>((ref) {
  return FontScaleNotifier(ref);
});

class FontScaleNotifier extends StateNotifier<double> {
  final Ref _ref;

  FontScaleNotifier(this._ref) : super(1.0);

  Future<void> setFontScale(double scale) async {
    state = scale;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble('font_scale', scale);
  }

  Future<void> loadFontScale() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    state = prefs.getDouble('font_scale') ?? 1.0;
  }
}

final seedColorProvider = StateNotifierProvider<SeedColorNotifier, Color>((ref) {
  return SeedColorNotifier(ref);
});

class SeedColorNotifier extends StateNotifier<Color> {
  final Ref _ref;

  SeedColorNotifier(this._ref) : super(const Color(0xFF1A73E8));

  Future<void> setSeedColor(Color color) async {
    state = color;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('seed_color', color.value);
  }

  Future<void> loadSeedColor() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final stored = prefs.getInt('seed_color');
    if (stored != null) {
      state = Color(stored);
    }
  }
}

final isOnboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('onboarding_complete') ?? false;
});

final brightnessProvider = StateProvider<double>((ref) => 1.0);
final fontSizeProvider = StateProvider<double>((ref) => 16.0);
final marginProvider = StateProvider<double>((ref) => 16.0);
final readerThemeProvider = StateProvider<String>((ref) => 'light');

final publicProfileProvider = StateProvider<bool>((ref) => false);
final syncMetadataProvider = StateProvider<bool>((ref) => true);
final analyticsProvider = StateProvider<bool>((ref) => false);

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }
  return SettingsService(prefs);
});
