import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
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
