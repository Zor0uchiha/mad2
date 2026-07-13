import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/bookmark_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String? _selectedBookId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookmarkModel> _filterBookmarks(
    List<BookmarkModel> bookmarks,
    List<BookModel> books,
  ) {
    var filtered = bookmarks.toList();

    if (_selectedBookId != null) {
      filtered = filtered.where((b) => b.bookId == _selectedBookId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        final book = books.cast<BookModel?>().firstWhere(
              (bk) => bk?.id == b.bookId,
              orElse: () => null,
            );
        return b.title.toLowerCase().contains(query) ||
            b.bookTitle.toLowerCase().contains(query) ||
            (b.note?.toLowerCase().contains(query) ?? false) ||
            (book?.title.toLowerCase().contains(query) ?? false) ||
            (book?.author.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> _deleteBookmark(BookmarkModel bookmark) async {
    await ref.read(bookmarkRepositoryProvider).deleteBookmark(bookmark.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bookmark deleted"),
          action: SnackBarAction(label: "Undo", onPressed: () async {
            await ref.read(bookmarkRepositoryProvider).addBookmark(bookmark);
          }),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, BookmarkModel bookmark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Bookmark?"),
        content: Text("Delete bookmark at page ${bookmark.pageIndex + 1}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteBookmark(bookmark);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    final booksAsync = ref.watch(allBooksProvider);
    final bookmarks = bookmarksAsync.asData?.value ?? [];
    final books = booksAsync.asData?.value ?? [];
    final filtered = _filterBookmarks(bookmarks, books);

    final uniqueBookIds = bookmarks.map((b) => b.bookId).toSet().toList();
    final bookTitleMap = {
      for (final book in books) book.id: book.title,
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Bookmarks")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: "Search bookmarks...",
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (uniqueBookIds.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonFormField<String?>(
                value: _selectedBookId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.filter_list_rounded),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                hint: const Text("All books"),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("All books"),
                  ),
                  ...uniqueBookIds.map((id) {
                    final title = bookTitleMap[id] ?? "Unknown";
                    return DropdownMenuItem(
                      value: id,
                      child: Text(title, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedBookId = v),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No bookmarks yet",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedBookId != null
                              ? "Try a different search or filter"
                              : "Bookmark pages while reading to find them later",
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final bookmark = filtered[index];
                      final bookTitle =
                          bookTitleMap[bookmark.bookId] ?? bookmark.bookTitle;
                      return Dismissible(
                        key: ValueKey(bookmark.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Theme.of(context).colorScheme.error,
                          child: Icon(Icons.delete_rounded,
                              color: Theme.of(context).colorScheme.onError),
                        ),
                        confirmDismiss: (_) async {
                          _confirmDelete(context, bookmark);
                          return false;
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.bookmark_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            bookmark.title.isNotEmpty
                                ? bookmark.title
                                : "Page ${bookmark.pageIndex + 1}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bookTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "Page ${bookmark.pageIndex + 1}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  if (bookmark.note != null &&
                                      bookmark.note!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        bookmark.note!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20),
                            onPressed: () => _confirmDelete(context, bookmark),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Jump to Page?"),
                                content: Text(
                                  "Go to page ${bookmark.pageIndex + 1} of $bookTitle?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text("Cancel"),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      context.push(
                                        "${AppConstants.routeReader}/${bookmark.bookId}",
                                      );
                                    },
                                    child: const Text("Go"),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
