import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";
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

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    ref.read(booksProvider).getAllBooks().then((list) {
      if (mounted) {
        setState(() {
          _filteredBooks = list;
        });
      }
      _applySort();
    });
  }

  void _filterBooks(String query) {
    final Future<List<BookModel>> future = query.isEmpty
        ? ref.read(booksProvider).getAllBooks()
        : ref.read(booksProvider).searchBooks(query);
    future.then((list) {
      if (mounted) {
        setState(() {
          _filteredBooks = list;
        });
        _applySort();
      }
    });
  }

  void _applySort() {
    switch (_currentSort) {
      case LibrarySort.titleAsc:
        _filteredBooks.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.titleDesc:
        _filteredBooks.sort((a, b) => b.title.compareTo(a.title));
      case LibrarySort.authorAsc:
        _filteredBooks.sort((a, b) => a.author.compareTo(b.author));
      case LibrarySort.authorDesc:
        _filteredBooks.sort((a, b) => b.author.compareTo(a.author));
      case LibrarySort.recent:
        _filteredBooks.sort(
          (a, b) =>
              (b.lastOpenedAt ?? b.createdAt)
                  .compareTo(a.lastOpenedAt ?? a.createdAt),
        );
      case LibrarySort.progress:
        _filteredBooks.sort((a, b) => b.progress.compareTo(a.progress));
    }
  }

  void _setSort(LibrarySort sort) {
    setState(() {
      _currentSort = sort;
      _applySort();
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
                      SizedBox(width: 18),
                    SizedBox(width: 8),
                    Text(sort.label),
                  ],
                ),
              ),
            ).toList(),
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
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
              onChanged: _filterBooks,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: "Search by title, author, or tags...",
              ),
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
                  Spacer(),
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
            child: books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.4),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? "Your library is empty"
                              : "No books found",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 8),
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
                  )
                : _isGridView
                    ? GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: books.length,
                        itemBuilder: (context, index) =>
                            BookGridTile(book: books[index]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: books.length,
                        itemBuilder: (context, index) =>
                            BookListTile(book: books[index]),
                      ),
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
}
