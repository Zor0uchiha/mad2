import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  final String? imageUrl;
  final String? title;
  final double width;
  final double height;
  final double borderRadius;

  const BookCover({
    super.key,
    this.imageUrl,
    this.title,
    this.width = 120,
    this.height = 180,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(theme),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _placeholder(theme, loading: true);
          },
        ),
      );
    }

    return _placeholder(theme);
  }

  Widget _placeholder(ThemeData theme, {bool loading = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Center(
              child: Icon(
                Icons.menu_book_rounded,
                size: width * 0.4,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
              ),
            ),
    );
  }
}
