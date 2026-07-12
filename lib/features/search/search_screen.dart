import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/models/online_book_model.dart";
import "../../data/models/collection_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/services/online_book_service.dart";

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<BookModel> _localResults = [];
  List<OnlineBookModel> _onlineResults = [];
  bool _isOnline = false;
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() { _localResults = []; _onlineResults = []; _isOnline = false; });
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final local = ref.read(booksProvider).searchBooks(query);
      setState(() => _localResults = local);
      final online = await ref.read(onlineBookServiceProvider).searchBooks(query);
      setState(() { _onlineResults = online; _isOnline = true; });
    } catch (e) {
      setState(() { _localResults = []; _onlineResults = []; _isOnline = false; });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: "Search books, authors, collections..."),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (_localResults.isNotEmpty) ...[
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Local", style: Theme.of(context).textTheme.titleSmall)),
                        ..._localResults.map((b) => ListTile(title: Text(b.title), subtitle: Text(b.author), onTap: () => context.push("${AppConstants.routeReader}/${b.id}"))),
                      ],
                      if (_onlineResults.isNotEmpty) ...[
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Online", style: Theme.of(context).textTheme.titleSmall)),
                        ..._onlineResults.map((b) => ListTile(title: Text(b.title), subtitle: Text(b.authors.join(", ")), onTap: () => context.push("${AppConstants.routeBookDetail}/${b.id}"))),
                      ],
                      if (_localResults.isEmpty && _onlineResults.isEmpty && _controller.text.isNotEmpty)
                        Center(child: Padding(padding: const EdgeInsets.all(24), child: Text("No results found", style: Theme.of(context).textTheme.bodyLarge))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
