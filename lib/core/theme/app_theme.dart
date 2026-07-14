import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const double cardRadius = 20;
  static const double buttonRadius = 14;
  static const double inputRadius = 14;
  static const double sheetRadius = 24;

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
      surfaceSecondary: AppColors.surfaceSecondaryDark,
      card: AppColors.cardDark,
      accent: AppColors.accent,
      onAccent: Colors.white,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      border: AppColors.border,
    );
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
      surfaceSecondary: AppColors.surfaceSecondaryLight,
      card: AppColors.cardLight,
      accent: AppColors.accent,
      onAccent: Colors.white,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      border: AppColors.borderLight,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color surface,
    required Color surfaceSecondary,
    required Color card,
    required Color accent,
    required Color onAccent,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: accent.withOpacity(0.15),
      onPrimaryContainer: accent,
      secondary: accentSecondary(isDark),
      onSecondary: onAccent,
      secondaryContainer: accentSecondary(isDark).withOpacity(0.15),
      onSecondaryContainer: accentSecondary(isDark),
      tertiary: const Color(0xFF7C4DFF),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF7C4DFF).withOpacity(0.15),
      onTertiaryContainer: const Color(0xFF7C4DFF),
      error: const Color(0xFFEF5350),
      onError: Colors.white,
      errorContainer: const Color(0xFFEF5350).withOpacity(0.15),
      onErrorContainer: const Color(0xFFEF5350),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: isDark ? const Color(0xFF2B2F38) : const Color(0xFFF0F1F3),
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border.withOpacity(0.5),
      inverseSurface: isDark ? const Color(0xFFF8F9FA) : const Color(0xFF0F1115),
      onInverseSurface: isDark ? const Color(0xFF1A1C1E) : const Color(0xFFF8F9FA),
      shadow: Colors.black.withOpacity(0.3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      fontFamily: _getFontFamily(),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontFamily: _getFontFamily(),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceSecondary,
        elevation: 0,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: _getFontFamily()),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontFamily: _getFontFamily()),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surfaceSecondary,
        indicatorColor: accent.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: _getFontFamily()),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 22)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: _getFontFamily()),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: _getFontFamily()),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
            side: BorderSide(color: accent.withOpacity(0.4)),
          ),
          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: _getFontFamily()),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: _getFontFamily()),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF3F4F6),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF2B2F38) : const Color(0xFFF0F1F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        labelStyle: TextStyle(fontSize: 13, fontFamily: _getFontFamily()),
      ),
      dividerTheme: DividerThemeData(
        color: border.withOpacity(0.4),
        thickness: 0.5,
        space: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark ? const Color(0xFF2B2F38) : const Color(0xFF1F2937),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sheetRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.withOpacity(0.3);
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withOpacity(0.2),
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accent.withOpacity(0.2),
      ),
    );
  }

  static Color accentSecondary(bool isDark) {
    return isDark ? AppColors.accentSecondary : AppColors.accentSecondary;
  }

  static String? _getFontFamily() {
    return null;
  }
}

// Extension for consistent spacing
extension ThemeSpacing on BuildContext {
  double get spacingXs => 4;
  double get spacingSm => 8;
  double get spacingMd => 16;
  double get spacingLg => 24;
  double get spacingXl => 32;
}
