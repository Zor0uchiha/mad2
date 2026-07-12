import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/collection_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/models/book_model.dart";

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _createCollection() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(collectionsProvider);
    await repo.addCollection(CollectionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider).getAllCollections();

    return Scaffold(
      appBar: AppBar(title: const Text("Collections")),
      body: collections.isEmpty
          ? Center(child: Text("No collections yet", style: Theme.of(context).textTheme.bodyLarge))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final col = collections[index];
                return GestureDetector(
                  onTap: () {},
                  child: Card(
                    color: Color(col.colorValue),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.folder_rounded, size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(col.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text("${col.bookCount} books", style: TextStyle(color: Colors.white.withAlpha(200))),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _createCollection, icon: const Icon(Icons.add_rounded), label: const Text("New Collection")),
    );
  }
}
