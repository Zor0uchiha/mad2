import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../core/constants/app_constants.dart";
import "../../core/providers.dart";

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(Duration(milliseconds: AppConstants.splashDelayMs));
    if (!mounted) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final onboardingComplete = prefs.getBool("onboarding_complete") ?? false;
    if (!mounted) return;
    if (onboardingComplete) {
      try {
        final user = await ref.read(authServiceProvider).currentUser;
        if (!mounted) return;
        if (user != null) {
          context.go(AppConstants.routeHome);
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      context.go(AppConstants.routeAuth);
    } else {
      context.go(AppConstants.routeOnboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
