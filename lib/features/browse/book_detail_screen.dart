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
        return _buildContent(theme, colorScheme, book);
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

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme, OnlineBookModel book) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: "book_cover_${book.id}",
                child: book.thumbnail != null
                    ? CachedNetworkImage(
                        imageUrl: book.thumbnail!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _coverPlaceholder(colorScheme),
                        errorWidget: (_, __, ___) => _coverPlaceholder(colorScheme),
                      )
                    : _coverPlaceholder(colorScheme),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(theme, colorScheme, book),
                  const SizedBox(height: 16),
                  _buildActionButtons(book),
                  const SizedBox(height: 16),
                  _buildDownloadSection(theme, book),
                  const SizedBox(height: 16),
                  _buildDescriptionSection(theme, book),
                  const SizedBox(height: 20),
                  _buildInfoSection(theme, book),
                  if (book.categories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCategoriesSection(theme, book),
                  ],
                  const SizedBox(height: 24),
                  _buildBottomActions(theme, book),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme, ColorScheme colorScheme, OnlineBookModel book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown Author",
          style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (book.averageRating != null) ...[
              Icon(Icons.star_rounded, color: AppColors.rating, size: 22),
              const SizedBox(width: 4),
              Text(
                book.averageRating!.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (book.ratingsCount != null) ...[
                const SizedBox(width: 4),
                Text(
                  "(${book.ratingsCount})",
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(width: 12),
            ],
            _SourceBadge(source: book.source),
            if (book.isFree || book.isPublicDomain) ...[
              const SizedBox(width: 8),
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
        ),
      ],
    );
  }

  Widget _buildActionButtons(OnlineBookModel book) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionChip(icon: Icons.bookmark_add_rounded, label: "Want to Read", color: AppColors.wantToRead, onTap: () {}),
          const SizedBox(width: 8),
          _ActionChip(icon: Icons.menu_book_rounded, label: "Reading", color: AppColors.reading, onTap: () {}),
          const SizedBox(width: 8),
          _ActionChip(icon: Icons.check_circle_rounded, label: "Finished", color: AppColors.finished, onTap: () {}),
          const SizedBox(width: 8),
          _ActionChip(icon: Icons.list_alt_rounded, label: "Add to List", color: AppColors.rating, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildDownloadSection(ThemeData theme, OnlineBookModel book) {
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
              _ActionChip(
                icon: Icons.download_rounded, label: "Download EPUB",
                color: const Color(0xFF34A853), onTap: () => _openUrl(book.epubDownloadLink!),
              ),
            if (book.pdfDownloadLink != null)
              _ActionChip(
                icon: Icons.download_rounded, label: "Download PDF",
                color: AppColors.accent, onTap: () => _openUrl(book.pdfDownloadLink!),
              ),
            if (book.readOnlineLink != null)
              _ActionChip(
                icon: Icons.public_rounded, label: "Read Online",
                color: const Color(0xFF1A73E8), onTap: () => _openUrl(book.readOnlineLink!),
              ),
            if (book.previewLink != null)
              _ActionChip(
                icon: Icons.preview_rounded, label: "Preview",
                color: const Color(0xFF7C4DFF), onTap: () => _openUrl(book.previewLink!),
              ),
            if (book.borrowLink != null)
              _ActionChip(
                icon: Icons.library_books_rounded, label: "Borrow",
                color: AppColors.streak, onTap: () => _openUrl(book.borrowLink!),
              ),
            if (book.buyLink != null)
              _ActionChip(
                icon: Icons.shopping_cart_rounded, label: "Buy Book",
                color: AppColors.rating, onTap: () => _openUrl(book.buyLink!),
              ),
            if (book.infoLink != null)
              _ActionChip(
                icon: Icons.language_rounded, label: "Visit Website",
                color: AppColors.textSecondary, onTap: () => _openUrl(book.infoLink!),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, OnlineBookModel book) {
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
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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

  Widget _buildInfoSection(ThemeData theme, OnlineBookModel book) {
    final infoItems = <_InfoItem>[];
    if (book.publisher != null) infoItems.add(_InfoItem("Publisher", book.publisher!));
    if (book.publishedDate != null) infoItems.add(_InfoItem("Published", book.publishedDate!));
    if (book.isbn != null) infoItems.add(_InfoItem("ISBN-13", book.isbn!));
    if (book.isbn10 != null) infoItems.add(_InfoItem("ISBN-10", book.isbn10!));
    if (book.pageCount != null) infoItems.add(_InfoItem("Pages", "${book.pageCount}"));
    if (book.language != null) infoItems.add(_InfoItem("Language", book.language!.toUpperCase()));
    if (book.downloadCount != null) infoItems.add(_InfoItem("Downloads", _formatCount(book.downloadCount!)));
    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: infoItems.map((item) => _InfoChip(label: item.label, value: item.value)).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(ThemeData theme, OnlineBookModel book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Categories", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: book.categories.map((c) => Chip(
            label: Text(c, style: theme.textTheme.labelSmall),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme, OnlineBookModel book) {
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

  String _formatCount(int count) {
    if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
    if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
    return count.toString();
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.menu_book_rounded, size: 80)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
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
        color: AppColors.textSecondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}
