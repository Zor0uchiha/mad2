import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:share_plus/share_plus.dart" as share_plus;
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/online_book_model.dart";
import "../../data/models/book_model.dart";
import "../../data/models/review_model.dart";
import "../../data/services/online_book_service.dart";
import "../../data/repositories/local_repositories.dart";

final _bookDetailProvider = FutureProvider.autoDispose.family<OnlineBookModel?, String>((ref, bookId) async {
  return ref.read(onlineBookServiceProvider).getBookById(bookId);
});

final _similarBooksProvider = FutureProvider.autoDispose.family<List<OnlineBookModel>, String>((ref, category) async {
  if (category.isEmpty) return [];
  return ref.read(onlineBookServiceProvider).searchBooks(category);
});

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailScreen({required this.bookId, super.key});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  ReadingStatus _status = ReadingStatus.none;
  bool _showFullDescription = false;
  double _userRating = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookAsync = ref.watch(_bookDetailProvider(widget.bookId));

    return bookAsync.when(
      data: (book) {
        if (book == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Book Details")),
            body: const Center(child: Text("Book not found")),
          );
        }

        final similarAsync = ref.watch(_similarBooksProvider(book.categories.isNotEmpty ? book.categories.first : ""));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
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
                            placeholder: (_, __) => Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded, size: 80)),
                            errorWidget: (_, __, ___) => Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded, size: 80)),
                          )
                        : Container(color: colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.menu_book_rounded, size: 80))),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown Author",
                        style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      if (book.categories.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: book.categories.map((c) => Chip(label: Text(c, style: theme.textTheme.labelSmall))).toList(),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: AppColors.rating, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            book.averageRating != null ? "${book.averageRating!.toStringAsFixed(1)}" : "N/A",
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (book.ratingsCount != null) ...[
                            const SizedBox(width: 4),
                            Text("(${book.ratingsCount} ratings)", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatusChip(
                            label: "Want to Read",
                            icon: Icons.bookmark_add_rounded,
                            selected: _status == ReadingStatus.wantToRead,
                            color: AppColors.wantToRead,
                            onTap: () => setState(() => _status = ReadingStatus.wantToRead),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: "Reading",
                            icon: Icons.menu_book_rounded,
                            selected: _status == ReadingStatus.reading,
                            color: AppColors.reading,
                            onTap: () => setState(() => _status = ReadingStatus.reading),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: "Finished",
                            icon: Icons.check_circle_rounded,
                            selected: _status == ReadingStatus.finished,
                            color: AppColors.finished,
                            onTap: () => setState(() => _status = ReadingStatus.finished),
                          ),
                        ],
                      ),
                      if (book.description != null && book.description!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text("Description", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          book.description!,
                          maxLines: _showFullDescription ? null : 4,
                          overflow: _showFullDescription ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (book.description!.length > 200)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(() => _showFullDescription = !_showFullDescription),
                              child: Text(_showFullDescription ? "Show less" : "Read more"),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      Text("Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(label: "Pages", value: book.pageCount?.toString() ?? "N/A"),
                          const SizedBox(width: 12),
                          _InfoChip(label: "Language", value: book.language?.toUpperCase() ?? "N/A"),
                          const SizedBox(width: 12),
                          _InfoChip(label: "Publisher", value: book.publisher ?? "N/A"),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _importToLibrary(book),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Import to Library"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.outlined(
                            onPressed: () => share_plus.Share.share("Check out ${book.title} on Bookstr!"),
                            icon: const Icon(Icons.share_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("Rate this book", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return IconButton(
                            icon: Icon(
                              star <= _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: AppColors.rating,
                            ),
                            onPressed: () => setState(() => _userRating = star.toDouble()),
                          );
                        }),
                      ),
                      if (_userRating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Write your review...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text("Similar Books", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      similarAsync.when(
                        data: (similar) {
                          final filtered = similar.where((s) => s.id != book.id).take(10).toList();
                          if (filtered.isEmpty) return const SizedBox.shrink();
                          return SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final sb = filtered[index];
                                return SizedBox(
                                  width: 120,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        context.pushReplacement("${AppConstants.routeBookDetail}/${sb.id}");
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: sb.thumbnail != null
                                                ? CachedNetworkImage(
                                                    imageUrl: sb.thumbnail!,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) => Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded)),
                                                    errorWidget: (_, __, ___) => Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book_rounded)),
                                                  )
                                                : Container(color: colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.menu_book_rounded))),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                                            child: Text(sb.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          ),
                                          if (sb.averageRating != null)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.star_rounded, size: 12, color: AppColors.rating),
                                                  const SizedBox(width: 2),
                                                  Text(sb.averageRating!.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                                                ],
                                              ),
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
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text("Book Details")),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text("Book Details")),
        body: Center(child: Text("Error loading book: $e")),
      ),
    );
  }

  Future<void> _importToLibrary(OnlineBookModel book) async {
    final repo = ref.read(booksProvider);
    final allBooks = await repo.getAllBooks();
    final existing = allBooks.where((b) => b.title == book.title).toList();
    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${book.title} is already in your library")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported ${book.title} to library")),
      );
    }
  }
}

enum ReadingStatus { none, wantToRead, reading, finished }

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: selected ? color : null),
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
        children: [
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
