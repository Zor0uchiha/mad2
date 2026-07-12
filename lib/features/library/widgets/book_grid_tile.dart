import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../core/constants/app_constants.dart";
import "../../../data/models/book_model.dart";

class BookGridTile extends StatelessWidget {
  final BookModel book;

  const BookGridTile({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (book.progress > 0)
                      Container(
                        height: 4,
                        width: double.infinity,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: book.progress.clamp(0.0, 1.0),
                          child: Container(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (book.progress > 0) ...[
                    SizedBox(height: 6),
                    Text(
                      "${(book.progress * 100).toInt()}%",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
