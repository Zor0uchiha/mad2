import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/collection_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/services/share_service.dart";
import "widgets/collection_card.dart";

enum CollectionSort { name, createdDate, bookCount }

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  CollectionSort _sort = CollectionSort.name;

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedColor = AppColors.collectionColors[0].value;
    String selectedIcon = "folder";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("New Collection"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    hintText: "Collection name",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    hintText: "Optional description",
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
                  children: AppColors.collectionColors.map((c) {
                    final isSelected = c.value == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c.value),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
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
                final repo = ref.read(collectionsProvider);
                await repo.addCollection(CollectionModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  description: descController.text.trim(),
                  colorValue: selectedColor,
                  iconName: selectedIcon,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text("Create"),
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

  List<CollectionModel> _sorted(List<CollectionModel> collections) {
    final sorted = List<CollectionModel>.from(collections);
    switch (_sort) {
      case CollectionSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case CollectionSort.createdDate:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CollectionSort.bookCount:
        sorted.sort((a, b) => b.bookCount.compareTo(a.bookCount));
    }
    return sorted;
  }

  void _showCollectionActions(CollectionModel collection) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                collection.name,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text("Edit"),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text("Delete", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text("Share"),
              onTap: () {
                Navigator.pop(ctx);
                _shareCollection(collection);
              },
            ),
          ],
        ),
      ),
    );
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
                  children: AppColors.collectionColors.map((c) {
                    final isSelected = c.value == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c.value),
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
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
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
            onPressed: () async {
              await ref.read(collectionsProvider).deleteCollection(collection.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _shareCollection(CollectionModel collection) {
    final text = 'Collection "${collection.name}" on Libora\n'
        '${collection.bookCount} book${collection.bookCount == 1 ? "" : "s"}'
        '${collection.description != null && collection.description!.isNotEmpty ? "\n${collection.description}" : ""}';
    ShareService.shareText(text);
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(allCollectionsProvider).asData?.value ?? [];
    final sorted = _sorted(collections);
    final totalBooks = collections.fold<int>(0, (sum, c) => sum + c.bookCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Collections"),
        actions: [
          PopupMenuButton<CollectionSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: "Sort",
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => CollectionSort.values.map((sort) {
              String label;
              switch (sort) {
                case CollectionSort.name:
                  label = "Name";
                case CollectionSort.createdDate:
                  label = "Created Date";
                case CollectionSort.bookCount:
                  label = "Book Count";
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
        ],
      ),
      body: collections.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections_bookmark_rounded,
                      size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text("No collections yet",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text("Create your first collection to organize books",
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        "$totalBooks book${totalBooks == 1 ? "" : "s"} across ${collections.length} collection${collections.length == 1 ? "" : "s"}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final collection = sorted[index];
                      return GestureDetector(
                        onLongPress: () => _showCollectionActions(collection),
                        child: CollectionCard(
                          collection: collection,
                          onTap: () => context.push(
                            "${AppConstants.routeCollectionDetail}/${collection.id}",
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New Collection"),
      ),
    );
  }
}
