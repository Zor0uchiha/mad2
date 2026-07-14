import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/theme/app_colors.dart";

final shellIndexProvider = StateProvider<int>((ref) => 0);

class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = ref.watch(shellIndexProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border.withOpacity(0.4) : AppColors.borderLight.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(shellIndexProvider.notifier).state = index;
            final routes = ["/home", "/library", "/browse", "/activity", "/profile"];
            context.go(routes[index]);
          },
          backgroundColor: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondaryLight,
          indicatorColor: AppColors.accent.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 68,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.library_books_outlined, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              selectedIcon: Icon(Icons.library_books_rounded, color: AppColors.accent),
              label: "Library",
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              selectedIcon: Icon(Icons.explore_rounded, color: AppColors.accent),
              label: "Browse",
            ),
            NavigationDestination(
              icon: Icon(Icons.timeline_outlined, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              selectedIcon: Icon(Icons.timeline_rounded, color: AppColors.accent),
              label: "Activity",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.accent),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
