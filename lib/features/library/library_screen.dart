import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_theme.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
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

enum _BookFilter { all, favorites, reading, finished, pdf, epub, recentlyAdded }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<BookModel> _filteredBooks = [];
  bool _isGridView = true;
  LibrarySort _currentSort = LibrarySort.titleAsc;
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
      case _BookFilter.pdf:
        return books.where((b) => b.format == BookFormat.pdf).toList();
      case _BookFilter.epub:
        return books.where((b) => b.format == BookFormat.epub).toList();
      case _BookFilter.recentlyAdded:
        books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return books.take(10).toList();
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
    final books = _filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Library"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: "Search",
            onPressed: () => _searchController.text.isNotEmpty
                ? _searchController.clear()
                : null,
          ),
          const SizedBox(width: 4),
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
                      Icon(
                        Icons.check,
                        size: 18,
                        color: theme.colorScheme.primary,
                      )
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
      body: RefreshIndicator(
        onRefresh: _loadBooks,
        child: _isLoading && books.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.grid_view_rounded, size: 18),
                              tooltip: "Grid view",
                            ),
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.list_rounded, size: 18),
                              tooltip: "List view",
                            ),
                          ],
                          selected: {_isGridView},
                          onSelectionChanged: (val) =>
                              setState(() => _isGridView = val.first),
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: "Search by title, author, or tags...",
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFilterChip("All", _BookFilter.all),
                          _buildFilterChip("Favorites", _BookFilter.favorites),
                          _buildFilterChip("Reading", _BookFilter.reading),
                          _buildFilterChip("Finished", _BookFilter.finished),
                          _buildFilterChip("PDF", _BookFilter.pdf),
                          _buildFilterChip("EPUB", _BookFilter.epub),
                          _buildFilterChip("Recently Added", _BookFilter.recentlyAdded),
                        ],
                      ),
                    ),
                  ),
                  if (books.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              "${books.length} book${books.length == 1 ? "" : "s"}",
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _currentSort.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (books.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme),
                    )
                  else if (_isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final book = books[index];
                            return _buildGridCard(book, theme);
                          },
                          childCount: books.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final book = books[index];
                            return _buildListCard(book, theme);
                          },
                          childCount: books.length,
                        ),
                      ),
                    ),
                ],
              ),
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

  Widget _buildFilterChip(String label, _BookFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _setFilter(filter),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? "Your library is empty"
                : "No books found",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? "Import your first book to get started"
                : "Try a different search term",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BookModel book, ThemeData theme) {
    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      onLongPress: () => _showBookActions(book),
      child: Card(
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppColors.accent.withOpacity(0.1),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: AppColors.accent.withOpacity(0.5),
                      ),
                    ),
                    if (book.progress > 0)
                      Container(
                        height: 4,
                        width: double.infinity,
                        color: AppColors.cardDark,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: book.progress.clamp(0.0, 1.0),
                          child: Container(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (book.progress > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${(book.progress * 100).toInt()}%",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BookModel book, ThemeData theme) {
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
        onLongPress: () => _showBookActions(book),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accent.withOpacity(0.5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (book.progress > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: book.progress.clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${(book.progress * 100).toInt()}%",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  book.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: book.isFavorite ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _toggleFavorite(book),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
