import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/services/share_service.dart";
import "widgets/book_grid_tile.dart";
import "widgets/book_list_tile.dart";

enum LibrarySort {
  titleAsc("Title A-Z"),
  titleDesc("Title Z-A"),
  authorAsc("Author A-Z"),
  authorDesc("Author Z-A"),
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
  List<BookModel> _filteredBooks = [];
  bool _isGridView = true;
  LibrarySort _currentSort = LibrarySort.recent;
  _BookFilter _selectedFilter = _BookFilter.all;
  Timer? _debounce;
  bool _isLoading = false;

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
      case LibrarySort.titleDesc:
        books.sort((a, b) => b.title.compareTo(a.title));
      case LibrarySort.authorAsc:
        books.sort((a, b) => a.author.compareTo(b.author));
      case LibrarySort.authorDesc:
        books.sort((a, b) => b.author.compareTo(a.author));
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
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = _filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library"),
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
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(
              _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? "List view" : "Grid view",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: "Search by title, author, or tags...",
              ),
            ),
          ),
          SizedBox(
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
          if (books.isNotEmpty)
            Padding(
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                    ? _buildEmptyState(theme)
                    : _isGridView
                        ? _buildGridView(books)
                        : _buildListView(books),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text("Import"),
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

  Widget _buildGridView(List<BookModel> books) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return GestureDetector(
          onLongPress: () => _showBookActions(book),
          child: Stack(
            children: [
              BookGridTile(book: book),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    book.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: book.isFavorite ? Colors.red : Colors.white70,
                    size: 20,
                  ),
                  onPressed: () => _toggleFavorite(book),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(List<BookModel> books) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  book.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: book.isFavorite ? Colors.red : null,
                ),
                onPressed: () => _toggleFavorite(book),
              ),
              Expanded(
                child: BookListTile(book: book),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: "Actions",
                onSelected: (value) => _handleListAction(book, value),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: "open",
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 20),
                        const SizedBox(width: 12),
                        Text("Open Book"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "edit",
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 12),
                        Text("Edit Metadata"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "collections",
                    child: Row(
                      children: [
                        const Icon(Icons.collections_bookmark, size: 20),
                        const SizedBox(width: 12),
                        Text("Collections"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "favorite",
                    child: Row(
                      children: [
                        Icon(
                          book.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(book.isFavorite ? "Unfavorite" : "Favorite"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "share",
                    child: Row(
                      children: [
                        const Icon(Icons.share, size: 20),
                        const SizedBox(width: 12),
                        Text("Share"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text("Remove", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
