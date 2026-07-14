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
    _tabController = TabController(length: 4, vsync: this);
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
                      tabs: const [
                        Tab(text: "Books"),
                        Tab(text: "Achievements"),
                        Tab(text: "Collections"),
                        Tab(text: "Lists"),
                      ],
                    ),
                    colorScheme.surface,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _BooksTab(books: books),
                _AchievementsTab(books: books, streak: user.readingStreak),
                _CollectionsTab(),
                _ListsTab(),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.cardDark,
            child: Icon(Icons.person_rounded, size: 52, color: AppColors.accent),
          ),
          const SizedBox(height: 12),
          Text(user.displayName ?? "Reader", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(user.bio!, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(value: booksRead.toString(), label: "Books"),
                _StatColumn(value: currentlyReading.toString(), label: "Reading"),
                _StatColumn(value: finishedBooks.toString(), label: "Finished"),
                _StatColumn(value: "$streak", label: "Streak"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditProfile(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text("Edit Profile"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTogglePrivacy,
                  icon: Icon(user.isPublicProfile ? Icons.public_rounded : Icons.lock_rounded),
                  label: Text(user.isPublicProfile ? "Public" : "Private"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReadingCalendar(streak: streak),
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

class _ReadingCalendar extends ConsumerWidget {
  final int streak;

  const _ReadingCalendar({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readingDates = ref.watch(_profileReadingDatesProvider).asData?.value ?? {};
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    final dayCells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      dayCells.add(const SizedBox(width: 28, height: 28));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(now.year, now.month, day);
      final isToday = date == DateTime(now.year, now.month, now.day);
      final isFuture = date.isAfter(now);
      final isActive = readingDates.contains(date);

      Color cellColor;
      Color textColor;
      FontWeight fontWeight;

      if (isToday) {
        cellColor = AppColors.accent;
        textColor = Colors.white;
        fontWeight = FontWeight.bold;
      } else if (isFuture) {
        cellColor = Colors.transparent;
        textColor = AppColors.textSecondary.withOpacity(0.3);
        fontWeight = FontWeight.normal;
      } else if (isActive) {
        cellColor = AppColors.accent.withOpacity(0.3);
        textColor = AppColors.textPrimary;
        fontWeight = FontWeight.normal;
      } else {
        cellColor = AppColors.border;
        textColor = AppColors.textSecondary;
        fontWeight = FontWeight.normal;
      }

      dayCells.add(Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text("$day", style: TextStyle(fontSize: 10, fontWeight: fontWeight, color: textColor))),
      ));
    }

    final rows = <Widget>[];
    for (int i = 0; i < dayCells.length; i += 7) {
      final end = i + 7 > dayCells.length ? dayCells.length : i + 7;
      final rowCells = dayCells.sublist(i, end);
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 28, height: 28));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: rowCells),
      ));
    }

    const weekdays = ["S", "M", "T", "W", "T", "F", "S"];
    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((d) => SizedBox(
        width: 28,
        child: Center(child: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
      )).toList(),
    );

    const monthNames = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(monthNames[now.month - 1], style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.streak.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.streak),
                    const SizedBox(width: 4),
                    Text("$streak day${streak == 1 ? "" : "s"}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.streak)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          headerRow,
          const SizedBox(height: 8),
          ...rows,
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

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
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
            Icon(Icons.menu_book_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text("No books in your library", style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 40,
              height: 52,
              decoration: BoxDecoration(
                color: book.coverPath != null && book.coverPath!.isNotEmpty ? Colors.transparent : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: book.coverPath != null && book.coverPath!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, size: 24)),
                    )
                  : const Icon(Icons.menu_book_rounded, size: 24),
            ),
            title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${book.author} \u2022 ${(book.progress * 100).toInt()}%", style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book.progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
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
      _Achievement(
        icon: Icons.menu_book_rounded,
        label: "First Book",
        description: "Read your first book",
        unlocked: finishedCount >= 1,
      ),
      _Achievement(
        icon: Icons.library_books_rounded,
        label: "Bookworm",
        description: "Read 5 books",
        unlocked: finishedCount >= 5,
      ),
      _Achievement(
        icon: Icons.school_rounded,
        label: "Scholar",
        description: "Read 10 books",
        unlocked: finishedCount >= 10,
      ),
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        label: "On Fire",
        description: "7-day reading streak",
        unlocked: streak >= 7,
      ),
      _Achievement(
        icon: Icons.whatshot_rounded,
        label: "Unstoppable",
        description: "30-day reading streak",
        unlocked: streak >= 30,
      ),
      _Achievement(
        icon: Icons.chrome_reader_mode_rounded,
        label: "Page Turner",
        description: "Read 1000 pages",
        unlocked: totalPages >= 1000,
      ),
    ];

    if (achievements.where((a) => a.unlocked).isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text("No achievements yet", style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text("Keep reading to unlock achievements!", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: achievements.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: a.unlocked ? AppColors.accent.withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                a.icon,
                color: a.unlocked ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(a.label, style: TextStyle(fontWeight: a.unlocked ? FontWeight.w600 : FontWeight.normal)),
            subtitle: Text(a.description, style: theme.textTheme.bodySmall),
            trailing: Icon(
              a.unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
              color: a.unlocked ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        );
      }).toList(),
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
            Icon(Icons.folder_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text("No collections", style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final c = collections[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(backgroundColor: c.color, child: Icon(Icons.folder_rounded, color: Colors.white)),
            title: Text(c.name),
            subtitle: Text("${c.bookCount} books"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push("${AppConstants.routeCollectionDetail}/${c.id}"),
          ),
        );
      },
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
            Icon(Icons.list_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text("No reading lists", style: theme.textTheme.bodyMedium),
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
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Icon(Icons.list_rounded, color: AppColors.accent),
            ),
            title: Text(list.title),
            subtitle: Text("${list.bookCount} books"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppConstants.routeReadingLists),
          ),
        );
      },
    );
  }
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
