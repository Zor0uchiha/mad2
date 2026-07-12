import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/reading_list_model.dart";
import "../../data/repositories/local_repositories.dart";

class ReadingListScreen extends ConsumerWidget {
  const ReadingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(readingListsProvider);
    final allLists = lists.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Reading Lists")),
      body: allLists.isEmpty
          ? const Center(child: Text("No reading lists yet."))
          : ListView.builder(
              itemCount: allLists.length,
              itemBuilder: (context, index) {
                final list = allLists[index];
                return Card(
                  child: ListTile(
                    title: Text(list.title),
                    subtitle: Text("${list.bookCount} books"),
                    trailing: Switch(value: list.isPublic, onChanged: (v) {}),
                    onTap: () {},
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text("New List")),
    );
  }
}
