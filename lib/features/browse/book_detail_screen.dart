import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/models/review_model.dart";
import "../../data/repositories/local_repositories.dart";

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailScreen({required this.bookId, super.key});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _wantToRead = false;
  bool _isReading = false;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(booksProvider).getBook(widget.bookId);
    if (book == null) {
      return Scaffold(appBar: AppBar(title: const Text("Book Details")), body: const Center(child: Text("Book not found in library")));
    }

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 160, height: 240, color: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.menu_book_rounded, size: 80)),
            ),
            const SizedBox(height: 24),
            Text(book.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(book.author, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 16),
            Row(
              children: [
                FilterChip(label: Text("Want to Read"), selected: _wantToRead, onSelected: (v) => setState(() => _wantToRead = v)),
                const SizedBox(width: 8),
                FilterChip(label: Text("Reading"), selected: _isReading, onSelected: (v) => setState(() => _isReading = v)),
                const SizedBox(width: 8),
                FilterChip(label: Text("Finished"), selected: _isFinished, onSelected: (v) => setState(() => _isFinished = v)),
              ],
            ),
            const SizedBox(height: 24),
            Text("Description", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(book.description ?? "No description available.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            Text("Information", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(title: const Text("Pages"), trailing: Text("${book.pageCount}")),
            ListTile(title: const Text("Publisher"), trailing: Text(book.publisher ?? "Unknown")),
            ListTile(title: const Text("Language"), trailing: Text(book.language ?? "Unknown")),
            ListTile(title: const Text("ISBN"), trailing: Text(book.isbn ?? "N/A")),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () => context.push("${AppConstants.routeReader}/${book.id}"), icon: const Icon(Icons.menu_book_rounded), label: const Text("Read Now")),
          ],
        ),
      ),
    );
  }
}
