import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";
import "../../data/services/online_book_service.dart";

final _searchResultsProvider = FutureProvider.autoDispose.family<List<OnlineBookModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(onlineBookServiceProvider).searchBooks(query);
});

final _trendingProvider = FutureProvider.autoDispose<List<OnlineBookModel>>((ref) async {
  final service = ref.read(onlineBookServiceProvider);
  final fiction = await service.searchBooks("fiction");
  final trending = await service.searchBooks("bestsellers");
  final merged = {...fiction, ...trending}.toList();
  merged.shuffle();
  return merged.take(10).toList();
});

const List<String> _categories = [
  "Fiction", "Non-Fiction", "Science Fiction", "Fantasy", "Mystery",
  "Romance", "Thriller", "Biography", "History", "Philosophy", "Poetry", "Horror",
];

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  String? _selectedCategory;

  void _onSearch(String value) {
    setState(() => _query = value);
  }

  void _onCategoryTap(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
      _query = _selectedCategory ?? "";
      _searchController.text = _query;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resultsAsync = ref.watch(_searchResultsProvider(_query));
    final trendingAsync = ref.watch(_trendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Browse Books")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: "Search books, authors...",
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch("");
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => _onCategoryTap(cat),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _query.isNotEmpty
                ? resultsAsync.when(
                    data: (books) => books.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: colorScheme.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text("No results found", style: theme.textTheme.titleMedium),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: books.length,
                            itemBuilder: (context, index) {
                              final book = books[index];
                              return _BookGridCard(book: book);
                            },
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text("Error: $e")),
                  )
                : trendingAsync.when(
                    data: (trending) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up_rounded, color: AppColors.streak),
                            const SizedBox(width: 8),
                            Text("Trending Now", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: trending.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final book = trending[index];
                              return _TrendingCard(book: book);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.explore_rounded, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text("Popular Categories", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.take(8).map((cat) {
                            return ActionChip(
                              avatar: Icon(Icons.tag_rounded, size: 18),
                              label: Text(cat),
                              onPressed: () => _onCategoryTap(cat),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text("Could not load trending books")),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookGridCard extends ConsumerWidget {
  final OnlineBookModel book;
  const _BookGridCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}"),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: book.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: book.thumbnail!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded, size: 40)),
                      errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded, size: 40)),
                    )
                  : Container(color: theme.colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.menu_book_rounded, size: 40))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (book.averageRating != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.rating),
                    const SizedBox(width: 4),
                    Text(book.averageRating!.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                    if (book.ratingsCount != null) ...[
                      const SizedBox(width: 4),
                      Text("(${book.ratingsCount})", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TrendingCard extends ConsumerWidget {
  final OnlineBookModel book;
  const _TrendingCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: book.thumbnail != null
                    ? CachedNetworkImage(
                        imageUrl: book.thumbnail!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded)),
                        errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded)),
                      )
                    : Container(color: theme.colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.menu_book_rounded))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Text(
                  book.authors.isNotEmpty ? book.authors.first : "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
