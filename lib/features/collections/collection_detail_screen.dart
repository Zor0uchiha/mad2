import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/collection_model.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({required this.collectionId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditDialog(context, ref, collection),
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
              ],
            ),
          ),
          const Divider(height: 1),
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
                        Text(
                          "Add books from your library",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return _BookTile(book: book);
                    },
                  ),
          ),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, CollectionModel collection) {
    final nameController = TextEditingController(text: collection.name);
    final descController = TextEditingController(text: collection.description ?? "");
    int selectedColor = collection.colorValue;

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
}

class _BookTile extends StatelessWidget {
  final BookModel book;

  const _BookTile({required this.book});

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
        ],
      ),
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
    );
  }
}
