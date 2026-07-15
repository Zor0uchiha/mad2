import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";

const _categoryChips = [
  "Trending", "Popular", "Free",
  "Programming", "AI", "Fiction",
  "Business", "Psychology", "Self Help", "Classics",
];

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(trendingBooksProvider.future),
      ref.refresh(popularBooksProvider.future),
      ref.refresh(newReleasesProvider.future),
      ref.refresh(editorsPicksProvider.future),
      ref.refresh(awardWinnersProvider.future),
      ref.refresh(publicDomainProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Browse"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              readOnly: true,
              onTap: () => context.push(AppConstants.routeSearch),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: "Search books, authors, genres...",
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categoryChips.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: AppColors.accent.withOpacity(0.15),
                    checkmarkColor: AppColors.accent,
                    onSelected: (v) {
                      setState(() => _selectedCategory = v ? cat : null);
                    },
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _selectedCategory != null
                  ? _buildCategoryView(theme, _selectedCategory!)
                  : _buildMainView(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView(ThemeData theme) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      children: [
        _buildSection(
          "Trending", Icons.trending_up_rounded, AppColors.accent,
          ref.watch(trendingBooksProvider), "trending",
        ),
        _buildSection(
          "Popular", Icons.local_fire_department_rounded, AppColors.streak,
          ref.watch(popularBooksProvider), "popular",
        ),
        _buildSection(
          "Free Books", Icons.public_rounded, const Color(0xFF00BCD4),
          ref.watch(publicDomainProvider), "public domain",
        ),
        _buildSection(
          "New Releases", Icons.new_releases_rounded, AppColors.reading,
          ref.watch(newReleasesProvider), "new releases",
        ),
        _buildSection(
          "Editor's Picks", Icons.star_rounded, AppColors.rating,
          ref.watch(editorsPicksProvider), "editor picks",
        ),
        _buildSection(
          "Award Winners", Icons.emoji_events_rounded, AppColors.finished,
          ref.watch(awardWinnersProvider), "award winners",
        ),
      ],
    );
  }

  Widget _buildCategoryView(ThemeData theme, String category) {
    final provider = categoryBooksProvider(category);
    return ref.watch(provider).when(
      data: (books) {
        if (books.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text("No $category books found", style: theme.textTheme.titleSmall),
              ],
            ),
          );
        }
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) => _BookGridCard(book: books[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error loading books")),
    );
  }

  Widget _buildSection(
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
          padding: const EdgeInsets.only(bottom: 20),
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
              SizedBox(
                height: 240,
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
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: icon, title: title, color: color),
            SizedBox(
              height: 240,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
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
      width: 140,
      child: GestureDetector(
        onTap: () => context.push("${AppConstants.routeBookDetail}?id=${Uri.encodeQueryComponent(book.id)}&source=${book.source}"),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.accent.withOpacity(0.06),
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
                  if (book.isFree || book.isPublicDomain)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.reading,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Free",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (book.averageRating != null) ...[
                  Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                  const SizedBox(width: 2),
                  Text(
                    book.averageRating!.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.rating, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                ],
                _SourceBadge(source: book.source),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.2)),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  final OnlineBookModel book;

  const _BookGridCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeBookDetail}?id=${Uri.encodeQueryComponent(book.id)}&source=${book.source}"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.accent.withOpacity(0.06),
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
                if (book.isFree || book.isPublicDomain)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.reading, borderRadius: BorderRadius.circular(6)),
                      child: const Text("Free", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (book.averageRating != null) ...[
                Icon(Icons.star_rounded, size: 12, color: AppColors.rating),
                const SizedBox(width: 2),
                Text(book.averageRating!.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.rating)),
                const SizedBox(width: 6),
              ],
              _SourceBadge(source: book.source),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.2)),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final highlight = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 10, width: 100, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 8, width: 80, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 8, width: 60, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}
