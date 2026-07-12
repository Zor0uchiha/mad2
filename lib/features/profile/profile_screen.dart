import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/user_model.dart";
import "../../data/models/book_model.dart";
import "../../data/models/review_model.dart";
import "../../data/services/auth_service.dart";
import "../../data/repositories/local_repositories.dart";

final _userProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  return ref.read(authServiceProvider).currentUser;
});

final _profileBooksProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(booksProvider).getAllBooks().length;
});

final _profileReviewsProvider = Provider.autoDispose<int>((ref) {
  return 0;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userAsync = ref.watch(_userProvider);
    final totalBooks = ref.watch(_profileBooksProvider);
    final totalReviews = ref.watch(_profileReviewsProvider);

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

          final books = ref.watch(booksProvider).getAllBooks();
          final currentlyReading = books.where((b) => b.progress > 0 && b.progress < 1).length;
          final finishedBooks = books.where((b) => b.progress >= 1).length;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    user: user,
                    booksRead: totalBooks,
                    currentlyReading: currentlyReading,
                    finishedBooks: finishedBooks,
                    reviewsCount: totalReviews,
                    streak: user.readingStreak,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: "Books"),
                        Tab(text: "Reviews"),
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
                _ReviewsTab(),
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
  final int reviewsCount;
  final int streak;

  const _ProfileHeader({
    required this.user,
    required this.booksRead,
    required this.currentlyReading,
    required this.finishedBooks,
    required this.reviewsCount,
    required this.streak,
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
            backgroundImage: user.photoUrl != null ? CachedNetworkImageProvider(user.photoUrl!) : null,
            child: user.photoUrl == null ? Icon(Icons.person_rounded, size: 48, color: colorScheme.onPrimaryContainer) : null,
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
              _StatColumn(value: booksRead.toString(), label: "Books Read"),
              _StatColumn(value: currentlyReading.toString(), label: "Reading"),
              _StatColumn(value: finishedBooks.toString(), label: "Finished"),
              _StatColumn(value: reviewsCount.toString(), label: "Reviews"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$streak day${streak == 1 ? "" : "s"}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text("Reading Streak", style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                  onPressed: () {
                    // toggle privacy
                  },
                  icon: Icon(user.isPublicProfile ? Icons.public_rounded : Icons.lock_rounded),
                  label: Text(user.isPublicProfile ? "Public" : "Private"),
                ),
              ),
            ],
          ),
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

class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
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
            onPressed: () => Navigator.pop(context),
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
          trailing: Icon(Icons.chevron_right_rounded),
          onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
        );
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text("No reviews yet", style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collections = ref.watch(collectionsProvider).getAllCollections();
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
    final listsBox = ref.watch(readingListsProvider);
    final lists = listsBox.values.toList();
    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text("No reading lists", style: theme.textTheme.bodyMedium),
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
          onTap: () {},
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
