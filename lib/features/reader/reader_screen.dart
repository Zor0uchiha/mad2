import "dart:async";
import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:flutter_pdfview/flutter_pdfview.dart";
import "package:epub_view/epub_view.dart";
import "package:path/path.dart" as p;
import "../../core/constants/app_constants.dart";
import "../../core/providers.dart";
import "../../data/models/book_model.dart";
import "../../data/models/bookmark_model.dart";
import "../../data/models/note_model.dart";
import "../../data/models/reading_progress_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";
import "widgets/reader_settings.dart";

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({required this.bookId, super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentPage = 0;
  int _totalPages = 1;
  double _progress = 0.0;
  bool _showControls = true;
  bool _isFullScreen = false;

  double _fontSize = 16.0;
  double _brightness = 1.0;
  ReaderTheme _readerTheme = ReaderTheme.light;

  int _readingSeconds = 0;
  Timer? _timer;
  Timer? _saveTimer;

  late BookModel _book;
  bool _bookLoaded = false;
  bool _continuousScroll = false;
  PDFViewController? _pdfController;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    final book = await ref.read(booksProvider).getBook(widget.bookId);
    if (!mounted) return;

    if (book != null) {
      final progress = await ref.read(readingProgressProvider).getProgress(widget.bookId);
      if (!mounted) return;

      setState(() {
        _book = book;
        _currentPage = progress?.currentPage ?? book.currentPage;
        _totalPages = book.pageCount > 0 ? book.pageCount : 1;
        _progress = progress?.progressPercentage ?? book.progress;
        _bookLoaded = true;
      });
      _startTimers();
    } else {
      setState(() {
        _totalPages = 1;
        _book = BookModel(
          id: widget.bookId,
          title: "Unknown Book",
          author: "Unknown Author",
          format: BookFormat.pdf,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _bookLoaded = true;
      });
    }
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _readingSeconds++);
    });

    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveProgress();
    });
  }

  @override
  void dispose() {
    _saveProgress();
    _timer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final progressRepo = ref.read(readingProgressProvider);
    final bookRepo = ref.read(booksProvider);

    await progressRepo.saveProgress(ReadingProgressModel(
      id: "${widget.bookId}_progress",
      bookId: widget.bookId,
      currentPage: _currentPage,
      progressPercentage: _progress,
      totalPages: _totalPages,
      lastReadAt: DateTime.now(),
      readingTimeMinutes: _readingSeconds ~/ 60,
    ));

    final updatedBook = _book.copyWith(
      currentPage: _currentPage,
      progress: _progress,
      lastOpenedAt: DateTime.now(),
    );
    await bookRepo.updateBook(updatedBook);
    _book = updatedBook;
  }

  void _goToPage(int page) {
    final clamped = page.clamp(0, _totalPages - 1);
    setState(() {
      _currentPage = clamped;
      _progress = _totalPages > 0 ? clamped / _totalPages : 0.0;
    });
    _pdfController?.setPage(clamped);
  }

  Future<void> _addBookmark() async {
    final repo = ref.read(bookmarkRepositoryProvider);
    final bookmark = BookmarkModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      bookTitle: _book.title,
      title: "Page ${_currentPage + 1}",
      pageIndex: _currentPage,
      createdAt: DateTime.now(),
    );
    await repo.addBookmark(bookmark);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bookmark added at page ${_currentPage + 1}")),
      );
    }
  }

  Future<void> _showAddNoteDialog() async {
    final notesRepo = ref.read(noteRepositoryProvider);
    final existingNotes = await notesRepo.getNotesForBook(widget.bookId);
    final note = existingNotes.where((n) => n.pageIndex == _currentPage).firstOrNull;
    final controller = TextEditingController(text: note?.text ?? "");

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Note for Page ${_currentPage + 1}"),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Write your note for this page...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await notesRepo.saveNote(NoteModel(
        id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        bookId: widget.bookId,
        bookTitle: _book.title,
        pageIndex: _currentPage,
        text: result,
        createdAt: note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note saved")),
        );
      }
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showControls = !_isFullScreen;
    });
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReaderSettingsSheet(
        fontSize: _fontSize,
        brightness: _brightness,
        readerTheme: _readerTheme,
        onFontSizeChanged: (v) => setState(() => _fontSize = v),
        onBrightnessChanged: (v) => setState(() => _brightness = v),
        onThemeChanged: (v) => setState(() => _readerTheme = v),
      ),
    );
  }

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Table of Contents",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _totalPages,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(child: Text("${i + 1}")),
                title: Text("Page ${i + 1}"),
                subtitle: i == _currentPage ? const Text("Current page") : null,
                selected: i == _currentPage,
                onTap: () {
                  _goToPage(i);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTapReader(TapUpDetails details) {
    if (_book.filePath == null || _book.filePath!.isEmpty) {
      setState(() => _showControls = !_showControls);
      return;
    }

    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;

    if (x < width / 3) {
      _goToPage(_currentPage - 1);
    } else if (x > width * 2 / 3) {
      _goToPage(_currentPage + 1);
    } else {
      setState(() => _showControls = !_showControls);
    }
  }

  Widget _buildFallbackContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              "Page ${_currentPage + 1}",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: _fontSize * 1.5,
                color: _readerTheme == ReaderTheme.dark ? Colors.white70 : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Reading content placeholder",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: _fontSize,
                color: _readerTheme == ReaderTheme.dark ? Colors.white54 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 5.0,
      child: PDFView(
        filePath: _book.filePath!,
        enableSwipe: true,
        swipeHorizontal: !_continuousScroll,
        autoSpacing: _continuousScroll,
        pageFling: true,
        defaultPage: _currentPage,
        onRender: (pages) {
          if (mounted) {
            setState(() {
              _totalPages = pages ?? 1;
            });
          }
        },
        onViewCreated: (controller) {
          _pdfController = controller;
          if (_currentPage > 0) {
            controller.setPage(_currentPage);
          }
        },
        onPageChanged: (page, total) {
          if (mounted) {
            setState(() {
              if (page != null) _currentPage = page;
              if (total != null && total > 0) {
                _totalPages = total;
                _progress = (page ?? 0) / total;
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("PDF error: $error")),
            );
          }
        },
      ),
    );
  }

  Widget _buildEpubView() {
    try {
      final controller = EpubController(
        document: _loadEpubBook(),
      );
      return EpubView(
        controller: controller,
        onDocumentLoaded: (document) {
          if (mounted) {
            setState(() {
              _totalPages = document.Chapters?.length ?? 1;
            });
          }
        },
        onDocumentError: (error) {
          if (mounted) {
            setState(() => _totalPages = 1);
          }
        },
      );
    } catch (e) {
      return _buildFallbackContent();
    }
  }

  Future<EpubBook> _loadEpubBook() async {
    final file = File(_book.filePath!);
    final bytes = await file.readAsBytes();
    return await EpubReader.readBook(bytes);
  }

  Widget _buildReaderContent() {
    Widget content;
    if (_book.filePath == null || _book.filePath!.isEmpty) {
      content = _buildFallbackContent();
    } else {
      switch (_book.format) {
        case BookFormat.pdf:
          content = _buildPdfView();
        case BookFormat.epub:
          content = _buildEpubView();
      }
    }

    return Stack(
      children: [
        content,
        if (_book.filePath != null && _book.filePath!.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              onTapUp: _onTapReader,
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_bookLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final duration = Duration(seconds: _readingSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final timeStr =
        "${hours > 0 ? "${hours}h " : ""}${minutes}m ${seconds}s";

    return AnnotatedRegion(
      value: _isFullScreen
          ? SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: _showControls
            ? AppBar(
                title: Text(
                  _book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _saveProgress();
                    context.pop();
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.list_rounded),
                    onPressed: _showTableOfContents,
                    tooltip: "Table of Contents",
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_rounded),
                    onPressed: _addBookmark,
                    tooltip: "Add bookmark",
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: _showSettingsSheet,
                    tooltip: "Reading settings",
                  ),
                ],
              )
            : null,
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: _readerTheme == ReaderTheme.dark
                    ? const Color(0xFF1A1A2E)
                    : _readerTheme == ReaderTheme.sepia
                        ? const Color(0xFFF5E6C8)
                        : Colors.white,
                child: _buildReaderContent(),
              ),
            ),
            if (_showControls) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "${_currentPage + 1}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Expanded(
                      child: Slider(
                        value: _currentPage.toDouble(),
                        min: 0,
                        max: (_totalPages - 1).toDouble(),
                        onChanged: (v) => _goToPage(v.toInt()),
                      ),
                    ),
                    Text(
                      "$_totalPages",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  value: _progress,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(_progress * 100).toInt()}%",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_book.filePath != null && _book.filePath!.isNotEmpty)
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _continuousScroll
                                      ? Icons.unfold_more_rounded
                                      : Icons.unfold_less_rounded,
                                ),
                                onPressed: () =>
                                    setState(() => _continuousScroll = !_continuousScroll),
                                tooltip: _continuousScroll
                                    ? "Single page"
                                    : "Continuous scroll",
                                iconSize: 20,
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        IconButton(
                          icon: const Icon(Icons.note_add_rounded),
                          onPressed: _showAddNoteDialog,
                          tooltip: "Add note",
                          iconSize: 20,
                        ),
                        IconButton(
                          icon: Icon(
                            _isFullScreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                          onPressed: _toggleFullScreen,
                          tooltip:
                              _isFullScreen ? "Exit full screen" : "Full screen",
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
