import "dart:io";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../core/constants/app_constants.dart";
import "../../../core/theme/app_colors.dart";
import "../../../data/models/book_model.dart";

class ContinueReadingCard extends StatelessWidget {
  final BookModel book;

  const ContinueReadingCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 60,
          decoration: BoxDecoration(
            color: hasCover ? Colors.transparent : AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: hasCover
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded, color: AppColors.accent)),
                )
              : Icon(Icons.menu_book_rounded, color: AppColors.accent),
        ),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: book.progress.clamp(0.0, 1.0), minHeight: 3, backgroundColor: AppColors.border),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
        ),
        onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
      ),
    );
  }
}
