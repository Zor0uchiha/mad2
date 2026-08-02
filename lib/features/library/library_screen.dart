import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/collection_model.dart";
import "../../data/services/share_service.dart";
import "../../data/services/import_service.dart";
import "../../shared/widgets/generated_cover.dart";
import "book_actions_sheet.dart";

enum LibrarySort {
  titleAsc("Title A-Z"),
  authorAsc("Author"),
  recent("Recent"),
  progress("Progress");

  final String label;
  const LibrarySort(this.label);
}

enum _BookFilter { all, favorites, reading, finished, recentlyAdded }

enum _ViewMode { grid, list, shelf }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ViewMode _viewMode = _ViewMode.grid;
  LibrarySort _currentSort = LibrarySort.recent;
  _BookFilter _selectedFilter = _BookFilter.all;
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookModel> _applyFilterAndSort(List<BookModel> books) {
    final query = _searchController.text.trim().toLowerCase();
    var list = books.where((b) {
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.author.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    switch (_selectedFilter) {
      case _BookFilter.all:
        break;
      case _BookFilter.favorites:
        list = list.where((b) => b.isFavorite).toList();
        break;
      case _BookFilter.reading:
        list = list.where((b) => b.progress > 0 && b.progress < 1.0).toList();
        break;
      case _BookFilter.finished:
        list = list.where((b) => b.progress >= 1.0).toList();
        break;
      case _BookFilter.recentlyAdded:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    switch (_currentSort) {
      case LibrarySort.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySort.authorAsc:
        list.sort((a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
        break;
      case LibrarySort.recent:
        list.sort(
          (a, b) => (b.lastOpenedAt ?? b.createdAt).compareTo(a.lastOpenedAt ?? a.createdAt),
        );
        break;
      case LibrarySort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
    }
    return list;
  }

  Future<void> _importBooks() async {
    setState(() => _isImporting = true);
    try {
      final repo = ref.read(bookRepositoryProvider);
      final service = ImportService(repo);
      final imported = await service.pickAndImportBooks();
      if (imported.isNotEmpty) {
        ref.invalidate(allBooksProvider);
        ref.invalidate(continueReadingProvider);
        ref.invalidate(recentBooksProvider);
        ref.invalidate(recentlyAddedBooksProvider);
        ref.invalidate(totalBooksProvider);
        ref.invalidate(totalPagesReadProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Imported ${imported.length} book${imported.length == 1 ? "" : "s"}",
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
    ref.invalidate(allBooksProvider);
  }

  void _openBook(BookModel book) {
    context.push("${AppConstants.routeReader}/${book.id}");
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
                _openBook(book);
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
              leading: const Icon(Icons.image_rounded),
              title: const Text("Change Cover"),
              onTap: () {
                Navigator.pop(ctx);
                saveGalleryCover(context, ref, book);
              },
            ),
            if (book.format == BookFormat.pdf)
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text("Set Cover from a PDF page"),
                onTap: () {
                  Navigator.pop(ctx);
                  savePdfPageCover(context, ref, book);
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
              title: const Text("Remove from Library", style: TextStyle(color: Colors.red)),
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

  Future<void> _showEditDialog(BookModel book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final descController = TextEditingController(text: book.description ?? "");
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
        tags: tags,
      );
      await ref.read(bookRepositoryProvider).updateBook(updated);
      ref.invalidate(allBooksProvider);
    }

    titleController.dispose();
    authorController.dispose();
    descController.dispose();
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
      ref.invalidate(allBooksProvider);
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

    if (confirmed == true && mounted) {
      await ref.read(bookRepositoryProvider).deleteBook(book.id);
      ref.invalidate(allBooksProvider);
      ref.invalidate(continueReadingProvider);
      ref.invalidate(recentBooksProvider);
      ref.invalidate(recentlyAddedBooksProvider);
      ref.invalidate(totalBooksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, scheme),
            Expanded(
              child: booksAsync.when(
                loading: () => _buildShimmerGrid(theme, scheme),
                error: (e, _) => _buildErrorState(theme, scheme),
                data: (books) {
                  final visible = _applyFilterAndSort(books);
                  return _buildContent(theme, scheme, books.isEmpty, visible);
                },
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

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                "Library",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              PopupMenuButton<LibrarySort>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: "Sort",
                onSelected: (sort) => setState(() => _currentSort = sort),
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
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _viewModeButton(Icons.grid_view_rounded, _ViewMode.grid),
                    _viewModeButton(Icons.list_rounded, _ViewMode.list),
                    _viewModeButton(Icons.auto_stories_rounded, _ViewMode.shelf),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: "Search by title, author, or tags...",
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                onPressed: _showCreateCollectionDialog,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
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
        onSelected: (_) => setState(() => _selectedFilter = filter),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    ColorScheme scheme,
    bool libraryEmpty,
    List<BookModel> books,
  ) {
    if (books.isEmpty && !libraryEmpty) {
      return _buildNoResults(theme, scheme);
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(allBooksProvider.future),
      child: libraryEmpty
          ? _buildEmptyState(theme, scheme)
          : switch (_viewMode) {
              _ViewMode.grid => _buildGridView(theme, books),
              _ViewMode.list => _buildListView(theme, books),
              _ViewMode.shelf => _buildShelfView(theme, books),
            },
    );
  }

  Widget _buildNoResults(ThemeData theme, ColorScheme scheme) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(allBooksProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.search_off_rounded, size: 64, color: scheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            "No books match",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Try a different search or clear the current filter.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedFilter = _BookFilter.all;
                });
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text("Clear filters"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmptyIllustration(),
              const SizedBox(height: 24),
              Text(
                "Your library is empty",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Import PDFs or EPUBs from your device to start\nbuilding your personal bookshelf.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _importBooks,
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                label: const Text("Import Books"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(AppConstants.routeBrowse),
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text("Browse Online Books"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme scheme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: scheme.error.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't load your library",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Something went wrong while loading your books. Please try again.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allBooksProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid(ThemeData theme, ColorScheme scheme) {
    final base = scheme.surfaceContainerHighest;
    return _Shimmer(
      baseColor: base,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 14, width: double.infinity, color: base, margin: const EdgeInsets.only(bottom: 6)),
            Container(height: 12, width: 100, color: base),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(ThemeData theme, List<BookModel> books) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.66,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) => _GridBookCard(
        book: books[i],
        onOpen: () => _openBook(books[i]),
        onToggleFavorite: () => _toggleFavorite(books[i]),
        onMore: () => _showBookActions(books[i]),
      ),
    );
  }

  Widget _buildListView(ThemeData theme, List<BookModel> books) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ListBookCard(
        book: books[i],
        onOpen: () => _openBook(books[i]),
        onToggleFavorite: () => _toggleFavorite(books[i]),
        onMore: () => _showBookActions(books[i]),
      ),
    );
  }

  Widget _buildShelfView(ThemeData theme, List<BookModel> books) {
    final shelfCount = (books.length / 4).ceil();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: shelfCount,
      itemBuilder: (context, i) => _ShelfRow(
        books: books.sublist(i * 4, (i * 4 + 4) > books.length ? books.length : i * 4 + 4),
        onOpen: _openBook,
        onToggleFavorite: _toggleFavorite,
        onMore: _showBookActions,
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final BookModel book;
  final double? width;
  final double? height;
  final double fontSize;

  const _BookCover({
    required this.book,
    this.width,
    this.height,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    final placeholder = GeneratedCover(
      title: book.title,
      author: book.author,
      fontSize: fontSize,
    );
    if (!hasCover) return placeholder;
    return Image.file(
      File(book.coverPath!),
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _GridBookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMore;

  const _GridBookCard({
    required this.book,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onMore,
  });

  String? get _status {
    if (book.progress >= 1) return "Finished";
    if (book.progress > 0) return "${(book.progress * 100).toInt()}%";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: ValueKey("book-${book.id}"),
      onTap: onOpen,
      onLongPress: onMore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookCover(book: book),
                  if (_status != null)
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
                          _status!,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (book.progress > 0 && book.progress < 1)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: book.isFavorite ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      color: theme.colorScheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListBookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMore;

  const _ListBookCard({
    required this.book,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey("book-${book.id}"),
        onTap: onOpen,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 76,
                  child: _BookCover(book: book, width: 56, height: 76, fontSize: 9),
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
                        if (book.progress >= 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.finished, borderRadius: BorderRadius.circular(6)),
                            child: const Text("Finished", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
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
                        Text(
                          "${(book.progress * 100).toInt()}%",
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  IconButton(
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: book.isFavorite ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    color: theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  final List<BookModel> books;
  final void Function(BookModel) onOpen;
  final void Function(BookModel) onToggleFavorite;
  final void Function(BookModel) onMore;

  const _ShelfRow({
    required this.books,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < books.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: ValueKey("book-${books[i].id}"),
                    onTap: () => onOpen(books[i]),
                    onLongPress: () => onMore(books[i]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 0.72,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _BookCover(book: books[i], fontSize: 9),
                                if (books[i].isFavorite)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => onToggleFavorite(books[i]),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          books[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B6E47), Color(0xFF6B4F2F)],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.18),
            AppColors.wantToRead.withOpacity(0.18),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface.withOpacity(0.6),
            ),
          ),
          const Icon(Icons.menu_book_rounded, size: 56, color: AppColors.accent),
          Positioned(
            bottom: 34,
            right: 40,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.wantToRead,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;

  const _Shimmer({required this.child, required this.baseColor});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + 2 * t, 0),
            end: Alignment(1.0 + 2 * t, 0),
            colors: [
              Colors.transparent,
              widget.baseColor,
              Colors.transparent,
            ],
            stops: const [0.2, 0.5, 0.8],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
