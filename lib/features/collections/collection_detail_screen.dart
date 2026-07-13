import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/collection_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/services/share_service.dart";

enum _BookSort { title, author, progress, recentlyAdded }

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({required this.collectionId, super.key});

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  _BookSort _sort = _BookSort.recentlyAdded;

  List<BookModel> _sorted(List<BookModel> books) {
    final sorted = List<BookModel>.from(books);
    switch (_sort) {
      case _BookSort.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case _BookSort.author:
        sorted.sort((a, b) => a.author.compareTo(b.author));
      case _BookSort.progress:
        sorted.sort((a, b) => b.progress.compareTo(a.progress));
      case _BookSort.recentlyAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  Future<void> _deleteCollection(String id) async {
    await ref.read(collectionsProvider).deleteCollection(id);
    if (mounted) context.pop();
  }

  void _confirmDelete(CollectionModel collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Collection"),
        content: Text('Are you sure you want to delete "${collection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCollection(collection.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _shareCollection(CollectionModel collection, List<BookModel> books) {
    final bookList = books.take(5).map((b) => '• ${b.title}').join('\n');
    final text = 'Collection "${collection.name}" on Libora\n'
        '${collection.bookCount} book${collection.bookCount == 1 ? "" : "s"}'
        '${collection.description != null && collection.description!.isNotEmpty ? "\n${collection.description}" : ""}'
        '\n\n$bookList';
    ShareService.shareText(text);
  }

  void _showEditDialog(CollectionModel collection) {
    final nameController = TextEditingController(text: collection.name);
    final descController = TextEditingController(text: collection.description ?? "");
    int selectedColor = collection.colorValue;
    String selectedIcon = collection.iconName ?? "folder";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Edit Collection"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text("Icon", style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _iconOption("folder", Icons.folder_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("favorite", Icons.favorite_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("star", Icons.star_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("book", Icons.menu_book_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("library", Icons.library_books_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("science", Icons.science_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("history", Icons.history_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("art", Icons.palette_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                    _iconOption("music", Icons.music_note_rounded, selectedIcon, (v) => setDialogState(() => selectedIcon = v)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Color", style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppColors.collectionColors
                      .map((c) {
                        final isSelected = c.value == selectedColor;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = c.value),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final updated = collection.copyWith(
                  name: name,
                  description: descController.text.trim(),
                  colorValue: selectedColor,
                  iconName: selectedIcon,
                  updatedAt: DateTime.now(),
                );
                await ref.read(collectionsProvider).updateCollection(updated);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconOption(String name, IconData icon, String current, void Function(String) onSelected) {
    final isSelected = name == current;
    return GestureDetector(
      onTap: () => onSelected(name),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Icon(icon, size: 22, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      ),
    );
  }

  Future<void> _addBooksFromLibrary(CollectionModel collection) async {
    final allBooks = await ref.read(bookRepositoryProvider).getAllBooks();
    final available = allBooks.where((b) => !collection.bookIds.contains(b.id)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All books are already in this collection")),
        );
      }
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIds = <String>{};
          return AlertDialog(
            title: const Text("Add Books from Library"),
            content: SizedBox(
              width: double.maxFinite,
              child: available.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text("No books available to add"),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: available.map((book) {
                        final isChecked = selectedIds.contains(book.id);
                        return CheckboxListTile(
                          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                          value: isChecked,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedIds.add(book.id);
                              } else {
                                selectedIds.remove(book.id);
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
                onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(ctx, selectedIds),
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      final repo = ref.read(collectionsProvider);
      final bookRepo = ref.read(bookRepositoryProvider);
      for (final bookId in selected) {
        await repo.addBookToCollection(collection.id, bookId);
        final book = allBooks.firstWhere((b) => b.id == bookId);
        final updatedBook = book.copyWith(
          collectionIds: [...book.collectionIds, collection.id],
        );
        await bookRepo.updateBook(updatedBook);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${selected.length} book${selected.length == 1 ? "" : "s"} added")),
        );
      }
    }
  }

  Future<bool> _removeBookFromCollection(CollectionModel collection, BookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Book"),
        content: Text('Remove "${book.title}" from this collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(collectionsProvider);
      final bookRepo = ref.read(bookRepositoryProvider);
      await repo.removeBookFromCollection(collection.id, book.id);
      final updatedBook = book.copyWith(
        collectionIds: book.collectionIds.where((id) => id != collection.id).toList(),
      );
      await bookRepo.updateBook(updatedBook);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider(collectionId));
    final booksAsync = ref.watch(booksInCollectionProvider(collectionId));
    final collection = collectionAsync.asData?.value ?? null;
    final books = booksAsync.asData?.value ?? [];
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Collection")),
        body: const Center(child: Text("Collection not found")),
      );
    }
    final color = collection.color;
    final sorted = _sorted(books);
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.currentPage);
    final finishedBooks = books.where((b) => b.progress >= 1.0).length;

    final dateFormat = (DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          PopupMenuButton<_BookSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: "Sort books",
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => _BookSort.values.map((sort) {
              String label;
              switch (sort) {
                case _BookSort.title:
                  label = "Title";
                case _BookSort.author:
                  label = "Author";
                case _BookSort.progress:
                  label = "Progress";
                case _BookSort.recentlyAdded:
                  label = "Recently Added";
              }
              final isSelected = _sort == sort;
              return PopupMenuItem(
                value: sort,
                child: Row(
                  children: [
                    if (isSelected)
                      Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              );
            }).toList(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: "More",
            onSelected: (value) {
              switch (value) {
                case "edit":
                  _showEditDialog(collection);
                case "share":
                  _shareCollection(collection, books);
                case "delete":
                  _confirmDelete(collection);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "edit",
                child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 12), Text("Edit")]),
              ),
              const PopupMenuItem(
                value: "share",
                child: Row(children: [Icon(Icons.share_rounded, size: 20), SizedBox(width: 12), Text("Share")]),
              ),
              const PopupMenuItem(
                value: "delete",
                child: Row(children: [Icon(Icons.delete_rounded, size: 20, color: Colors.red), SizedBox(width: 12), Text("Delete", style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _iconFromName(collection.iconName),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${books.length} book${books.length == 1 ? "" : "s"}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (collection.description != null &&
                    collection.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    collection.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statChip(Icons.pages_rounded, "$totalPages pages read"),
                    const SizedBox(width: 12),
                    _statChip(Icons.check_circle_rounded, "$finishedBooks finished"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      "Created ${dateFormat(collection.createdAt)}",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.update, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      "Updated ${dateFormat(collection.updatedAt)}",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${sorted.length} book${sorted.length == 1 ? "" : "s"}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addBooksFromLibrary(collection),
                    icon: const Icon(Icons.library_add_rounded, size: 18),
                    label: const Text("Add Books"),
                  ),
                ],
              ),
            ),
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text("No books in this collection",
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _addBooksFromLibrary(collection),
                          icon: const Icon(Icons.library_add_rounded),
                          label: const Text("Add Books from Library"),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final book = sorted[index];
                      return Dismissible(
                        key: ValueKey(book.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.error,
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _removeBookFromCollection(collection, book),
                        child: _BookTile(
                          book: book,
                          onDelete: () => _removeBookFromCollection(collection, book),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  IconData _iconFromName(String? iconName) {
    switch (iconName) {
      case "favorite":
        return Icons.favorite_rounded;
      case "star":
        return Icons.star_rounded;
      case "book":
        return Icons.menu_book_rounded;
      case "library":
        return Icons.library_books_rounded;
      case "science":
        return Icons.science_rounded;
      case "history":
        return Icons.history_rounded;
      case "art":
        return Icons.palette_rounded;
      case "music":
        return Icons.music_note_rounded;
      case "folder":
      default:
        return Icons.folder_rounded;
    }
  }
}

class _BookTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onDelete;

  const _BookTile({required this.book, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: book.coverPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(book.coverPath!, fit: BoxFit.cover),
              )
            : Icon(Icons.menu_book_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${(book.progress * 100).toInt()}%",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: book.progress,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              tooltip: "Remove from collection",
              onPressed: onDelete,
            ),
          ],
        ],
      ),
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
    );
  }
}
