import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:hive_flutter/hive_flutter.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/reading_goal_model.dart";
import "../../data/services/storage_service.dart";
import "../../data/services/import_service.dart";
import "../../data/repositories/local_repositories.dart";
import "widgets/continue_reading_card.dart";

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

final recommendedBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final books = await repo.getAllBooks();
  if (books.isEmpty) return [];
  final favorites = books.where((b) => b.isFavorite).toList();
  if (favorites.length >= 3) return favorites.take(6).toList();
  books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return books.take(6).toList();
});

const _dailyQuotes = [
  "The man who does not read has no advantage over the man who cannot read.",
  "A reader lives a thousand lives before he dies.",
  "Books are a uniquely portable magic.",
  "So many books, so little time.",
  "The more that you read, the more things you will know.",
  "Reading is to the mind what exercise is to the body.",
  "A room without books is like a body without a soul.",
  "Today a reader, tomorrow a leader.",
  "Reading gives us someplace to go when we have to stay where we are.",
];

String _dailyQuote() {
  final now = DateTime.now();
  final index = (now.month * 31 + now.day) % _dailyQuotes.length;
  return _dailyQuotes[index];
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return "Good Morning";
  if (hour < 17) return "Good Afternoon";
  return "Good Evening";
}

Future<void> _refreshDashboard(WidgetRef ref) async {
  await Future.wait([
    ref.refresh(allBooksProvider.future),
    ref.refresh(continueReadingProvider.future),
    ref.refresh(recentBooksProvider.future),
    ref.refresh(recentlyAddedBooksProvider.future),
    ref.refresh(totalBooksProvider.future),
    ref.refresh(totalPagesReadProvider.future),
    ref.refresh(recommendedBooksProvider.future),
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
      ref.invalidate(recommendedBooksProvider);
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
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    final allBooks = ref.watch(allBooksProvider).asData?.value ?? [];
    final continueReadingBooks = ref.watch(continueReadingProvider).asData?.value ?? [];
    final recentlyAdded = ref.watch(recentlyAddedBooksProvider).asData?.value ?? [];
    final recommendedBooks = ref.watch(recommendedBooksProvider).asData?.value ?? [];
    final readingGoal = ref.watch(readingGoalProvider);
    final streak = ref.watch(streakProvider).asData?.value ?? 0;
    final user = ref.watch(localUserProvider).asData?.value;
    final userName = user?.displayName ?? "Reader";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppConstants.routeSearch),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppConstants.routeNotifications),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreetingHeroCard(
                greeting: _greeting(),
                userName: userName,
                streak: streak,
                readingGoal: readingGoal.asData?.value,
                quote: _dailyQuote(),
              ),
              const SizedBox(height: 24),
              if (continueReadingBooks.isNotEmpty) ...[
                _SectionHeader(title: "Continue Reading"),
                const SizedBox(height: 16),
                SizedBox(
                  height: 290,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: continueReadingBooks.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ContinueReadingCard(book: continueReadingBooks[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              _SectionHeader(title: "Quick Actions"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.upload_file_rounded,
                      label: "Import",
                      color: AppColors.accent,
                      onTap: () => _importBooks(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.explore_rounded,
                      label: "Browse",
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.list_alt_rounded,
                      label: "Lists",
                      color: const Color(0xFF1A73E8),
                      onTap: () => context.push(AppConstants.routeReadingLists),
                    ),
                  ),
                ],
              ),
              if (recentlyAdded.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(
                  title: "Recently Added",
                  showSeeAll: true,
                  onSeeAll: () => context.push(AppConstants.routeLibrary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentlyAdded.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _SmallBookCoverCard(book: recentlyAdded[index]),
                    ),
                  ),
                ),
              ],
              if (recommendedBooks.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionHeader(title: "Recommended For You"),
                const SizedBox(height: 16),
                SizedBox(
                  height: 340,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recommendedBooks.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final book = recommendedBooks[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _RecommendationCard(
                          book: book,
                          onSave: () async {
                            final repo = ref.read(bookRepositoryProvider);
                            final updated = book.copyWith(isFavorite: !book.isFavorite);
                            await repo.updateBook(updated);
                            ref.invalidate(allBooksProvider);
                            ref.invalidate(recommendedBooksProvider);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (allBooks.isEmpty) ...[
                const SizedBox(height: 16),
                _buildEmptyLibrary(context, theme, cardColor, ref),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary(
    BuildContext context,
    ThemeData theme,
    Color cardColor,
    WidgetRef ref,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded, size: 64, color: AppColors.accent.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            "Start Your Reading Journey",
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Import books from your device\nto build your library",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _importBooks(context, ref),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text("Import"),
          ),
        ],
      ),
    );
  }
}

class _GreetingHeroCard extends StatelessWidget {
  final String greeting;
  final String userName;
  final int streak;
  final ReadingGoalModel? readingGoal;
  final String quote;

  const _GreetingHeroCard({
    required this.greeting,
    required this.userName,
    required this.streak,
    this.readingGoal,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$greeting, $userName \u{1F44B}",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.streak.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "$streak Day Streak",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.streak,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (readingGoal != null && readingGoal!.targetBooks > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  "Reading Goal",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  "${readingGoal!.currentBooks} / ${readingGoal!.targetBooks} books",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: readingGoal!.overallProgress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, color: AppColors.accent.withOpacity(0.5), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    this.showSeeAll = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (showSeeAll && onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("See All"),
          ),
      ],
    );
  }
}

class _SmallBookCoverCard extends StatelessWidget {
  final BookModel book;

  const _SmallBookCoverCard({required this.book});

  bool get _isNew {
    return DateTime.now().difference(book.createdAt).inDays < 7;
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 110,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: hasCover
                    ? Image.file(
                        File(book.coverPath!),
                        width: 110,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
          ),
          if (_isNew)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 110,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 32, color: AppColors.accent.withOpacity(0.4)),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onSave;

  const _RecommendationCard({
    required this.book,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    final genre = book.tags.isNotEmpty ? book.tags.first : "General";

    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.1),
                  ),
                  child: hasCover
                      ? Image.file(
                          File(book.coverPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                        const SizedBox(width: 2),
                        Text(
                          "4.5",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rating,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.description ?? "No description available.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: onSave,
                        icon: Icon(
                          book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 20,
                          color: book.isFavorite ? AppColors.accent : AppColors.textSecondary,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.3)),
    );
  }
}
