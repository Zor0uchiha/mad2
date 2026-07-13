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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (continueReadingBooks.isNotEmpty) ...[
              _SectionTitle(
                title: "Continue Reading",
                onTap: () => context.push(AppConstants.routeLibrary),
              ),
              SizedBox(height: 12),
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
              SizedBox(height: 28),
            ],
            _SectionTitle(
              title: "Recent Books",
              onTap: () => context.push(AppConstants.routeLibrary),
            ),
            SizedBox(height: 12),
            if (recentBooks.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      "No books yet. Import your first book!",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...recentBooks.take(10).map(
                    (book) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecentBookRow(book: book),
                    ),
                  ),
            SizedBox(height: 28),
            if (recentlyAdded.isNotEmpty) ...[
              _SectionTitle(
                title: "Recently Added",
                onTap: () => context.push(AppConstants.routeLibrary),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentlyAdded.length,
                  itemBuilder: (context, index) => _SmallBookCard(
                    book: recentlyAdded[index],
                  ),
                ),
              ),
              SizedBox(height: 28),
            ],
            _SectionTitle(
              title: "Reading Statistics",
              onTap: () => context.push(AppConstants.routeStatistics),
            ),
            SizedBox(height: 12),
            StatCard(
              title: "Total Books",
              value: "$totalBooks",
              icon: Icons.menu_book_rounded,
            ),
            SizedBox(height: 12),
            StatCard(
              title: "Books Currently Reading",
              value: "$inProgressCount",
              icon: Icons.trending_up_rounded,
              iconColor: theme.colorScheme.tertiary,
            ),
            SizedBox(height: 12),
            StatCard(
              title: "Pages Read",
              value: "$totalPagesRead",
              icon: Icons.chrome_reader_mode_rounded,
              iconColor: AppColors.streak,
            ),
            SizedBox(height: 28),
            if (readingGoal.asData?.value case final goal? when goal.targetBooks > 0) ...[
              _ReadingGoalCard(goal: goal),
              SizedBox(height: 28),
            ],
            _SectionTitle(
              title: "Reading Streak",
              onTap: () => context.push(AppConstants.routeStatistics),
            ),
            SizedBox(height: 12),
            _StreakCard(streak: streak),
            SizedBox(height: 28),
            if (collections.isNotEmpty) ...[
              _SectionTitle(
                title: "Favorite Collections",
                onTap: () => context.push(AppConstants.routeCollections),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final col = collections[index];
                    return Container(
                      width: 160,
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
              SizedBox(height: 28),
            ],
            if (trending.isNotEmpty) ...[
              _SectionTitle(
                title: "Trending Books",
                onTap: () => context.push(AppConstants.routeBrowse),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: trending.length,
                  itemBuilder: (context, index) => _SmallBookCard(
                    book: trending[index],
                  ),
                ),
              ),
              SizedBox(height: 28),
            ],
            if (recentlyReviewed.isNotEmpty) ...[
              _SectionTitle(
                title: "Recently Reviewed",
                onTap: () => context.push(AppConstants.routeLibrary),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentlyReviewed.length,
                  itemBuilder: (context, index) => _SmallBookCard(
                    book: recentlyReviewed[index],
                  ),
                ),
              ),
              SizedBox(height: 28),
            ],
            _SectionTitle(title: "Quick Actions", onTap: null),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                QuickActionButton(
                  icon: Icons.upload_file_rounded,
                  label: "Import Book",
                  onTap: () {},
                ),
                QuickActionButton(
                  icon: Icons.phone_android_rounded,
                  label: "Scan Device",
                  onTap: () {},
                ),
                QuickActionButton(
                  icon: Icons.explore_rounded,
                  label: "Browse Books",
                  onTap: () => context.push(AppConstants.routeBrowse),
                ),
                QuickActionButton(
                  icon: Icons.folder_open_rounded,
                  label: "Create Collection",
                  onTap: () => context.push(AppConstants.routeCollections),
                ),
              ],
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _SectionTitle({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        margin: const EdgeInsets.only(right: 12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
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
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
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
            ? Text(
                "${(book.progress * 100).toInt()}%",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: AppColors.streak,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  "Reading Goal",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: AppColors.streak,
              ),
            ),
            SizedBox(height: 12),
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
                  style: theme.textTheme.bodySmall?.copyWith(
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
            SizedBox(width: 16),
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
                  streak == 1 ? "Day Streak" : "Day Streak",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
