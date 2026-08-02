import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';

/// Full-screen picker that lets the user choose a PDF page to use as the
/// book cover. Returns the chosen 1-indexed page number via `Navigator.pop`.
class PdfCoverPagePicker extends StatefulWidget {
  final String filePath;

  const PdfCoverPagePicker({super.key, required this.filePath});

  @override
  State<PdfCoverPagePicker> createState() => _PdfCoverPagePickerState();
}

class _PdfCoverPagePickerState extends State<PdfCoverPagePicker> {
  PdfDocument? _doc;
  int _pageCount = 0;
  bool _failed = false;
  final Map<int, Future<Uint8List>> _cache = {};

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      if (!mounted) {
        doc.dispose();
        return;
      }
      setState(() {
        _doc = doc;
        _pageCount = doc.pageCount;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Uint8List> _renderPage(int zeroIndex) async {
    final doc = _doc;
    if (doc == null) throw Exception('no document');
    final page = await doc.getPage(zeroIndex + 1);
    const scale = 140.0 / 72.0;
    final fullWidth = page.width * scale;
    final fullHeight = page.height * scale;
    final image = await page.render(
      x: 0,
      y: 0,
      width: fullWidth.round(),
      height: fullHeight.round(),
      fullWidth: fullWidth,
      fullHeight: fullHeight,
    );
    await image.createImageIfNotAvailable();
    final data = await image.imageIfAvailable!.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _thumbnail(int i) {
    return _cache.putIfAbsent(
      i,
      () => _renderPage(i),
    );
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        if (_failed) {
          return const Center(
            child: Text("Could not read this PDF (encrypted or damaged)."),
          );
        }
        if (_pageCount == 0) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    "Choose cover page",
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$_pageCount pages",
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: _pageCount,
                itemBuilder: (ctx, index) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, index + 1),
                    child: Column(
                      children: [
                        Expanded(
                          child: FutureBuilder<Uint8List>(
                            future: _thumbnail(index),
                            builder: (ctx, snap) {
                              if (snap.hasData) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    snap.data!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                );
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${index + 1}",
                          style: Theme.of(ctx).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Convenience helper: render a PDF page (1-indexed) to PNG bytes at a chosen
/// width so it can be stored as a book cover.
Future<Uint8List?> renderPdfPageAsPng(
  String filePath,
  int pageNumber,
  int widthPx,
) async {
  try {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final page = await doc.getPage(pageNumber);
      final scale = widthPx / page.width;
      final fullWidth = page.width * scale;
      final fullHeight = page.height * scale;
      final image = await page.render(
        x: 0,
        y: 0,
        width: fullWidth.round(),
        height: fullHeight.round(),
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      await image.createImageIfNotAvailable();
      final data = await image.imageIfNotAvailable!.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data!.buffer.asUint8List();
    } finally {
      await doc.dispose();
    }
  } catch (_) {
    return null;
  }
}