import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/online_book_model.dart";
import "../../data/services/online_book_service.dart";
import "../../data/repositories/local_repositories.dart";

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<OnlineBookModel> _results = [];
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await ref.read(onlineBookServiceProvider).searchBooks(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _results = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Browse Books")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: "Search books, authors..."),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text("Search for books to browse", style: Theme.of(context).textTheme.bodyLarge))
                    : ListView.builder(itemCount: _results.length, itemBuilder: (context, index) {
                        final book = _results[index];
                        return ListTile(
                          leading: book.thumbnail != null ? Image.network(book.thumbnail!, width: 48, fit: BoxFit.cover) : const Icon(Icons.menu_book_rounded),
                          title: Text(book.title),
                          subtitle: Text(book.authors.join(", ")),
                          onTap: () => context.push("${AppConstants.routeBookDetail}/${book.id}"),
                        );
                      }),
          ),
        ],
      ),
    );
  }
}
