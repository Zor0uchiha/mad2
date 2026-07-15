import "dart:io";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../core/constants/app_constants.dart";
import "../../../core/theme/app_colors.dart";
import "../../../data/models/book_model.dart";

class ContinueReadingCard extends StatelessWidget {
  final BookModel book;

  const ContinueReadingCard({super.key, required this.book});

  String _timeRemaining() {
    final remaining = book.pageCount - book.currentPage;
    if (remaining <= 0) return "Complete";
    final mins = (remaining * 0.5).round();
    if (mins < 60) return "${mins}m left";
    final h = mins ~/ 60;
    final m = mins % 60;
    return "${h}h ${m}m left";
  }

  String _lastOpenedText() {
    final lastOpened = book.lastOpenedAt;
    if (lastOpened == null) return "";
    final diff = DateTime.now().difference(lastOpened);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${(diff.inDays / 7).round()}w ago";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    final progress = book.progress.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.cardDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.1),
                  ),
                  child: hasCover
                      ? Image.file(
                          File(book.coverPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.border,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${(progress * 100).toInt()}% • Page ${book.currentPage}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _timeRemaining(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _lastOpenedText(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.accent.withOpacity(0.4)),
    );
  }
}
