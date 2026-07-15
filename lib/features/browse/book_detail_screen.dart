import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:share_plus/share_plus.dart" as share_plus;
import "package:url_launcher/url_launcher.dart" as url_launcher;
import "package:file_picker/file_picker.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";
import "../../data/models/book_model.dart";
import "../../data/services/import_service.dart";
import "../../data/repositories/local_repositories.dart";

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String? source;

  const BookDetailScreen({required this.bookId, this.source, super.key});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _showFullDescription = false;

  String get _detailKey => "${widget.source ?? 'google_books'}|${widget.bookId}";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookAsync = ref.watch(bookDetailProvider(_detailKey));

    return bookAsync.when(
      data: (book) {
        if (book == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Book Details")),
            body: const Center(child: Text("Book not found")),
          );
        }
        return _buildPremiumLayout(theme, colorScheme, book);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text("Book Details")),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text("Book Details")),
        body: Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildPremiumLayout(ThemeData theme, ColorScheme colorScheme, OnlineBookModel book) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            leading: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.thumbnail != null)
                    CachedNetworkImage(
                      imageUrl: book.thumbnail!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _coverPlaceholder(colorScheme),
                      errorWidget: (_, __, ___) => _coverPlaceholder(colorScheme),
                    )
                  else
                    _coverPlaceholder(colorScheme),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            colorScheme.surface.withOpacity(0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Hero(
                            tag: "book_cover_${book.id}",
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 110,
                                height: 160,
                                child: book.thumbnail != null
                                    ? CachedNetworkImage(
                                        imageUrl: book.thumbnail!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => _coverPlaceholder(colorScheme),
                                        errorWidget: (_, __, ___) => _coverPlaceholder(colorScheme),
                                      )
                                    : _coverPlaceholder(colorScheme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  book.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown Author",
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRatingRow(book, theme),
                  const SizedBox(height: 16),
                  _buildStatusRow(book),
                  const SizedBox(height: 20),
                  _buildDescription(book, theme),
                  const SizedBox(height: 20),
                  _buildInfoRow(book, theme),
                  if (book.categories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildGenres(book, theme),
                  ],
                  const SizedBox(height: 20),
                  _buildAvailability(book, theme),
                  const SizedBox(height: 24),
                  _buildBottomActions(book, theme, colorScheme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(OnlineBookModel book, ThemeData theme) {
    return Row(
      children: [
        if (book.averageRating != null) ...[
          Icon(Icons.star_rounded, color: AppColors.rating, size: 24),
          const SizedBox(width: 4),
          Text(
            book.averageRating!.toStringAsFixed(1),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (book.ratingsCount != null) ...[
            const SizedBox(width: 4),
            Text(
              "(${book.ratingsCount})",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(width: 12),
        ],
        _SourceBadge(source: book.source),
        if (book.isFree || book.isPublicDomain) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.reading.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              book.isPublicDomain ? "Public Domain" : "Free",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.reading),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusRow(OnlineBookModel book) {
    return Row(
      children: [
        _ActionBadge(icon: Icons.bookmark_add_rounded, label: "Want to Read", color: AppColors.wantToRead),
        const SizedBox(width: 8),
        _ActionBadge(icon: Icons.menu_book_rounded, label: "Reading", color: AppColors.reading),
        const SizedBox(width: 8),
        _ActionBadge(icon: Icons.check_circle_rounded, label: "Finished", color: AppColors.finished),
      ],
    );
  }

  Widget _buildDescription(OnlineBookModel book, ThemeData theme) {
    if (book.description == null || book.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Description", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          book.description!,
          maxLines: _showFullDescription ? null : 4,
          overflow: _showFullDescription ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: theme.colorScheme.onSurfaceVariant),
        ),
        if (book.description!.length > 250)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showFullDescription = !_showFullDescription),
              child: Text(_showFullDescription ? "Show less" : "Read more"),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(OnlineBookModel book, ThemeData theme) {
    final items = <MapEntry<String, String>>[];
    if (book.publisher != null) items.add(MapEntry("Publisher", book.publisher!));
    if (book.publishedDate != null) items.add(MapEntry("Published", book.publishedDate!));
    if (book.isbn != null) items.add(MapEntry("ISBN-13", book.isbn!));
    if (book.isbn10 != null) items.add(MapEntry("ISBN-10", book.isbn10!));
    if (book.pageCount != null) items.add(MapEntry("Pages", "${book.pageCount}"));
    if (book.language != null) items.add(MapEntry("Language", book.language!.toUpperCase()));
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((e) => _InfoBadge(label: e.key, value: e.value)).toList(),
        ),
      ],
    );
  }

  Widget _buildGenres(OnlineBookModel book, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Genres", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: book.categories.map((c) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(c, style: theme.textTheme.labelMedium?.copyWith(fontSize: 12)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAvailability(OnlineBookModel book, ThemeData theme) {
    final hasDirectDownload = book.epubDownloadLink != null || book.pdfDownloadLink != null;
    final hasReadOnline = book.readOnlineLink != null;
    final hasPreview = book.previewLink != null;
    final hasBorrow = book.borrowLink != null;
    final hasBuy = book.buyLink != null;
    final hasInfo = book.infoLink != null;

    if (!hasDirectDownload && !hasReadOnline && !hasPreview && !hasBorrow && !hasBuy && !hasInfo) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Availability", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (book.epubDownloadLink != null)
              _ActionChip(icon: Icons.download_rounded, label: "Download EPUB", color: const Color(0xFF34A853), onTap: () => _openUrl(book.epubDownloadLink!)),
            if (book.pdfDownloadLink != null)
              _ActionChip(icon: Icons.download_rounded, label: "Download PDF", color: AppColors.accent, onTap: () => _openUrl(book.pdfDownloadLink!)),
            if (book.readOnlineLink != null)
              _ActionChip(icon: Icons.public_rounded, label: "Read Online", color: const Color(0xFF1A73E8), onTap: () => _openUrl(book.readOnlineLink!)),
            if (book.previewLink != null)
              _ActionChip(icon: Icons.preview_rounded, label: "Preview", color: const Color(0xFF7C4DFF), onTap: () => _openUrl(book.previewLink!)),
            if (book.borrowLink != null)
              _ActionChip(icon: Icons.library_books_rounded, label: "Borrow", color: AppColors.streak, onTap: () => _openUrl(book.borrowLink!)),
            if (book.buyLink != null)
              _ActionChip(icon: Icons.shopping_cart_rounded, label: "Buy Book", color: AppColors.rating, onTap: () => _openUrl(book.buyLink!)),
            if (book.infoLink != null)
              _ActionChip(icon: Icons.language_rounded, label: "Visit Website", color: theme.colorScheme.onSurfaceVariant, onTap: () => _openUrl(book.infoLink!)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActions(OnlineBookModel book, ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _importToLibrary(book),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text("Import to Library"),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _importFromFile(book),
              icon: const Icon(Icons.file_open_rounded, size: 20),
              label: const Text("Import File"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => share_plus.Share.share("Check out ${book.title} on Libora!\n\n${book.infoLink ?? book.previewLink ?? ''}"),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text("Share"),
          ),
        ),
      ],
    );
  }

  Future<void> _importToLibrary(OnlineBookModel book) async {
    final repo = ref.read(booksProvider);
    final allBooks = await repo.getAllBooks();
    final existing = allBooks.where((b) =>
        b.title.toLowerCase() == book.title.toLowerCase()).toList();
    if (existing.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${book.title} is already in your library")),
        );
      }
      return;
    }
    final newBook = BookModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: book.title,
      author: book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown",
      coverPath: book.thumbnail,
      description: book.description,
      format: BookFormat.pdf,
      pageCount: book.pageCount ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: List.from(book.categories),
      onlineBookId: book.id,
    );
    await repo.addBook(newBook);
    if (context.mounted) {
      ref.invalidate(allBooksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported ${book.title} to library")),
      );
    }
  }

  Future<void> _importFromFile(OnlineBookModel book) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final repo = ref.read(bookRepositoryProvider);
      final importService = ImportService(repo);
      final imported = await importService.importFromPath(result.files.first.path ?? '');
      if (imported != null && context.mounted) {
        ref.invalidate(allBooksProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Imported ${imported.title}")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import error: $e")),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
    }
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.menu_book_rounded, size: 80)),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      'google_books' => 'Google Books',
      'open_library' => 'Open Library',
      'gutendex' => 'Project Gutenberg',
      _ => source,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withOpacity(0.08),
    );
  }
}
