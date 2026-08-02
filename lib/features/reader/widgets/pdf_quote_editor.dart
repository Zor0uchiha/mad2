import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/book_model.dart';
import '../../../data/models/quote_model.dart';
import '../../library/pdf_cover_picker.dart';

Future<void> showPdfQuoteEditor(
  BuildContext context,
  BookModel book,
  int pageIndex,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: PdfQuoteEditor(book: book, pageIndex: pageIndex),
    ),
  );
}

class PdfQuoteEditor extends ConsumerStatefulWidget {
  final BookModel book;
  final int pageIndex;

  const PdfQuoteEditor({super.key, required this.book, required this.pageIndex});

  @override
  ConsumerState<PdfQuoteEditor> createState() => _PdfQuoteEditorState();
}

class _PdfQuoteEditorState extends ConsumerState<PdfQuoteEditor> {
  Uint8List? _pageBytes;
  double _pageAspect = 1.0;
  bool _loading = true;

  Offset? _dragStart;
  Offset? _dragEnd;
  bool _dragging = false;

  List<QuoteModel> _pageQuotes = [];
  final GlobalKey _pageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final filePath = widget.book.filePath;
    setState(() => _loading = true);
    try {
      if (filePath == null || filePath.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      PdfDocument? doc;
      try {
        doc = await PdfDocument.openFile(filePath);
        final page = await doc.getPage(widget.pageIndex.clamp(1, doc.pageCount));
        final h = page.height;
        final w = page.width;
        _pageAspect = w > 0 && h > 0 ? h / w : 1.4;
      } catch (_) {
        _pageAspect = 1.4;
      } finally {
        await doc?.dispose();
      }
      final bytes = await renderPdfPageAsPng(filePath, widget.pageIndex, 760);
      if (!mounted) return;
      setState(() {
        _pageBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    final quotes =
        await ref.read(quoteRepositoryProvider).getQuotesForPage(
              widget.book.id,
              widget.pageIndex,
            );
    if (mounted) {
      setState(() => _pageQuotes = quotes);
    }
  }

  Future<void> _saveQuote({double? top, double? bottom}) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Highlight — Page ${widget.pageIndex}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Type the quote / line (optional):"),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "e.g. \"A reader lives a thousand lives...\"",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (saved != true) return;

    final quote = QuoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.book.id,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
      pageIndex: widget.pageIndex,
      text: text,
      normalizedTop: (top ?? 0.0).clamp(0.0, 1.0),
      normalizedBottom: (bottom ?? 0.0).clamp(0.0, 1.0),
      createdAt: DateTime.now(),
    );
    await ref.read(quoteRepositoryProvider).saveQuote(quote);
    ref.invalidate(allQuotesProvider);
    ref.invalidate(quotesForBookProvider);

    final quotes = await ref.read(quoteRepositoryProvider).getQuotesForPage(
          widget.book.id,
          widget.pageIndex,
        );
    if (mounted) {
      setState(() => _pageQuotes = quotes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Highlight saved to Quotes")),
      );
    }
  }

  Future<void> _deleteQuote(QuoteModel quote) async {
    await ref.read(quoteRepositoryProvider).deleteQuote(quote.id);
    ref.invalidate(allQuotesProvider);
    ref.invalidate(quotesForBookProvider);
    if (mounted) {
      setState(() {
        _pageQuotes = _pageQuotes.where((q) => q.id != quote.id).toList();
      });
    }
  }

  Future<void> _shareQuote(QuoteModel quote) async {
    final text = quote.text.isNotEmpty
        ? '"${quote.text}"'
        : "Highlight on page ${quote.pageIndex} of ${widget.book.title}";
    await Share.share("$text\n\n— ${widget.book.title} · ${widget.book.author}");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  "Highlight & Quote",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Drag on the page to highlight a line, then save it as a quote.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pageBytes == null
                    ? const Center(child: Text("Could not render this page."))
                    : _buildPage(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.format_quote, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  "${_pageQuotes.length} saved line${_pageQuotes.length == 1 ? "" : "s"} on this page",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: _pageQuotes.isEmpty
                ? Center(
                    child: Text(
                      "No highlights saved on this page yet.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: _pageQuotes.length,
                    itemBuilder: (ctx, i) {
                      final q = _pageQuotes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.border_color,
                              color: Colors.amber, size: 18),
                          title: Text(
                            q.text.isEmpty ? "(line highlighted)" : q.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "${widget.book.title} · Page ${q.pageIndex}",
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_rounded, size: 18),
                                onPressed: () => _shareQuote(q),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () => _deleteQuote(q),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildPage() {
    final bytes = _pageBytes!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AspectRatio(
                key: _pageKey,
                aspectRatio: 1 / _pageAspect,
                child: GestureDetector(
                  onPanStart: (d) {
                    setState(() {
                      _dragStart = d.localPosition;
                      _dragEnd = d.localPosition;
                      _dragging = true;
                    });
                  },
                  onPanUpdate: (d) {
                    setState(() => _dragEnd = d.localPosition);
                  },
                  onPanEnd: (_) {
                    final start = _dragStart;
                    final end = _dragEnd;
                    setState(() {
                      _dragging = false;
                      _dragStart = null;
                      _dragEnd = null;
                    });
                    if (start != null &&
                        end != null &&
                        (end.dy - start.dy).abs() > 10) {
                      final boxH = _pageKey.currentContext?.size?.height ?? 1.0;
                      final lo = start.dy < end.dy ? start.dy : end.dy;
                      final hi = start.dy < end.dy ? end.dy : start.dy;
                      _saveQuote(top: lo / boxH, bottom: hi / boxH);
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                      CustomPaint(
                        painter: _HighlightPainter(
                          dragStart: _dragging ? _dragStart : null,
                          dragEnd: _dragging ? _dragEnd : null,
                          quotes: _pageQuotes,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final Offset? dragStart;
  final Offset? dragEnd;
  final List<QuoteModel> quotes;

  _HighlightPainter({
    this.dragStart,
    this.dragEnd,
    required this.quotes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawBand(double top, double bottom, Color color) {
      final y0 = top * h;
      final y1 = bottom * h;
      canvas.drawRect(
        Rect.fromLTRB(0, y0, w, y1),
        Paint()..color = color,
      );
    }

    for (final q in quotes) {
      if (q.normalizedBottom > 0) {
        drawBand(q.normalizedTop, q.normalizedBottom, Colors.amber.withOpacity(0.35));
      }
    }

    if (dragStart != null && dragEnd != null) {
      final top = dragStart!.dy < dragEnd!.dy ? dragStart!.dy : dragEnd!.dy;
      final bottom = dragStart!.dy < dragEnd!.dy ? dragEnd!.dy : dragStart!.dy;
      drawBand(top, bottom, Colors.amber.withOpacity(0.45));
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.dragStart != dragStart ||
        oldDelegate.dragEnd != dragEnd ||
        oldDelegate.quotes.length != quotes.length;
  }
}
