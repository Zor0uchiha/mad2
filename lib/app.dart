import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "./core/theme/app_theme.dart";
import "./core/constants/app_constants.dart";
import "./core/navigation/router.dart";
import "./core/providers.dart";

final fontScaleProvider = StateProvider<double>((ref) => 1.0);
final seedColorProvider = StateProvider<Color>((ref) => AppTheme.primaryLight);

class AppWidget extends ConsumerWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        colorScheme: AppTheme.lightTheme.colorScheme.copyWith(primary: seedColor),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        colorScheme: AppTheme.darkTheme.colorScheme.copyWith(primary: seedColor),
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
