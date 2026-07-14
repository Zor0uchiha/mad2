import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/collection_model.dart";

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

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  Future<void> _refresh() async {
    await ref.refresh(allCollectionsProvider.future);
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Collection"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Name",
            hintText: "Collection name",
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
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
                colorValue: AppColors.collectionColors[
                    DateTime.now().millisecondsSinceEpoch % AppColors.collectionColors.length]
                    .value,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) _refresh();
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(allCollectionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Collections")),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text("Something went wrong", style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(allCollectionsProvider),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections_bookmark_rounded, size: 64, color: AppColors.accent.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text("No collections yet", style: theme.textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text("Create your first collection to organize books", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Create Collection"),
                    onPressed: _showCreateDialog,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                final color = Color(collection.colorValue);

                return GestureDetector(
                  onTap: () => context.push("${AppConstants.routeCollectionDetail}/${collection.id}"),
                  child: Card(
                    color: color.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _iconFromName(collection.iconName),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            collection.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${collection.bookCount} book${collection.bookCount == 1 ? "" : "s"}",
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: "New Collection",
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
