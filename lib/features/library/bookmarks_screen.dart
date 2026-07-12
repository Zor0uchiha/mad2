import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/bookmark_model.dart";
import "../../data/models/note_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider).getAllBookmarks();

    return Scaffold(
      appBar: AppBar(title: const Text("Bookmarks & Notes")),
      body: bookmarks.isEmpty
          ? const Center(child: Text("No bookmarks or notes yet."))
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  leading: const Icon(Icons.bookmark_rounded),
                  title: Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title),
                  subtitle: Text("Page ${bookmark.pageIndex + 1}"),
                  onTap: () => context.push("${AppConstants.routeReader}/${bookmark.bookId}"),
                );
              },
            ),
    );
  }
}
