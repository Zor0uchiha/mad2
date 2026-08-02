import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import 'highlight_model.dart';

class HighlightsScreen extends ConsumerWidget {
  final String? bookId;

  const HighlightsScreen({super.key, this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        bookId == null
            ? ref.watch(allHighlightsProvider)
            : ref.watch(highlightsForBookProvider(bookId!));

    return Scaffold(
      appBar: AppBar(title: const Text("Highlights")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Could not load highlights.")),
        data: (highlights) => highlights.isEmpty
            ? _buildEmpty(context)
            : _buildList(context, ref, highlights),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.border_color_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            "No highlights yet",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Select any text in a book and tap a highlight color to save it here.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<HighlightModel> highlights,
  ) {
    final grouped = <String, List<HighlightModel>>{};
    for (final h in highlights) {
      final key = h.bookTitle;
      grouped.putIfAbsent(key, () => []).add(h);
    }
    final books = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        for (final book in books)
          _BookGroup(
            bookTitle: book,
            highlights: grouped[book]!,
            onDelete: (h) async {
              await ref.read(highlightRepositoryProvider).deleteHighlight(h.id);
              ref.invalidate(allHighlightsProvider);
              ref.invalidate(highlightsForBookProvider);
            },
            onSave: (h) async {
              await ref.read(highlightRepositoryProvider).saveHighlight(h);
              ref.invalidate(allHighlightsProvider);
              ref.invalidate(highlightsForBookProvider);
            },
          ),
      ],
    );
  }
}

class _BookGroup extends StatelessWidget {
  final String bookTitle;
  final List<HighlightModel> highlights;
  final Future<void> Function(HighlightModel) onDelete;
  final Future<void> Function(HighlightModel) onSave;

  const _BookGroup({
    required this.bookTitle,
    required this.highlights,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final byChapter = <String, List<HighlightModel>>{};
    for (final h in highlights) {
      final key = h.chapterName.isEmpty ? "General" : h.chapterName;
      byChapter.putIfAbsent(key, () => []).add(h);
    }
    final chapters = byChapter.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Text(
            bookTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final chapter in chapters) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Text(
              chapter,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final h in byChapter[chapter]!)
            _HighlightTile(highlight: h, onDelete: onDelete, onSave: onSave),
        ],
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final HighlightModel highlight;
  final Future<void> Function(HighlightModel) onDelete;
  final Future<void> Function(HighlightModel) onSave;

  const _HighlightTile({
    required this.highlight,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(highlightColorValues[highlight.color] ?? 0xFFFFEB3B);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    highlight.text,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Page ${highlight.pageIndex + 1}"
                    "${highlight.underlined ? "  ·  underlined" : ""}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (highlight.note != null && highlight.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        highlight.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: "Edit",
              onPressed: () => _edit(context),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: "Share",
              onPressed: () => Share.share(
                '"${highlight.text}"\n\n— ${highlight.bookTitle} · Page ${highlight.pageIndex + 1}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: "Delete",
              onPressed: () => onDelete(highlight),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    var color = highlight.color;
    var underlined = highlight.underlined;
    final noteController = TextEditingController(text: highlight.note ?? "");

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Edit Highlight"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.text,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text("Color", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final c in HighlightColor.values)
                      InkWell(
                        onTap: () => setState(() => color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(highlightColorValues[c] ?? 0xFFFFEB3B),
                            shape: BoxShape.circle,
                            border: color == c
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: color == c ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Underline"),
                  value: underlined,
                  onChanged: (v) => setState(() => underlined = v ?? false),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Note (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Save")),
          ],
        ),
      ),
    );

    if (saved == true) {
      final now = DateTime.now();
      await onSave(
        highlight.copyWith(
          color: color,
          underlined: underlined,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          updatedAt: now,
        ),
      );
    }
    noteController.dispose();
  }
}
