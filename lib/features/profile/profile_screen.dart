import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/user_model.dart";
import "../../data/models/book_model.dart";

final _profileUserProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  return ref.watch(localUserProvider).valueOrNull;
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
            radius: 48,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.person_rounded, size: 48, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 12),
          Text(user.displayName ?? "Reader", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(user.bio!, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatColumn(value: booksRead.toString(), label: "Books"),
              _StatColumn(value: currentlyReading.toString(), label: "Reading"),
              _StatColumn(value: finishedBooks.toString(), label: "Finished"),
              _StatColumn(value: "$streak", label: "Streak"),
            ],
          ),
          const SizedBox(height: 16),
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

class _ReadingCalendar extends StatelessWidget {
  final int streak;

  const _ReadingCalendar({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(28, (i) => now.subtract(Duration(days: 27 - i)));
    final today = now.weekday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text("Reading Activity", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: days.map((day) {
                final isActive = day.day % 3 == 0 && day.isBefore(now);
                final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isToday
                        ? theme.colorScheme.primary
                        : isActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      "${day.day}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
        return ListTile(
          leading: Container(
            width: 36,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.menu_book_rounded, size: 24),
          ),
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${book.author} \u2022 ${(book.progress * 100).toInt()}%"),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: a.unlocked ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                a.icon,
                color: a.unlocked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(a.label, style: TextStyle(fontWeight: a.unlocked ? FontWeight.w600 : FontWeight.normal)),
            subtitle: Text(a.description, style: theme.textTheme.bodySmall),
            trailing: Icon(
              a.unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
              color: a.unlocked ? Colors.green : theme.colorScheme.onSurfaceVariant,
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
        return ListTile(
          leading: CircleAvatar(backgroundColor: c.color, child: Icon(Icons.folder_rounded, color: Colors.white)),
          title: Text(c.name),
          subtitle: Text("${c.bookCount} books"),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push("${AppConstants.routeCollectionDetail}/${c.id}"),
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
        return ListTile(
          leading: CircleAvatar(child: Icon(Icons.list_rounded)),
          title: Text(list.title),
          subtitle: Text("${list.bookCount} books"),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(AppConstants.routeReadingLists),
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
