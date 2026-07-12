import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/timezone.dart" as tz;
import "package:timezone/data/latest_all.dart" as tz_data;
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";

class SettingsService {
  static const String keyTheme = "theme";
  static const String keyFontScale = "font_scale";
  static const String keySeedColor = "seed_color";
  static const String keyOnboardingComplete = "onboarding_complete";

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  ThemeMode get themeMode {
    final value = _prefs.getString(keyTheme);
    if (value == "dark") return ThemeMode.dark;
    if (value == "light") return ThemeMode.light;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode == ThemeMode.dark ? "dark" : mode == ThemeMode.light ? "light" : "system";
    await _prefs.setString(keyTheme, value);
  }

  double get fontScale => _prefs.getDouble(keyFontScale) ?? 1.0;

  Future<void> setFontScale(double scale) async {
    await _prefs.setDouble(keyFontScale, scale);
  }

  Color get seedColor {
    final stored = _prefs.getInt(keySeedColor);
    return stored != null ? Color(stored) : AppTheme.primaryLight;
  }

  Future<void> setSeedColor(Color color) async {
    await _prefs.setInt(keySeedColor, color.value);
  }

  bool get hasCompletedOnboarding => _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(keyOnboardingComplete, true);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings("@mipmap/ic_launcher");
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(init);
    tz_data.initializeTimeZones();
  }

  Future<void> showDailyReminder(int hour, int minute) async {
    await _notifications.zonedSchedule(
      0,
      "Time to read",
      "You have a reading reminder",
      tz.TZDateTime.now(tz.local).add(const Duration(days: 1)),
      const NotificationDetails(
        android: AndroidNotificationDetails("reading_reminder", "Reading Reminders"),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
