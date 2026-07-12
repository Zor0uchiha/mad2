import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BookModel> _filteredBooks = [];
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _filteredBooks = ref.read(booksProvider).getAllBooks();
  }

  void _filterBooks(String query) {
    setState(() {
      _filteredBooks = ref.read(booksProvider).searchBooks(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = _filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library"),
        actions: [
          IconButton(onPressed: () => setState(() => _isGridView = !_isGridView), icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterBooks,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: "Search books..."),
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? Center(child: Text("No books found", style: Theme.of(context).textTheme.bodyLarge))
                : _isGridView
                    ? GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12), padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: books.length, itemBuilder: (context, index) => _BookGridTile(book: books[index]))
                    : ListView.builder(itemCount: books.length, itemBuilder: (context, index) => _BookListTile(book: books[index])),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text("Import")),
    );
  }
}

class _BookGridTile extends StatelessWidget {
  final BookModel book;
  const _BookGridTile({required this.book});

  @override
  Widget build(BuildContext context) {
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
                color: Theme.of(context).colorScheme.primaryContainer,
                child: book.coverPath != null
                    ? Image.network(book.coverPath!, fit: BoxFit.cover)
                    : const Icon(Icons.menu_book_rounded, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  final BookModel book;
  const _BookListTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(width: 48, height: 72, color: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.menu_book_rounded)),
      title: Text(book.title),
      subtitle: Text(book.author),
      trailing: Text("${(book.progress * 100).toInt()}%"),
      onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
    );
  }
}
