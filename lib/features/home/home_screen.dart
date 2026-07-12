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
import "widgets/continue_reading_card.dart";
import "widgets/quick_action_button.dart";
import "widgets/stat_card.dart";

final readingGoalProvider = Provider<ReadingGoalModel?>((ref) {
  final box = Hive.box<ReadingGoalModel>(AppConstants.hiveBoxReadingGoals);
  final goals = box.values.toList();
  if (goals.isEmpty) return null;
  goals.sort((a, b) => b.endDate.compareTo(a.endDate));
  return goals.first;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books = ref.watch(booksProvider).getAllBooks();
    final collections = ref.watch(collectionsProvider).getAllCollections();
    final recentBooks = ref.watch(booksProvider).getRecentBooks(limit: 10);
    final readingGoal = ref.watch(readingGoalProvider);
    final inProgressBooks =
        books.where((b) => b.progress > 0 && b.progress < 1).toList();

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
            if (inProgressBooks.isNotEmpty) ...[
              _SectionTitle(
                title: "Continue Reading",
                onTap: () => context.push(AppConstants.routeLibrary),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: inProgressBooks.length,
                  itemBuilder: (context, index) => ContinueReadingCard(
                    book: inProgressBooks[index],
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
                  label: "Import",
                  onTap: () {},
                ),
                QuickActionButton(
                  icon: Icons.explore_rounded,
                  label: "Browse",
                  onTap: () => context.push(AppConstants.routeBrowse),
                ),
                QuickActionButton(
                  icon: Icons.folder_open_rounded,
                  label: "Collections",
                  onTap: () => context.push(AppConstants.routeCollections),
                ),
                QuickActionButton(
                  icon: Icons.analytics_rounded,
                  label: "Stats",
                  onTap: () => context.push(AppConstants.routeStatistics),
                ),
              ],
            ),
            SizedBox(height: 28),
            _SectionTitle(
              title: "Recent Books",
              onTap: () => context.push(AppConstants.routeLibrary),
            ),
            SizedBox(height: 12),
            if (recentBooks.isEmpty)
              Card(
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
              ...recentBooks.map(
                (book) => _RecentBookRow(book: book),
              ),
            if (collections.isNotEmpty) ...[
              SizedBox(height: 28),
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
            ],
            SizedBox(height: 28),
            if (readingGoal != null && readingGoal.targetBooks > 0) ...[
              _ReadingGoalCard(goal: readingGoal),
              SizedBox(height: 28),
            ],
            StatCard(
              title: "Total Books",
              value: "${books.length}",
              icon: Icons.menu_book_rounded,
            ),
            SizedBox(height: 12),
            StatCard(
              title: "Books in Progress",
              value: "${inProgressBooks.length}",
              icon: Icons.trending_up_rounded,
              iconColor: theme.colorScheme.tertiary,
            ),
            SizedBox(height: 12),
            StatCard(
              title: "Collections",
              value: "${collections.length}",
              icon: Icons.folder_rounded,
              iconColor: AppColors.streak,
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

class _RecentBookRow extends StatelessWidget {
  final BookModel book;

  const _RecentBookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 60,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
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
