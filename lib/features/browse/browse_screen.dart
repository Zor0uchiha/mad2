import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";

const _categories = [
  _CategorySection("Programming & Technology", Icons.code_rounded, Color(0xFF34A853)),
  _CategorySection("AI & Machine Learning", Icons.auto_awesome_rounded, Color(0xFF7C4DFF)),
  _CategorySection("Business", Icons.business_rounded, Color(0xFF1A73E8)),
  _CategorySection("Self Help", Icons.self_improvement_rounded, Color(0xFFFF6D00)),
  _CategorySection("Fiction", Icons.auto_stories_rounded, Color(0xFFE53935)),
];

class _CategorySection {
  final String name;
  final IconData icon;
  final Color color;
  const _CategorySection(this.name, this.icon, this.color);
}

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            _buildSection(
              context, ref, "Trending Books",
              Icons.trending_up_rounded, AppColors.accent,
              ref.watch(trendingBooksProvider), "trending",
            ),
            _buildSection(
              context, ref, "Popular Books",
              Icons.local_fire_department_rounded, AppColors.streak,
              ref.watch(popularBooksProvider), "popular",
            ),
            _buildSection(
              context, ref, "New Releases",
              Icons.new_releases_rounded, AppColors.reading,
              ref.watch(newReleasesProvider), "new releases",
            ),
            _buildSection(
              context, ref, "Editor's Picks",
              Icons.star_rounded, AppColors.rating,
              ref.watch(editorsPicksProvider), "editor picks",
            ),
            _buildSection(
              context, ref, "Award Winners",
              Icons.emoji_events_rounded, AppColors.finished,
              ref.watch(awardWinnersProvider), "award winners",
            ),
            _buildSection(
              context, ref, "Public Domain Books",
              Icons.public_rounded, const Color(0xFF00BCD4),
              ref.watch(publicDomainProvider), "public domain",
            ),
            for (final cat in _categories)
              _buildSection(
                context, ref, cat.name, cat.icon, cat.color,
                ref.watch(categoryBooksProvider(cat.name)), cat.name,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.refresh(trendingBooksProvider.future),
      ref.refresh(popularBooksProvider.future),
      ref.refresh(newReleasesProvider.future),
      ref.refresh(editorsPicksProvider.future),
      ref.refresh(awardWinnersProvider.future),
      ref.refresh(publicDomainProvider.future),
      for (final cat in _categories)
        ref.refresh(categoryBooksProvider(cat.name).future),
    ]);
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon,
    Color color,
    AsyncValue<List<OnlineBookModel>> books,
    String searchQuery,
  ) {
    return books.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: icon, title: title, color: color,
                onSeeAll: () {
                  final encoded = Uri.encodeComponent(searchQuery);
                  context.push("${AppConstants.routeSearch}?q=$encoded");
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _BrowseBookCard(book: list[index]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: icon, title: title, color: color),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => _ShimmerCard(),
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.onSeeAll,
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
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (onSeeAll != null)
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

class _BrowseBookCard extends StatelessWidget {
  final OnlineBookModel book;

  const _BrowseBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: GestureDetector(
        onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}?source=${book.source}"),
        child: Card(
          color: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.accent.withOpacity(0.08),
                  child: book.thumbnail != null
                      ? CachedNetworkImage(
                          imageUrl: book.thumbnail!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _coverPlaceholder(),
                          errorWidget: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(
                  book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Row(
                  children: [
                    if (book.averageRating != null) ...[
                      Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                      const SizedBox(width: 2),
                      Text(
                        book.averageRating!.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.rating),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _SourceBadge(source: book.source),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 48, color: AppColors.accent.withOpacity(0.3)),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      'google_books' => 'Google',
      'open_library' => 'OpenLib',
      'gutendex' => 'Gutenberg',
      _ => source,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(height: 8, width: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(height: 8, width: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
