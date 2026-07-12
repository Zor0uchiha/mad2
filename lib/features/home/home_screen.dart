import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    final collections = ref.watch(collectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Bookstr"), actions: [
        IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => context.push(AppConstants.routeSearch)),
        IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => context.push(AppConstants.routeSettings)),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: "Continue Reading", onTap: () {}),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: _HorizontalBookList(books: books.where((b) => b.progress > 0 && b.progress < 1).toList())),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickAction(icon: Icons.upload_file_rounded, label: "Import", onTap: () {}),
                _QuickAction(icon: Icons.explore_rounded, label: "Browse", onTap: () => context.push(AppConstants.routeBrowse)),
                _QuickAction(icon: Icons.folder_open_rounded, label: "Collections", onTap: () => context.push(AppConstants.routeCollections)),
                _QuickAction(icon: Icons.analytics_rounded, label: "Stats", onTap: () => context.push(AppConstants.routeStatistics)),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: "Recent Books", onTap: () => context.push(AppConstants.routeLibrary)),
            const SizedBox(height: 12),
            _HorizontalBookList(books: books.take(10).toList()),
            const SizedBox(height: 24),
            _SectionTitle(title: "Favorite Collections", onTap: () {}),
            const SizedBox(height: 12),
            SizedBox(height: 100, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: collections.take(10).length, itemBuilder: (context, index) {
              final col = collections[index];
              return Container(width: 160, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Color(col.colorValue), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(col.name, style: const TextStyle(color: Colors.white))));
            })),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _SectionTitle({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: const Text("See All")),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 8), Text(label, style: Theme.of(context).textTheme.labelSmall)]),
      ),
    );
  }
}

class _HorizontalBookList extends StatelessWidget {
  final List<BookModel> books;
  const _HorizontalBookList({required this.books});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(scrollDirection: Axis.horizontal, itemCount: books.length, itemBuilder: (context, index) {
      final book = books[index];
      return GestureDetector(
        onTap: () => context.push("${AppConstants.routeReader}/${book.id}"),
        child: Container(width: 120, margin: const EdgeInsets.only(right: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: book.coverPath != null ? Icon(Icons.menu_book, size: 48) : null)),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
        ])),
      );
    });
  }
}
