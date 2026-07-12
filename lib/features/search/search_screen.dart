import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/online_book_model.dart";
import "../../data/models/collection_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/services/online_book_service.dart";

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
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<BookModel> _localResults = [];
  List<OnlineBookModel> _onlineResults = [];
  List<CollectionModel> _collectionResults = [];
  bool _isLoading = false;
  late TabController _tabController;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(FocusNode()));
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: AppConstants.searchDebounceMs), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _localResults = [];
        _onlineResults = [];
        _collectionResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    ref.read(_recentSearchesProvider.notifier).add(query.trim());

    try {
      final local = ref.read(booksProvider).searchBooks(query);
      final online = await ref.read(onlineBookServiceProvider).searchBooks(query);
      final allCollections = ref.read(collectionsProvider).getAllCollections();
      final lowerQuery = query.toLowerCase();
      final collections = allCollections.where((c) => c.name.toLowerCase().contains(lowerQuery)).toList();

      setState(() {
        _localResults = local;
        _onlineResults = online;
        _collectionResults = collections;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _localResults = [];
        _onlineResults = [];
        _collectionResults = [];
        _hasSearched = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentSearches = ref.watch(_recentSearchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search books, authors, collections...",
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
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
      body: _hasSearched && !_isLoading && _localResults.isEmpty && _onlineResults.isEmpty && _collectionResults.isEmpty
          ? Center(
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
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasSearched
                  ? Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          tabs: [
                            Tab(text: "Local (${_localResults.length})"),
                            Tab(text: "Online (${_onlineResults.length})"),
                            Tab(text: "Collections (${_collectionResults.length})"),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _localResults.isNotEmpty
                                  ? ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _localResults.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final book = _localResults[index];
                                        return ListTile(
                                          leading: Container(
                                            width: 40,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: book.coverPath != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.asset(book.coverPath!, fit: BoxFit.cover),
                                                  )
                                                : const Icon(Icons.menu_book_rounded),
                                          ),
                                          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          trailing: Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall),
                                          onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.library_books_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                                          const SizedBox(height: 8),
                                          Text("No local books found", style: theme.textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                              _onlineResults.isNotEmpty
                                  ? ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _onlineResults.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final book = _onlineResults[index];
                                        return ListTile(
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: book.thumbnail != null
                                                ? CachedNetworkImage(imageUrl: book.thumbnail!, width: 40, height: 56, fit: BoxFit.cover)
                                                : Container(
                                                    width: 40,
                                                    height: 56,
                                                    color: colorScheme.surfaceContainerHighest,
                                                    child: const Icon(Icons.menu_book_rounded, size: 24),
                                                  ),
                                          ),
                                          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Row(
                                            children: [
                                              Expanded(child: Text(book.authors.join(", "), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              if (book.averageRating != null) ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                                                Text(book.averageRating!.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                                              ],
                                            ],
                                          ),
                                          onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}"),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_off_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                                          const SizedBox(height: 8),
                                          Text("No online books found", style: theme.textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                              _collectionResults.isNotEmpty
                                  ? ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _collectionResults.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final collection = _collectionResults[index];
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: collection.color,
                                            child: Icon(collection.iconName != null ? Icons.folder_rounded : Icons.folder_rounded, color: Colors.white),
                                          ),
                                          title: Text(collection.name),
                                          subtitle: Text("${collection.bookCount} books"),
                                          onTap: () => context.push("${AppConstants.routeCollectionDetail}/${collection.id}"),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.folder_off_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                                          const SizedBox(height: 8),
                                          Text("No collections found", style: theme.textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : recentSearches.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Recent Searches", style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  TextButton(onPressed: () => ref.read(_recentSearchesProvider.notifier).clear(), child: const Text("Clear")),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: recentSearches.length,
                                itemBuilder: (context, index) {
                                  final search = recentSearches[index];
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
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text("Search your library", style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text("Find books, authors, and collections", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
    );
  }
}
