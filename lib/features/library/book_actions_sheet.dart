import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../data/models/book_model.dart';
import '../../data/services/share_service.dart';
import 'pdf_cover_picker.dart';

Future<void> savePdfPageCover(
  BuildContext context,
  WidgetRef ref,
  BookModel book,
) async {
  final filePath = book.filePath;
  if (filePath == null || filePath.isEmpty) {
    _snack(context, "This PDF has no local file to read.");
    return;
  }
  final page = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PdfCoverPagePicker(filePath: filePath),
  );
  if (page == null) return;

  try {
    final bytes = await renderPdfPageAsPng(filePath, page, 360);
    if (bytes == null) {
      _snack(context, "Could not render page $page of the PDF.");
      return;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory("${appDir.path}/libora_covers");
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    final dest = File("${coversDir.path}/${book.id}.png");
    await dest.writeAsBytes(bytes, flush: true);

    await ref.read(bookRepositoryProvider).updateBook(
          book.copyWith(coverPath: dest.path),
        );
    ref.invalidate(allBooksProvider);
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recentlyAddedBooksProvider);
    _snack(context, "Cover set from page $page of \"${book.title}\"");
  } catch (_) {
    _snack(context, "Could not set the cover from the PDF.");
  }
}

Future<void> saveGalleryCover(BuildContext context, WidgetRef ref, BookModel book) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1400,
    maxHeight: 2000,
    imageQuality: 90,
  );
  if (picked == null) return;
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory("${appDir.path}/libora_covers");
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    final dest = File("${coversDir.path}/${book.id}.jpg");
    await File(picked.path).copy(dest.path);
    final updated = book.copyWith(coverPath: dest.path);
    await ref.read(bookRepositoryProvider).updateBook(updated);
    ref.invalidate(allBooksProvider);
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recentlyAddedBooksProvider);
    _snack(context, 'Cover updated for "${book.title}"');
  } catch (_) {
    _snack(context, "Could not update the cover");
  }
}

Future<void> showBookActionsSheet(
  BuildContext context,
  WidgetRef ref,
  BookModel book,
) async {
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              book.title,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text("Open Book"),
            onTap: () {
              Navigator.pop(ctx);
              context.push("${AppConstants.routeReader}/${book.id}");
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: const Text("Change Cover"),
            onTap: () {
              Navigator.pop(ctx);
              saveGalleryCover(context, ref, book);
            },
          ),
          if (book.format == BookFormat.pdf)
            ListTile(
              leading: const Icon(Icons.auto_stories_rounded),
              title: const Text("Set Cover from a PDF page"),
              onTap: () {
                Navigator.pop(ctx);
                savePdfPageCover(context, ref, book);
              },
            ),
          ListTile(
            leading: Icon(book.isFavorite ? Icons.favorite : Icons.favorite_border),
            title: Text(book.isFavorite ? "Remove from Favorites" : "Mark as Favorite"),
            onTap: () async {
              Navigator.pop(ctx);
              final updated = book.copyWith(isFavorite: !book.isFavorite);
              await ref.read(bookRepositoryProvider).updateBook(updated);
              ref.invalidate(allBooksProvider);
              _snack(
                context,
                updated.isFavorite
                    ? 'Added "${book.title}" to favorites'
                    : 'Removed "${book.title}" from favorites',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Share"),
            onTap: () {
              Navigator.pop(ctx);
              ShareService.shareBook(book.title, book.author);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Remove from Library",
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, ref, book);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref, BookModel book) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Remove Book"),
      content: Text(
        'Are you sure you want to remove "${book.title}" from your library?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text("Remove"),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref.read(bookRepositoryProvider).deleteBook(book.id);
    ref.invalidate(allBooksProvider);
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recentBooksProvider);
    ref.invalidate(recentlyAddedBooksProvider);
    ref.invalidate(totalBooksProvider);
    _snack(context, 'Removed "${book.title}" from your library');
  }
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
