import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:hive_flutter/hive_flutter.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/collection_model.dart";
import "../../data/models/reading_goal_model.dart";
import "../../data/services/storage_service.dart";
import "../../data/services/import_service.dart";
import "../../data/repositories/local_repositories.dart";
import "widgets/continue_reading_card.dart";
import "widgets/quick_action_button.dart";
import "widgets/stat_card.dart";

final readingGoalProvider = FutureProvider<ReadingGoalModel?>((ref) async {
  final box = await StorageService.openReadingGoalsBox();
  final goals = box.values.toList();
  if (goals.isEmpty) return null;
  goals.sort((a, b) => b.endDate.compareTo(a.endDate));
  return goals.first;
});

final streakProvider = FutureProvider<int>((ref) async {
  final box = await StorageService.openUserProfileBox();
  final user = box.values.isNotEmpty ? box.values.first : null;
  return user?.readingStreak ?? 0;
});

Future<void> _refreshDashboard(WidgetRef ref) async {
  await Future.wait([
    ref.refresh(allBooksProvider.future),
    ref.refresh(continueReadingProvider.future),
    ref.refresh(recentBooksProvider.future),
    ref.refresh(recentlyAddedBooksProvider.future),
    ref.refresh(totalBooksProvider.future),
    ref.refresh(totalPagesReadProvider.future),
  ]);
}

Future<void> _importBooks(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final service = ImportService(repo);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final imported = await service.pickAndImportBooks();
    if (context.mounted) Navigator.of(context).pop();
    await _refreshDashboard(ref);
    if (context.mounted && imported.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Imported ${imported.length} book${imported.length == 1 ? "" : "s"}"),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    await _refreshDashboard(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Import error: $e")),
      );
    }
  }
}

Future<void> _scanDevice(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final service = ImportService(repo);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final found = await service.scanDevice();
    if (context.mounted) Navigator.of(context).pop();
    await _refreshDashboard(ref);
    if (context.mounted) {
      if (found.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Found and imported ${found.length} book${found.length == 1 ? "" : "s"}"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No new books found on device")),
        );
      }
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    await _refreshDashboard(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan error: $e")),
      );
    }
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allBooks = ref.watch(allBooksProvider).asData?.value ?? [];
    final continueReadingBooks =
        ref.watch(continueReadingProvider).asData?.value ?? [];
    final recentBooks = ref.watch(recentBooksProvider).asData?.value ?? [];
    final recentlyAdded =
        ref.watch(recentlyAddedBooksProvider).asData?.value ?? [];
    final collections =
        ref.watch(allCollectionsProvider).asData?.value ?? [];
    final totalBooks = ref.watch(totalBooksProvider).asData?.value ?? 0;
    final totalPagesRead =
        ref.watch(totalPagesReadProvider).asData?.value ?? 0;
    final readingGoal = ref.watch(readingGoalProvider);
    final streak = ref.watch(streakProvider).asData?.value ?? 0;
    final inProgressCount =
        allBooks.where((b) => b.progress > 0 && b.progress < 1).length;
    final finishedBooks =
        allBooks.where((b) => b.progress >= 1).toList();
    final trending = recentlyAdded;
    final recentlyReviewed = finishedBooks.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppConstants.routeSearch),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshDashboard(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: Icons.flash_on_rounded,
                title: "Quick Actions",
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  QuickActionButton(
                    icon: Icons.upload_file_rounded,
                    label: "Import Book",
                    onTap: () => _importBooks(context, ref),
                  ),
                  QuickActionButton(
                    icon: Icons.phone_android_rounded,
                    label: "Scan Device",
                    onTap: () => _scanDevice(context, ref),
                  ),
                  QuickActionButton(
                    icon: Icons.explore_rounded,
                    label: "Browse Books",
                    onTap: () => context.push(AppConstants.routeBrowse),
                  ),
                  QuickActionButton(
                    icon: Icons.folder_open_rounded,
                    label: "Collections",
                    onTap: () => context.push(AppConstants.routeCollections),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (continueReadingBooks.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.timelapse_rounded,
                  title: "Continue Reading",
                  onTap: () => context.push(AppConstants.routeLibrary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: continueReadingBooks.length,
                    itemBuilder: (context, index) => ContinueReadingCard(
                      book: continueReadingBooks[index],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              _SectionHeader(
                icon: Icons.history_rounded,
                title: "Recent Books",
                subtitle: "${allBooks.length} book${allBooks.length == 1 ? '' : 's'} in library",
                onTap: () => context.push(AppConstants.routeLibrary),
              ),
              const SizedBox(height: 12),
              if (recentBooks.isEmpty && allBooks.isEmpty)
                _buildEmptyLibrary(context, theme, ref)
              else if (recentBooks.isEmpty && allBooks.isNotEmpty)
                _buildRecentEmpty(theme)
              else
                ...recentBooks.take(5).map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentBookRow(book: book),
                  ),
                ),
              if (recentBooks.isNotEmpty || allBooks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => context.push(AppConstants.routeLibrary),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text("View All Books"),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (recentlyAdded.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.add_circle_outline_rounded,
                  title: "Recently Added",
                  onTap: () => context.push(AppConstants.routeLibrary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentlyAdded.length,
                    itemBuilder: (BuildContext context, int index) => _SmallBookCard(
                      book: recentlyAdded[index],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              _SectionHeader(
                icon: Icons.bar_chart_rounded,
                title: "Reading Statistics",
                subtitle: "$inProgressCount in progress",
                onTap: () => context.push(AppConstants.routeStatistics),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: "Total Books",
                      value: "$totalBooks",
                      icon: Icons.menu_book_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: "Books Reading",
                      value: "$inProgressCount",
                      icon: Icons.trending_up_rounded,
                      iconColor: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(
                title: "Pages Read",
                value: "$totalPagesRead",
                icon: Icons.chrome_reader_mode_rounded,
                iconColor: AppColors.streak,
              ),
              const SizedBox(height: 28),
              if (readingGoal.asData?.value case final goal? when goal.targetBooks > 0) ...[
                _SectionHeader(
                  icon: Icons.flag_rounded,
                  title: "Reading Goal",
                  onTap: () => context.push(AppConstants.routeStatistics),
                ),
                const SizedBox(height: 12),
                _ReadingGoalCard(goal: goal),
                const SizedBox(height: 28),
              ],
              _SectionHeader(
                icon: Icons.local_fire_department_rounded,
                title: "Reading Streak",
                onTap: () => context.push(AppConstants.routeStatistics),
              ),
              const SizedBox(height: 12),
              _StreakCard(streak: streak),
              const SizedBox(height: 28),
              if (collections.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.collections_bookmark_rounded,
                  title: "Collections",
                  onTap: () => context.push(AppConstants.routeCollections),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: collections.length,
                    itemBuilder: (BuildContext context, int index) {
                      final col = collections[index];
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Color(col.colorValue),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              col.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],
              if (trending.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.trending_up_rounded,
                  title: "Trending Books",
                  onTap: () => context.push(AppConstants.routeBrowse),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: trending.length,
                    itemBuilder: (BuildContext context, int index) => _SmallBookCard(
                      book: trending[index],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 56,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              "Start Your Reading Journey",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Import books from your device or browse online\nto build your library",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _importBooks(context, ref),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text("Import"),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _scanDevice(context, ref),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text("Scan"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEmpty(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Open a book to start tracking your reading progress",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("See All"),
          ),
      ],
    );
  }
}

class _SmallBookCard extends StatelessWidget {
  final BookModel book;

  const _SmallBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(right: 12),
        child: Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentBookRow extends StatelessWidget {
  final BookModel book;

  const _RecentBookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          book.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: book.progress > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${(book.progress * 100).toInt()}%",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      ),
    );
  }
}

class _ReadingGoalCard extends StatelessWidget {
  final ReadingGoalModel goal;

  const _ReadingGoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.overallProgress.clamp(0.0, 1.0);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.streak.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: AppColors.streak,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Reading Goal",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: AppColors.streak,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${goal.currentBooks} / ${goal.targetBooks} books",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.streak.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.streak,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$streak",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.streak,
                  ),
                ),
                Text(
                  "Day Streak",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
