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
  try {
    final imported = await service.pickAndImportBooks();
    if (context.mounted) {
      ref.invalidate(allBooksProvider);
      ref.invalidate(continueReadingProvider);
      ref.invalidate(recentBooksProvider);
      ref.invalidate(recentlyAddedBooksProvider);
      ref.invalidate(totalBooksProvider);
      ref.invalidate(totalPagesReadProvider);
      if (imported.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Imported ${imported.length} book${imported.length == 1 ? "" : "s"}")),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import error: $e")));
    }
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allBooks = ref.watch(allBooksProvider).asData?.value ?? [];
    final continueReadingBooks = ref.watch(continueReadingProvider).asData?.value ?? [];
    final recentBooks = ref.watch(recentBooksProvider).asData?.value ?? [];
    final recentlyAdded = ref.watch(recentlyAddedBooksProvider).asData?.value ?? [];
    final collections = ref.watch(allCollectionsProvider).asData?.value ?? [];
    final totalBooks = ref.watch(totalBooksProvider).asData?.value ?? 0;
    final totalPagesRead = ref.watch(totalPagesReadProvider).asData?.value ?? 0;
    final readingGoal = ref.watch(readingGoalProvider);
    final streak = ref.watch(streakProvider).asData?.value ?? 0;
    final inProgressCount = allBooks.where((b) => b.progress > 0 && b.progress < 1).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName, style: TextStyle(fontWeight: FontWeight.bold)),
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
              _GreetingCard(streak: streak),
              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.flash_on_rounded, title: "Quick Actions"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.upload_file_rounded,
                      label: "Import Book",
                      color: AppColors.accent,
                      onTap: () => _importBooks(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.explore_rounded,
                      label: "Browse Books",
                      color: const Color(0xFF7C4DFF),
                      onTap: () => context.push(AppConstants.routeBrowse),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.folder_open_rounded,
                      label: "Collections",
                      color: const Color(0xFF34A853),
                      onTap: () => context.push(AppConstants.routeCollections),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(icon: Icons.timelapse_rounded, title: "Continue"),
                        const SizedBox(height: 8),
                        if (continueReadingBooks.isNotEmpty)
                          SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.vertical,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: continueReadingBooks.length > 3 ? 3 : continueReadingBooks.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ContinueReadingCard(book: continueReadingBooks[index]),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text("No books in progress", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(icon: Icons.history_rounded, title: "Recent"),
                        const SizedBox(height: 8),
                        if (recentBooks.isNotEmpty)
                          ...recentBooks.take(3).map((book) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RecentBookRow(book: book),
                          ))
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text("No recent books", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.bar_chart_rounded, title: "Reading Stats"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatCard(title: "Total Books", value: "$totalBooks", icon: Icons.menu_book_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(title: "Reading", value: "$inProgressCount", icon: Icons.trending_up_rounded, iconColor: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(title: "Pages Read", value: "$totalPagesRead", icon: Icons.chrome_reader_mode_rounded, iconColor: AppColors.streak),
              if (readingGoal.asData?.value case final goal? when goal.targetBooks > 0) ...[
                const SizedBox(height: 28),
                _SectionHeader(icon: Icons.flag_rounded, title: "Reading Goal"),
                const SizedBox(height: 12),
                _ReadingGoalCard(goal: goal),
              ],
              if (recentlyAdded.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(icon: Icons.add_circle_outline_rounded, title: "Recently Added"),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentlyAdded.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _SmallBookCard(book: recentlyAdded[index]),
                    ),
                  ),
                ),
              ],
              if (collections.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(icon: Icons.collections_bookmark_rounded, title: "Collections"),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final col = collections[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Icon(Icons.folder_rounded, size: 16, color: Color(col.colorValue)),
                          label: Text(col.name),
                          onPressed: () => context.push("${AppConstants.routeCollectionDetail}/${col.id}"),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (allBooks.isEmpty) ...[
                const SizedBox(height: 24),
                _buildEmptyLibrary(context, theme, ref),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: AppColors.accent.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text("Start Your Reading Journey", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("Import books from your device\nto build your library", textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _importBooks(context, ref),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text("Import"),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final int streak;
  const _GreetingCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening";
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Reader!", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.streak.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 20),
                  const SizedBox(width: 6),
                  Text("$streak", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.streak, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _SectionHeader({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
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
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(Icons.menu_book_rounded, size: 36, color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
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
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 60,
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.menu_book_rounded, color: AppColors.accent),
        ),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        trailing: book.progress > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
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
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
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
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.flag_rounded, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Text("Reading Goal", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: AppColors.border, color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${goal.currentBooks} / ${goal.targetBooks} books", style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                Text("${(progress * 100).toInt()}%", style: theme.textTheme.labelMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
