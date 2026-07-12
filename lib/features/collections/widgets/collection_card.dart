import "package:flutter/material.dart";
import "package:bookstr/data/models/collection_model.dart";

class CollectionCard extends StatelessWidget {
  final CollectionModel collection;
  final VoidCallback onTap;

  const CollectionCard({
    required this.collection,
    required this.onTap,
    super.key,
  });

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

  @override
  Widget build(BuildContext context) {
    final color = collection.color;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color.withValues(alpha: 0.15),
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
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "${collection.bookCount} book${collection.bookCount == 1 ? "" : "s"}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
