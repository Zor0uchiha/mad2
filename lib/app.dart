import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/navigation/router.dart';
import 'providers/settings_provider.dart';

class LiboraApp extends ConsumerWidget {
  const LiboraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);

    return MaterialApp.router(
      title: 'Libora',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(seedColor),
      darkTheme: _buildDarkTheme(seedColor),
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  ThemeData _buildLightTheme(Color seed) {
    return AppTheme.lightTheme.copyWith(
      colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
        primary: seed,
        onPrimary: Colors.white,
        primaryContainer: seed.withOpacity(0.15),
        onPrimaryContainer: seed,
      ),
    );
  }

  ThemeData _buildDarkTheme(Color seed) {
    return AppTheme.darkTheme.copyWith(
      colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
        primary: seed,
        onPrimary: Colors.white,
        primaryContainer: seed.withOpacity(0.15),
        onPrimaryContainer: seed,
      ),
    );
  }
}
