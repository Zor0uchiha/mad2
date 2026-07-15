import "dart:async";
import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_theme.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/models/collection_model.dart";
import "../../data/services/share_service.dart";
import "../../data/services/import_service.dart";

enum LibrarySort {
  titleAsc("Title A-Z"),
  authorAsc("Author"),
  recent("Recent"),
  progress("Progress");

  final String label;
  const LibrarySort(this.label);
}

enum _BookFilter { all, favorites, reading, finished, recentlyAdded }

enum _ViewMode { grid, list, compact }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<BookModel> _filteredBooks = [];
  _ViewMode _viewMode = _ViewMode.grid;
  LibrarySort _currentSort = LibrarySort.recent;
  _BookFilter _selectedFilter = _BookFilter.all;
  Timer? _debounce;
  bool _isLoading = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(bookRepositoryProvider);
      final query = _searchController.text.trim();

      List<BookModel> books;
      if (query.isNotEmpty) {
        books = await repo.searchBooks(query);
      } else {
        books = await repo.getAllBooks();
      }

      books = _applyFilter(books);
      _applySort(books);

      if (mounted) {
        setState(() {
          _filteredBooks = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BookModel> _applyFilter(List<BookModel> books) {
    switch (_selectedFilter) {
      case _BookFilter.all:
        return books;
      case _BookFilter.favorites:
        return books.where((b) => b.isFavorite).toList();
      case _BookFilter.reading:
        return books.where((b) => b.progress > 0 && b.progress < 1.0).toList();
      case _BookFilter.finished:
        return books.where((b) => b.progress >= 1.0).toList();
      case _BookFilter.recentlyAdded:
        books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return books;
    }
  }

  void _applySort(List<BookModel> books) {
    switch (_currentSort) {
      case LibrarySort.titleAsc:
        books.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.authorAsc:
        books.sort((a, b) => a.author.compareTo(b.author));
      case LibrarySort.recent:
        books.sort(
          (a, b) =>
              (b.lastOpenedAt ?? b.createdAt)
                  .compareTo(a.lastOpenedAt ?? a.createdAt),
        );
      case LibrarySort.progress:
        books.sort((a, b) => b.progress.compareTo(a.progress));
    }
  }

  void _setSort(LibrarySort sort) {
    setState(() => _currentSort = sort);
    _applySort(_filteredBooks);
    if (mounted) setState(() {});
  }

  void _setFilter(_BookFilter filter) {
    setState(() => _selectedFilter = filter);
    _loadBooks();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      _loadBooks,
    );
  }

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Collection"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Collection Name"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description (optional)"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final collection = CollectionModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                colorValue: AppColors.accent.value,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await ref.read(collectionsProvider).addCollection(collection);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Collection "${collection.name}" created')),
                );
                ref.invalidate(allCollectionsProvider);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      descController.dispose();
    });
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      ref.refresh(allBooksProvider.future),
      ref.refresh(continueReadingProvider.future),
      ref.refresh(recentBooksProvider.future),
      ref.refresh(recentlyAddedBooksProvider.future),
      ref.refresh(totalBooksProvider.future),
      ref.refresh(totalPagesReadProvider.future),
    ]);
  }

  Future<void> _importBooks() async {
    setState(() => _isImporting = true);
    try {
      final repo = ref.read(bookRepositoryProvider);
      final service = ImportService(repo);
      final imported = await service.pickAndImportBooks();
      await _refreshDashboard();
      if (mounted && imported.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Imported ${imported.length} book${imported.length == 1 ? "" : "s"}"),
            duration: const Duration(seconds: 3),
          ),
        );
        _loadBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _toggleFavorite(BookModel book) async {
    final updated = book.copyWith(isFavorite: !book.isFavorite);
    await ref.read(bookRepositoryProvider).updateBook(updated);
    _loadBooks();
  }

  void _showBookActions(BookModel book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                book.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("Open Book"),
              onTap: () {
                Navigator.pop(ctx);
                context.push("${AppConstants.routeReader}/${book.id}");
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Metadata"),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark),
              title: const Text("Add/Remove from Collections"),
              onTap: () {
                Navigator.pop(ctx);
                _showCollectionPicker(book);
              },
            ),
            ListTile(
              leading: Icon(book.isFavorite ? Icons.favorite : Icons.favorite_border),
              title: Text(book.isFavorite ? "Remove from Favorites" : "Mark as Favorite"),
              onTap: () {
                Navigator.pop(ctx);
                _toggleFavorite(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share"),
              onTap: () {
                Navigator.pop(ctx);
                ShareService.shareBook(book.title, book.author);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Remove from Library",
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleListAction(BookModel book, String action) {
    switch (action) {
      case "open":
        context.push("${AppConstants.routeReader}/${book.id}");
      case "edit":
        _showEditDialog(book);
      case "collections":
        _showCollectionPicker(book);
      case "favorite":
        _toggleFavorite(book);
      case "share":
        ShareService.shareBook(book.title, book.author);
      case "delete":
        _confirmDelete(book);
    }
  }

  Future<void> _showEditDialog(BookModel book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final descController = TextEditingController(text: book.description ?? "");
    final isbnController = TextEditingController(text: book.isbn ?? "");
    final publisherController = TextEditingController(text: book.publisher ?? "");
    final langController = TextEditingController(text: book.language ?? "");
    final tagsController = TextEditingController(text: book.tags.join(", "));

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Metadata"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(labelText: "Author"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: isbnController,
                decoration: const InputDecoration(labelText: "ISBN"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: publisherController,
                decoration: const InputDecoration(labelText: "Publisher"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: langController,
                decoration: const InputDecoration(labelText: "Language"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: "Tags (comma-separated)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              "title": titleController.text,
              "author": authorController.text,
              "description": descController.text,
              "isbn": isbnController.text,
              "publisher": publisherController.text,
              "language": langController.text,
              "tags": tagsController.text,
            }),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      final tags = result["tags"]!
          .split(",")
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final updated = book.copyWith(
        title: result["title"],
        author: result["author"],
        description: result["description"]!.isEmpty ? null : result["description"],
        isbn: result["isbn"]!.isEmpty ? null : result["isbn"],
        publisher: result["publisher"]!.isEmpty ? null : result["publisher"],
        language: result["language"]!.isEmpty ? null : result["language"],
        tags: tags,
      );
      await ref.read(bookRepositoryProvider).updateBook(updated);
      _loadBooks();
    }

    titleController.dispose();
    authorController.dispose();
    descController.dispose();
    isbnController.dispose();
    publisherController.dispose();
    langController.dispose();
    tagsController.dispose();
  }

  Future<void> _showCollectionPicker(BookModel book) async {
    final collections = await ref.read(collectionsProvider).getAllCollections();
    final selectedIds = Set<String>.from(book.collectionIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Collections"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: collections.map((c) {
                final isChecked = selectedIds.contains(c.id);
                return CheckboxListTile(
                  title: Text(c.name),
                  subtitle: Text("${c.bookCount} books"),
                  value: isChecked,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedIds.add(c.id);
                      } else {
                        selectedIds.remove(c.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selectedIds),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updated = book.copyWith(collectionIds: result.toList());
      await ref.read(bookRepositoryProvider).updateBook(updated);

      for (final collection in collections) {
        final isNowSelected = result.contains(collection.id);
        final wasSelected = book.collectionIds.contains(collection.id);
        if (isNowSelected && !wasSelected) {
          await ref.read(collectionsProvider).addBookToCollection(collection.id, book.id);
        } else if (!isNowSelected && wasSelected) {
          await ref.read(collectionsProvider).removeBookFromCollection(collection.id, book.id);
        }
      }

      _loadBooks();
    }
  }

  Future<void> _confirmDelete(BookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Book"),
        content: Text(
          'Are you sure you want to remove "${book.title}" from your library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(bookRepositoryProvider).deleteBook(book.id);
      _loadBooks();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final books = _filteredBooks;
    final continueBooks = books.where((b) => b.progress > 0 && b.progress < 1).toList();
    final recentlyAdded = _selectedFilter == _BookFilter.all ? books.where((b) => DateTime.now().difference(b.createdAt).inDays < 14).toList() : [];
    final favorites = _selectedFilter == _BookFilter.all ? books.where((b) => b.isFavorite).toList() : [];
    final finished = _selectedFilter == _BookFilter.all ? books.where((b) => b.progress >= 1).toList() : [];

    final hasSections = _selectedFilter == _BookFilter.all && _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Library"),
        actions: [
          PopupMenuButton<LibrarySort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: "Sort",
            onSelected: _setSort,
            itemBuilder: (context) => LibrarySort.values.map(
              (sort) => PopupMenuItem(
                value: sort,
                child: Row(
                  children: [
                    if (_currentSort == sort)
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(sort.label),
                  ],
                ),
              ),
            ).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: "Search by title, author, or tags...",
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
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip("All", _BookFilter.all),
                      _buildFilterChip("Reading", _BookFilter.reading),
                      _buildFilterChip("Favorites", _BookFilter.favorites),
                      _buildFilterChip("Finished", _BookFilter.finished),
                      _buildFilterChip("Recent", _BookFilter.recentlyAdded),
                      const SizedBox(width: 4),
                      ActionChip(
                        avatar: const Icon(Icons.folder_rounded, size: 16),
                        label: const Text("Collection"),
                        onPressed: () => _showCreateCollectionDialog(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _viewModeButton(Icons.grid_view_rounded, _ViewMode.grid),
                      _viewModeButton(Icons.list_rounded, _ViewMode.list),
                      _viewModeButton(Icons.view_stream_rounded, _ViewMode.compact),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Text(
                    "${books.length} book${books.length == 1 ? "" : "s"}",
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    _currentSort.label,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading && books.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadBooks,
                    child: books.isEmpty
                        ? _buildEmptyState(theme, colorScheme)
                        : _buildBookSections(theme, colorScheme, books, continueBooks, recentlyAdded, favorites, finished, hasSections),
                  ),
          ),
        ],
      ),
      floatingActionButton: _isImporting
          ? FloatingActionButton(
              onPressed: null,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : FloatingActionButton(
              onPressed: _importBooks,
              tooltip: "Import books",
              child: const Icon(Icons.upload_file_rounded),
            ),
    );
  }

  Widget _viewModeButton(IconData icon, _ViewMode mode) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isSelected ? AppColors.accent : null),
      ),
    );
  }

  Widget _buildFilterChip(String label, _BookFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        selected: isSelected,
        onSelected: (_) => _setFilter(filter),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Icon(Icons.menu_book_rounded, size: 80, color: AppColors.accent.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(
                "Your Library is Empty",
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Import your first book to start building your personal digital bookshelf",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _importBooks,
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                label: const Text("Import Book"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppConstants.routeBrowse),
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text("Browse Online Books"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookSections(
    ThemeData theme,
    ColorScheme colorScheme,
    List<BookModel> books,
    List<BookModel> continueBooks,
    List<BookModel> recentlyAdded,
    List<BookModel> favorites,
    List<BookModel> finished,
    bool hasSections,
  ) {
    if (!hasSections) {
      return _buildBookGrid(theme, books);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (continueBooks.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader("Continue Reading", () {})),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueBooks.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSectionBookCard(continueBooks[i], theme),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        if (recentlyAdded.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader("Recently Added", null)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentlyAdded.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSectionBookCard(recentlyAdded[i], theme),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        if (favorites.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader("Favorites", null)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSectionBookCard(favorites[i], theme),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        if (finished.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader("Finished", null)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: finished.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildSectionBookCard(finished[i], theme),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        _sectionHeader("All Books", null),
        _buildBookGridSliver(theme, books),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _sectionHeader(String title, VoidCallback? onSeeAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("See All", style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionBookCard(BookModel book, ThemeData theme) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    final status = book.progress >= 1 ? "Finished" : book.progress > 0 ? "${(book.progress * 100).toInt()}%" : null;

    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      onLongPress: () => _showBookActions(book),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 130,
                    height: 180,
                    color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.08),
                    child: hasCover
                        ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverPlaceholder())
                        : _coverPlaceholder(),
                  ),
                ),
                if (status != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: book.progress >= 1 ? AppColors.finished : AppColors.reading,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (book.isFavorite)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 14),
                    ),
                  ),
                if (book.progress > 0 && book.progress < 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      child: LinearProgressIndicator(
                        value: book.progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: Colors.black.withOpacity(0.2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid(ThemeData theme, List<BookModel> books) {
    switch (_viewMode) {
      case _ViewMode.grid:
        return _buildGridView(theme, books);
      case _ViewMode.list:
        return _buildListView(theme, books);
      case _ViewMode.compact:
        return _buildCompactView(theme, books);
    }
  }

  Widget _buildBookGridSliver(ThemeData theme, List<BookModel> books) {
    switch (_viewMode) {
      case _ViewMode.grid:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridCard(books[index], theme),
              childCount: books.length,
            ),
          ),
        );
      case _ViewMode.list:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildListCard(books[index], theme),
              childCount: books.length,
            ),
          ),
        );
      case _ViewMode.compact:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCompactCard(books[index], theme),
              childCount: books.length,
            ),
          ),
        );
    }
  }

  Widget _buildGridView(ThemeData theme, List<BookModel> books) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) => _buildGridCard(books[i], theme),
    );
  }

  Widget _buildListView(ThemeData theme, List<BookModel> books) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: books.length,
      itemBuilder: (_, i) => _buildListCard(books[i], theme),
    );
  }

  Widget _buildCompactView(ThemeData theme, List<BookModel> books) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: books.length,
      itemBuilder: (_, i) => _buildCompactCard(books[i], theme),
    );
  }

  Widget _buildGridCard(BookModel book, ThemeData theme) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      onLongPress: () => _showBookActions(book),
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
                    color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.06),
                    child: hasCover
                        ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.3))))
                        : Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.3))),
                  ),
                ),
                if (book.isFavorite)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 14),
                    ),
                  ),
                if (book.progress >= 1)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.finished, borderRadius: BorderRadius.circular(6)),
                      child: const Text("Finished", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (book.progress > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.reading, borderRadius: BorderRadius.circular(6)),
                      child: Text("${(book.progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (book.progress > 0 && book.progress < 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                      child: LinearProgressIndicator(
                        value: book.progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(BookModel book, ThemeData theme) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
        onLongPress: () => _showBookActions(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 72,
                  color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.06),
                  child: hasCover
                      ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded, size: 28, color: AppColors.accent.withOpacity(0.3)))
                      : Icon(Icons.menu_book_rounded, size: 28, color: AppColors.accent.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (book.isFavorite)
                          const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: book.progress.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BookModel book, ThemeData theme) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return InkWell(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      onLongPress: () => _showBookActions(book),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 48,
                color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.06),
                child: hasCover
                    ? Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded, size: 18, color: AppColors.accent.withOpacity(0.3)))
                    : Icon(Icons.menu_book_rounded, size: 18, color: AppColors.accent.withOpacity(0.3)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (book.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.favorite_rounded, color: AppColors.accent, size: 14),
              ),
            Text("${(book.progress * 100).toInt()}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 32, color: AppColors.accent.withOpacity(0.3)),
    );
  }
}
