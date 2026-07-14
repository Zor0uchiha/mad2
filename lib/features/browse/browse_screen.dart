import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_theme.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";

const List<_Genre> _genres = [
  _Genre("Fiction", Color(0xFFE53935)),
  _Genre("Non-Fiction", Color(0xFF34A853)),
  _Genre("Science Fiction", Color(0xFF1A73E8)),
  _Genre("Fantasy", Color(0xFF7C4DFF)),
  _Genre("Mystery", Color(0xFFFFB300)),
  _Genre("Romance", Color(0xFFE91E63)),
  _Genre("Thriller", Color(0xFFFF6D00)),
  _Genre("Biography", Color(0xFF00BCD4)),
  _Genre("History", Color(0xFF4CAF50)),
  _Genre("Philosophy", Color(0xFFFF5722)),
];

class _Genre {
  final String name;
  final Color color;
  const _Genre(this.name, this.color);
}

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allBooks = ref.watch(allBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Browse"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppConstants.routeSearch),
          ),
        ],
      ),
      body: allBooks.when(
        data: (books) {
          final trending = (List<BookModel>.from(books)..shuffle()).take(10).toList();
          final popular = List<BookModel>.from(books)
            ..sort((a, b) => b.progress.compareTo(a.progress));
          final recent = List<BookModel>.from(books)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _SectionHeader(
                icon: Icons.trending_up_rounded,
                title: "Trending Now",
                color: AppColors.accent,
                onSeeAll: () {},
              ),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trending.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _BrowseCardLarge(book: trending[index]),
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                icon: Icons.local_fire_department_rounded,
                title: "Popular",
                color: AppColors.streak,
                onSeeAll: () {},
              ),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: popular.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _BrowseCardLarge(book: popular[index]),
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                icon: Icons.category_rounded,
                title: "Genres",
                color: AppColors.wantToRead,
                onSeeAll: () {},
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _genres.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    return _GenreCard(genre: genre);
                  },
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                icon: Icons.rate_review_rounded,
                title: "Recently Added",
                color: AppColors.rating,
                onSeeAll: () {},
              ),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _BrowseCardLarge(book: recent[index]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text("Could not load books",
                    style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text("See All"),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.only(right: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseCardLarge extends ConsumerWidget {
  final BookModel book;
  const _BrowseCardLarge({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                color: AppColors.accent.withOpacity(0.1),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 52,
                        color: AppColors.accent.withOpacity(0.4),
                      ),
                    ),
                    if (book.progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          color: AppColors.cardDark,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: book.progress.clamp(0.0, 1.0),
                            child: Container(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final _Genre genre;
  const _GenreCard({required this.genre});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Card(
        color: genre.color.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: BorderSide(
            color: genre.color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () {},
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tag_rounded,
                color: genre.color,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                genre.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: genre.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
