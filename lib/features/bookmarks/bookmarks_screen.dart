import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/bookmark_model.dart";
import "../../data/models/note_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String? _selectedBookId;
  late TabController _tabController;
  String? _editingBookmarkId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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

  List<NoteModel> _filterNotes(
    List<NoteModel> notes,
    List<BookModel> books,
  ) {
    var filtered = notes.toList();

    if (_selectedBookId != null) {
      filtered = filtered.where((n) => n.bookId == _selectedBookId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((n) {
        final book = books.cast<BookModel?>().firstWhere(
              (bk) => bk?.id == n.bookId,
              orElse: () => null,
            );
        return n.text.toLowerCase().contains(query) ||
            n.bookTitle.toLowerCase().contains(query) ||
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
          content: const Text("Bookmark deleted"),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () async {
              await ref.read(bookmarkRepositoryProvider).addBookmark(bookmark);
            },
          ),
        ),
      );
    }
  }

  void _confirmDeleteBookmark(BuildContext context, BookmarkModel bookmark) {
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

  Future<void> _deleteNote(NoteModel note) async {
    await ref.read(noteRepositoryProvider).deleteNote(note.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Note deleted"),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () async {
              await ref.read(noteRepositoryProvider).saveNote(note);
            },
          ),
        ),
      );
    }
  }

  void _confirmDeleteNote(BuildContext context, NoteModel note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Note?"),
        content: Text("Delete note from page ${note.pageIndex + 1}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteNote(note);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(NoteModel note) {
    final controller = TextEditingController(text: note.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Note"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter note text"),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await ref
                    .read(noteRepositoryProvider)
                    .saveNote(note.copyWith(text: text));
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBookmarkTitle(
      BookmarkModel bookmark, String newTitle) async {
    await ref
        .read(bookmarkRepositoryProvider)
        .updateBookmark(bookmark.copyWith(title: newTitle));
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    final notesAsync = ref.watch(allNotesProvider);
    final booksAsync = ref.watch(allBooksProvider);
    final bookmarks = bookmarksAsync.asData?.value ?? [];
    final notes = notesAsync.asData?.value ?? [];
    final books = booksAsync.asData?.value ?? [];
    final filteredBookmarks = _filterBookmarks(bookmarks, books);
    final filteredNotes = _filterNotes(notes, books);

    final allBookIds = <String>{
      ...bookmarks.map((b) => b.bookId),
      ...notes.map((n) => n.bookId),
    };
    final uniqueBookIds = allBookIds.toList();
    final bookTitleMap = {
      for (final book in books) book.id: book.title,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookmarks & Notes"),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: "Bookmarks"),
            Tab(text: "Notes"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _tabController.index == 0
                    ? "Search bookmarks..."
                    : "Search notes...",
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookmarksTab(filteredBookmarks, bookTitleMap, context),
                _buildNotesTab(filteredNotes, bookTitleMap, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab(
    List<BookmarkModel> bookmarks,
    Map<String, String> bookTitleMap,
    BuildContext context,
  ) {
    if (bookmarks.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final bookTitle =
            bookTitleMap[bookmark.bookId] ?? bookmark.bookTitle;
        final isEditing = _editingBookmarkId == bookmark.id;
        final titleController =
            TextEditingController(text: bookmark.title);

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
            _confirmDeleteBookmark(context, bookmark);
            return false;
          },
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bookmark_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: isEditing
                ? TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onSubmitted: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        _updateBookmarkTitle(bookmark, trimmed);
                      }
                      setState(() => _editingBookmarkId = null);
                    },
                    onTapOutside: (_) {
                      final trimmed = titleController.text.trim();
                      if (trimmed.isNotEmpty) {
                        _updateBookmarkTitle(bookmark, trimmed);
                      }
                      setState(() => _editingBookmarkId = null);
                    },
                  )
                : GestureDetector(
                    onTap: () =>
                        setState(() => _editingBookmarkId = bookmark.id),
                    child: Text(
                      bookmark.title.isNotEmpty
                          ? bookmark.title
                          : "Page ${bookmark.pageIndex + 1}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Row(
                  children: [
                    Text(
                      "Page ${bookmark.pageIndex + 1}",
                      style: Theme.of(context).textTheme.bodySmall,
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
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => _confirmDeleteBookmark(context, bookmark),
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
    );
  }

  Widget _buildNotesTab(
    List<NoteModel> notes,
    Map<String, String> bookTitleMap,
    BuildContext context,
  ) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "No notes yet",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedBookId != null
                  ? "Try a different search or filter"
                  : "Add notes while reading to remember important parts",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final bookTitle =
            bookTitleMap[note.bookId] ?? note.bookTitle;

        return Dismissible(
          key: ValueKey(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: Icon(Icons.delete_rounded,
                color: Theme.of(context).colorScheme.onError),
          ),
          confirmDismiss: (_) async {
            _confirmDeleteNote(context, note);
            return false;
          },
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.note_alt_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              note.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Row(
                  children: [
                    Text(
                      "Page ${note.pageIndex + 1}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditNoteDialog(note),
            ),
            onTap: () => _showEditNoteDialog(note),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    }
    return "${date.day}/${date.month}/${date.year}";
  }
}
