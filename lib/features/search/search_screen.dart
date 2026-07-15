import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";

final _recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]);

  void add(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query, ...state.where((s) => s != query)].take(10).toList();
    state = updated;
  }

  void remove(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clear() => state = [];
}

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<OnlineBookModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _showFilters = false;
  String? _sourceFilter;
  String? _languageFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery.isNotEmpty) {
        _controller.text = widget.initialQuery;
        _performSearch(_controller.text);
      } else {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () => _performSearch(query),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    ref.read(_recentSearchesProvider.notifier).add(query.trim());
    try {
      final results = await ref.read(unifiedBookRepositoryProvider).searchAll(query);
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (_) {
      setState(() {
        _results = [];
        _hasSearched = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<OnlineBookModel> get _filteredResults {
    var list = _results;
    if (_sourceFilter != null) {
      list = list.where((b) => b.source == _sourceFilter).toList();
    }
    if (_languageFilter != null) {
      list = list.where((b) => b.language == _languageFilter).toList();
    }
    return list;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'google_books': return 'Google Books';
      case 'open_library': return 'Open Library';
      case 'gutendex': return 'Gutenberg';
      default: return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentSearches = ref.watch(_recentSearchesProvider);
    final sources = _results.map((b) => b.source).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: false,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search by title, author, ISBN...",
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _controller.clear();
                _performSearch("");
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasSearched
              ? _results.isEmpty
                  ? _emptyState(theme, colorScheme)
                  : Column(
                      children: [
                        if (sources.length > 1)
                          Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _FilterChip(
                                  label: "All (${_results.length})",
                                  selected: _sourceFilter == null,
                                  onTap: () => setState(() => _sourceFilter = null),
                                ),
                                const SizedBox(width: 8),
                                for (final src in sources)
                                  _FilterChip(
                                    label: "${_sourceLabel(src)} (${_results.where((b) => b.source == src).length})",
                                    selected: _sourceFilter == src,
                                    onTap: () => setState(() => _sourceFilter = src),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _filteredResults.length,
                            itemBuilder: (context, index) {
                              final book = _filteredResults[index];
                              return _SearchResultTile(book: book);
                            },
                          ),
                        ),
                      ],
                    )
              : recentSearches.isNotEmpty
                  ? _recentSearchesView(theme, colorScheme, recentSearches)
                  : _initialView(theme, colorScheme),
    );
  }

  Widget _initialView(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text("Discover new books", style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text("Search across Google Books, Open Library,\nand Project Gutenberg",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text("No results found", style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("Try a different search term", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _recentSearchesView(ThemeData theme, ColorScheme colorScheme, List<String> searches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Searches", style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => ref.read(_recentSearchesProvider.notifier).clear(),
                child: const Text("Clear"),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searches.length,
            itemBuilder: (context, index) {
              final search = searches[index];
              return ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(search),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => ref.read(_recentSearchesProvider.notifier).remove(search),
                ),
                onTap: () {
                  _controller.text = search;
                  _performSearch(search);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final OnlineBookModel book;

  const _SearchResultTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}?source=${book.source}"),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 80,
                  child: book.thumbnail != null
                      ? CachedNetworkImage(
                          imageUrl: book.thumbnail!,
                          width: 56,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _placeholder(),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (book.averageRating != null) ...[
                          Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                          const SizedBox(width: 2),
                          Text(
                            book.averageRating!.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.rating),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _sourceLabel(book.source),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        if (book.isFree || book.isPublicDomain) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.reading),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'google_books': return 'Google';
      case 'open_library': return 'OpenLib';
      case 'gutendex': return 'Gutenberg';
      default: return source;
    }
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.accent.withOpacity(0.1),
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 24, color: AppColors.accent.withOpacity(0.4)),
      ),
    );
  }
}
