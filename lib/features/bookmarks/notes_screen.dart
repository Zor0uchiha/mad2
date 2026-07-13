import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/note_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/reading_repositories.dart";
import "../../data/repositories/local_repositories.dart";

class NotesScreen extends ConsumerStatefulWidget {
  final String? initialBookId;
  final int? initialPageIndex;

  const NotesScreen({super.key, this.initialBookId, this.initialPageIndex});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String? _selectedBookId;
  bool _didInitialDialog = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _showAddNoteDialog({String? prefillBookId, int? prefillPageIndex}) {
    final textController = TextEditingController();
    String selectedBookId = prefillBookId ?? "";
    int pageIndex = prefillPageIndex ?? 0;
    final pageController =
        TextEditingController(text: (pageIndex + 1).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        final booksAsync = ref.read(allBooksProvider);
        List<BookModel> books = [];
        ref.listen(allBooksProvider, (_, next) {
          books = next.asData?.value ?? [];
        });
        books = booksAsync.asData?.value ?? [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableBooks = books;

            return AlertDialog(
              title: const Text("Add Note"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBookId.isNotEmpty &&
                              availableBooks.any((b) => b.id == selectedBookId)
                          ? selectedBookId
                          : null,
                      decoration: const InputDecoration(
                        labelText: "Book",
                        prefixIcon: Icon(Icons.book_rounded),
                      ),
                      items: availableBooks
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.title,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => selectedBookId = v ?? "");
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pageController,
                      decoration: const InputDecoration(
                        labelText: "Page number",
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          pageIndex = parsed - 1;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: "Note",
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                      maxLines: 3,
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
                    final text = textController.text.trim();
                    if (text.isEmpty || selectedBookId.isEmpty) return;
                    final book = availableBooks
                        .cast<BookModel?>()
                        .firstWhere((b) => b?.id == selectedBookId,
                            orElse: () => null);
                    await ref.read(noteRepositoryProvider).saveNote(
                          NoteModel(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            bookId: selectedBookId,
                            bookTitle: book?.title ?? "",
                            pageIndex: pageIndex,
                            text: text,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditNoteDialog(NoteModel note) {
    final textController = TextEditingController(text: note.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Note"),
        content: TextField(
          controller: textController,
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
              final text = textController.text.trim();
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

  void _confirmDelete(BuildContext context, NoteModel note) {
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

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);
    final booksAsync = ref.watch(allBooksProvider);
    final notes = notesAsync.asData?.value ?? [];
    final books = booksAsync.asData?.value ?? [];
    final filtered = _filterNotes(notes, books);

    final uniqueBookIds = notes.map((n) => n.bookId).toSet().toList();
    final bookTitleMap = {
      for (final book in books) book.id: book.title,
    };

    if (!_didInitialDialog &&
        widget.initialBookId != null &&
        widget.initialPageIndex != null) {
      _didInitialDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddNoteDialog(
          prefillBookId: widget.initialBookId,
          prefillPageIndex: widget.initialPageIndex,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Notes")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: "Search notes...",
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
                              : "Tap + to add a new note",
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
                      final note = filtered[index];
                      final bookTitle = bookTitleMap[note.bookId] ??
                          note.bookTitle;

                      return Dismissible(
                        key: ValueKey(note.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Theme.of(context).colorScheme.error,
                          child: Icon(
                            Icons.delete_rounded,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          _confirmDelete(context, note);
                          return false;
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.note_alt_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
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
                              GestureDetector(
                                onTap: () {
                                  context.push(
                                    "${AppConstants.routeReader}/${note.bookId}",
                                  );
                                },
                                child: Text(
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
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "Page ${note.pageIndex + 1}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(note.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
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
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
