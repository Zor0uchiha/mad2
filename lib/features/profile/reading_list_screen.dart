import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/reading_list_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";

final _readingListsProvider = Provider.autoDispose<List<ReadingListModel>>((ref) {
  final box = ref.watch(readingListsProvider);
  final lists = box.values.toList();
  lists.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return lists;
});

class ReadingListScreen extends ConsumerStatefulWidget {
  const ReadingListScreen({super.key});

  @override
  ConsumerState<ReadingListScreen> createState() => _ReadingListScreenState();
}

class _ReadingListScreenState extends ConsumerState<ReadingListScreen> {
  String? _expandedListId;

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Reading List"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "List Name"),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Description (optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _createList(nameController.text.trim(), descController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _createList(String title, String description) async {
    final box = ref.read(readingListsProvider);
    final list = ReadingListModel(
      id: const Uuid().v4(),
      title: title,
      description: description.isEmpty ? null : description,
      userId: "current_user",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: box.values.length,
    );
    await box.put(list.id, list);
  }

  Future<void> _deleteList(ReadingListModel list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete List"),
        content: Text('Are you sure you want to delete "${list.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(readingListsProvider).delete(list.id);
    }
  }

  Future<void> _togglePublic(ReadingListModel list) async {
    final updated = list.copyWith(isPublic: !list.isPublic, updatedAt: DateTime.now());
    await ref.read(readingListsProvider).put(updated.id, updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lists = ref.watch(_readingListsProvider);
    final books = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Reading Lists")),
      body: lists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt_rounded, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text("No reading lists yet", style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text("Create a list to organize your books", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Create List"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: lists.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text("${lists.length} list${lists.length == 1 ? "" : "s"}", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const Spacer(),
                      ],
                    ),
                  );
                }
                final list = lists[index - 1];
                final isExpanded = _expandedListId == list.id;
                final listBooks = list.bookIds.map((id) => books.getBook(id)).whereType<BookModel>().toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.list_rounded, color: colorScheme.onPrimaryContainer),
                        ),
                        title: Text(list.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(list.description ?? "${list.bookCount} books", maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(list.isPublic ? Icons.public_rounded : Icons.lock_rounded, size: 20),
                              onPressed: () => _togglePublic(list),
                              tooltip: list.isPublic ? "Public" : "Private",
                            ),
                            IconButton(
                              icon: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                              onPressed: () => setState(() => _expandedListId = isExpanded ? null : list.id),
                            ),
                          ],
                        ),
                        onTap: () => setState(() => _expandedListId = isExpanded ? null : list.id),
                      ),
                      if (isExpanded) ...[
                        if (listBooks.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              children: listBooks.map((book) {
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 28,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.menu_book_rounded, size: 18),
                                  ),
                                  title: Text(book.title, style: theme.textTheme.bodyMedium),
                                  subtitle: Text(book.author, style: theme.textTheme.labelSmall),
                                  trailing: Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall),
                                  onTap: () {},
                                );
                              }).toList(),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text("No books in this list", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text("Delete"),
                                onPressed: () => _deleteList(list),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New List"),
      ),
    );
  }
}
