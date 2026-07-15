import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/user_model.dart";
import "../../data/models/book_model.dart";
import "../../data/services/storage_service.dart";

final _profileUserProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  return ref.watch(localUserProvider).valueOrNull;
});

final _profileReadingDatesProvider = FutureProvider<Set<DateTime>>((ref) async {
  final box = await StorageService.openReadingProgressBox();
  final dates = <DateTime>{};
  for (final progress in box.values) {
    final d = progress.lastReadAt;
    dates.add(DateTime(d.year, d.month, d.day));
  }
  return dates;
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _togglePrivacy(UserModel user) async {
    final repo = ref.read(userRepositoryProvider);
    await repo.updateProfile(isPublicProfile: !user.isPublicProfile);
    ref.invalidate(localUserProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userAsync = ref.watch(_profileUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_rounded, size: 80, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text("Sign in to view your profile", style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push(AppConstants.routeAuth),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text("Sign In"),
                  ),
                ],
              ),
            );
          }

          final books = ref.watch(allBooksProvider).asData?.value ?? [];
          final currentlyReading = books.where((b) => b.progress > 0 && b.progress < 1).length;
          final finishedBooks = books.where((b) => b.progress >= 1).length;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    user: user,
                    booksRead: books.length,
                    currentlyReading: currentlyReading,
                    finishedBooks: finishedBooks,
                    streak: user.readingStreak,
                    onTogglePrivacy: () => _togglePrivacy(user),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: AppColors.accent,
                      tabs: const [
                        Tab(text: "Books"),
                        Tab(text: "Reviews"),
                        Tab(text: "Lists"),
                        Tab(text: "Collections"),
                        Tab(text: "Achievements"),
                      ],
                    ),
                    theme.colorScheme.surface,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _BooksTab(books: books),
                _ReviewsTab(books: books),
                _ListsTab(),
                _CollectionsTab(),
                _AchievementsTab(books: books, streak: user.readingStreak),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final int booksRead;
  final int currentlyReading;
  final int finishedBooks;
  final int streak;
  final VoidCallback onTogglePrivacy;

  const _ProfileHeader({
    required this.user,
    required this.booksRead,
    required this.currentlyReading,
    required this.finishedBooks,
    required this.streak,
    required this.onTogglePrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.accent.withOpacity(0.15),
                child: Icon(Icons.person_rounded, size: 40, color: AppColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName ?? "Reader", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(user.bio!, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatPill(value: booksRead.toString(), label: "Books", color: AppColors.accent),
              const SizedBox(width: 8),
              _StatPill(value: currentlyReading.toString(), label: "Reading", color: AppColors.reading),
              const SizedBox(width: 8),
              _StatPill(value: finishedBooks.toString(), label: "Finished", color: AppColors.finished),
              const SizedBox(width: 8),
              _StatPill(value: "$streak", label: "Streak", color: AppColors.streak),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditProfile(context),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text("Edit Profile"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTogglePrivacy,
                  icon: Icon(user.isPublicProfile ? Icons.public_rounded : Icons.lock_rounded, size: 18),
                  label: Text(user.isPublicProfile ? "Public" : "Private"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReadingHeatmap(streak: streak),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileSheet(user: user),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ReadingHeatmap extends ConsumerWidget {
  final int streak;

  const _ReadingHeatmap({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readingDates = ref.watch(_profileReadingDatesProvider).asData?.value ?? {};
    final now = DateTime.now();

    final cells = <Widget>[];
    for (int w = 0; w < 20; w++) {
      for (int d = 0; d < 7; d++) {
        final dayOffset = (19 - w) * 7 + (6 - d);
        final date = now.subtract(Duration(days: dayOffset));
        final isActive = readingDates.contains(DateTime(date.year, date.month, date.day));
        cells.add(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.streak),
              const SizedBox(width: 6),
              Text("Reading Activity", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.streak.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.streak),
                    const SizedBox(width: 3),
                    Text("$streak day${streak == 1 ? "" : "s"}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.streak)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(userRepositoryProvider);
    await repo.updateProfile(
      displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );
    ref.invalidate(localUserProvider);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Profile", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Display Name"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Bio"),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class _BooksTab extends StatelessWidget {
  final List<BookModel> books;
  const _BooksTab({required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No books yet", style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text("Start reading to build your library", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final finished = books.where((b) => b.progress >= 1).toList();
    final pages = books.fold<int>(0, (sum, b) => sum + b.pageCount);
    final genres = <String>[];
    for (final b in books) {
      for (final t in b.tags) {
        if (!genres.contains(t)) genres.add(t);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _InfoChip(icon: Icons.check_circle_rounded, value: "${finished.length} Finished", color: AppColors.finished),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.menu_book_rounded, value: "$pages Pages", color: AppColors.reading),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.category_rounded, value: "${genres.length} Genres", color: AppColors.rating),
          ],
        ),
        const SizedBox(height: 16),
        Text("Reading History", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...books.map((book) => _HistoryItem(book: book)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _InfoChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final BookModel book;

  const _HistoryItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 48,
            color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.06),
            child: hasCover
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded, size: 20, color: AppColors.accent.withOpacity(0.3)))
                : Icon(Icons.menu_book_rounded, size: 20, color: AppColors.accent.withOpacity(0.3)),
          ),
        ),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text("${(book.progress * 100).toInt()}% complete", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
        trailing: Text(book.progress >= 1 ? "Finished" : "Reading", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: book.progress >= 1 ? AppColors.finished : AppColors.reading)),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final List<BookModel> books;
  const _ReviewsTab({required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text("No Reviews Yet", style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text("Share your thoughts on books you've read", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ListsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listsBoxAsync = ref.watch(readingListsBoxProvider);
    final lists = listsBoxAsync.asData?.value?.values.toList() ?? [];
    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No Reading Lists", style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: () => context.push(AppConstants.routeReadingLists),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Create List"),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = lists[index];
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Icon(Icons.list_rounded, color: AppColors.accent, size: 20),
            ),
            title: Text(list.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text("${list.bookCount} books", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push(AppConstants.routeReadingLists),
          ),
        );
      },
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collections = ref.watch(allCollectionsProvider).asData?.value ?? [];
    if (collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No Collections", style: theme.textTheme.titleSmall),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: collections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = collections[index];
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: c.color, radius: 18, child: Icon(Icons.folder_rounded, color: Colors.white, size: 18)),
            title: Text(c.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text("${c.bookCount} books", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push("${AppConstants.routeCollectionDetail}/${c.id}"),
          ),
        );
      },
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  final List<BookModel> books;
  final int streak;

  const _AchievementsTab({required this.books, required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finishedCount = books.where((b) => b.progress >= 1).length;
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.pageCount);

    final achievements = [
      _Achievement(icon: Icons.menu_book_rounded, label: "First Book", description: "Read your first book", unlocked: finishedCount >= 1),
      _Achievement(icon: Icons.library_books_rounded, label: "Bookworm", description: "Read 5 books", unlocked: finishedCount >= 5),
      _Achievement(icon: Icons.school_rounded, label: "Scholar", description: "Read 10 books", unlocked: finishedCount >= 10),
      _Achievement(icon: Icons.local_fire_department_rounded, label: "On Fire", description: "7-day reading streak", unlocked: streak >= 7),
      _Achievement(icon: Icons.whatshot_rounded, label: "Unstoppable", description: "30-day reading streak", unlocked: streak >= 30),
      _Achievement(icon: Icons.chrome_reader_mode_rounded, label: "Page Turner", description: "Read 1000 pages", unlocked: totalPages >= 1000),
    ];

    if (achievements.where((a) => a.unlocked).isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No Achievements Yet", style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text("Keep reading to unlock achievements!", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: achievements.length,
      itemBuilder: (_, i) {
        final a = achievements[i];
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(a.unlocked ? 0.5 : 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icon, size: 28, color: a.unlocked ? AppColors.accent : theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 8),
              Text(a.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: a.unlocked ? null : theme.colorScheme.onSurfaceVariant.withOpacity(0.4))),
              const SizedBox(height: 2),
              Text(a.description, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

class _Achievement {
  final IconData icon;
  final String label;
  final String description;
  final bool unlocked;

  const _Achievement({
    required this.icon,
    required this.label,
    required this.description,
    required this.unlocked,
  });
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
