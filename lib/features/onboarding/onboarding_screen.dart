import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../core/theme/app_colors.dart";
import "../../core/constants/app_constants.dart";
import "../../core/providers.dart";

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      icon: Icons.privacy_tip_rounded,
      title: "Privacy First",
      description: "Your books stay on your device.\nWe never upload your PDFs or EPUBs.",
    ),
    _OnboardingPageData(
      icon: Icons.wifi_off_rounded,
      title: "Read Anywhere",
      description: "Everything works offline.\nRead anywhere without internet.",
    ),
    _OnboardingPageData(
      icon: Icons.explore_rounded,
      title: "Discover & Connect",
      description: "Discover books.\nTrack reading.\nShare your reading journey.",
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool("onboarding_complete", true);
    if (!mounted) return;
    try {
      final user = await ref.read(authServiceProvider).currentUser;
      if (!mounted) return;
      if (user != null) {
        context.go(AppConstants.routeHome);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      context.go(AppConstants.routeHome);
      return;
    }
    if (!mounted) return;
    context.go(AppConstants.routeAuth);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text("Skip"),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            page.icon,
                            size: 80,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 72),
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.accent
                              : AppColors.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    child: Text(
                      _currentPage < _pages.length - 1 ? "Next" : "Get Started",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
