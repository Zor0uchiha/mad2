import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/constants/app_constants.dart";

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  const ReaderScreen({required this.bookId, super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentPage = 0;
  int _totalPages = 100;
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showControls ? AppBar(title: Text("Reading"), actions: [IconButton(icon: const Icon(Icons.bookmark_rounded), onPressed: () => context.push("${AppConstants.routeLibrary}/bookmarks"))]) : null,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 24),
                    Text("Your reading content here", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text("PDF or EPUB pages render here", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          if (_showControls) ...[
            Slider(value: _currentPage.toDouble(), max: _totalPages.toDouble(), onChanged: (v) => setState(() => _currentPage = v.toInt())),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () {}, child: const Text("TOC")),
                  Text("Page ${_currentPage + 1} of $_totalPages"),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_add_rounded)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.note_rounded)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.fullscreen_rounded)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.brightness_6_rounded)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
