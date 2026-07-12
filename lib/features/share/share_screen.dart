import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/services/share_service.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";;

class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider).getRecentBooks(limit: 1);

    return Scaffold(
      appBar: AppBar(title: const Text("Share Card")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(books.isNotEmpty ? books.first.title : "No book", style: const TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 16),
                  const Text("Currently Reading", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Bookstr", style: TextStyle(color: Colors.white.withAlpha(200))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final bytes = await _captureCard(context);
                if (bytes != null) await ShareService.shareImage(bytes, "Currently reading on Bookstr");
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text("Share Card"),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _captureCard(BuildContext context) async {
    final render = context.findRenderObject() as RenderRepaintBoundary?;
    return render != null ? await render.toImage(pixelRatio: 2) : null;
  }
}
