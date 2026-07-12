import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/constants/app_constants.dart";
import "../../../../data/services/settings_service.dart";

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.lock_rounded,
      title: "Your books remain on your device",
      description: "We never upload your personal PDF or EPUB files. Your library stays private.",
    ),
    OnboardingPage(
      icon: Icons.privacy_tip_rounded,
      title: "We respect your privacy",
      description: "Metadata sync is opt-in only. Control exactly what you share.",
    ),
    OnboardingPage(
      icon: Icons.wifi_off_rounded,
      title: "Works completely offline",
      description: "Read, bookmark, and organize without internet. Online features enhance the experience.",
    ),
    OnboardingPage(
      icon: Icons.library_books_rounded,
      title: "Organize your digital library",
      description: "Create collections, add tags, and manage your books your way.",
    ),
    OnboardingPage(
      icon: Icons.public_rounded,
      title: "Discover new books legally",
      description: "Browse an online catalog of public and legal book metadata.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
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
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(page.icon, size: 80, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 48),
                        Text(page.title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(page.description, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(settingsServiceProvider).setOnboardingComplete();
                      context.go(AppConstants.routeHome);
                    },
                    child: const Text("Skip"),
                  ),
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        ref.read(settingsServiceProvider).setOnboardingComplete();
                        context.go(AppConstants.routeHome);
                      }
                    },
                    child: Text(_currentPage < _pages.length - 1 ? "Next" : "Get Started"),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  OnboardingPage({required this.icon, required this.title, required this.description});
}
