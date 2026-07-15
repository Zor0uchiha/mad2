import "dart:async";
import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:flutter_pdfview/flutter_pdfview.dart";
import "package:epub_view/epub_view.dart";
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

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  int _currentPage = 0;
  int _totalPages = 1;
  double _progress = 0.0;
  bool _showControls = false;
  bool _isFullScreen = false;

  double _fontSize = 16.0;
  double _brightness = 1.0;
  double _fontScale = 1.0;
  ReaderTheme _readerTheme = ReaderTheme.dark;

  int _readingSeconds = 0;
  Timer? _timer;
  Timer? _saveTimer;
  Timer? _hideControlsTimer;

  late BookModel _book;
  bool _bookLoaded = false;
  bool _continuousScroll = false;
  PDFViewController? _pdfController;
  EpubController? _epubController;
  EpubBook? _epubBook;
  List<String> _epubChapterTitles = [];
  int _currentChapterIndex = -1;
  String _currentChapterName = "";
  List<BookmarkModel> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );
    _loadBook();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _timer?.cancel();
    _saveTimer?.cancel();
    _hideControlsTimer?.cancel();
    _tryResetOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  void _tryResetOrientation() {
    if (!_isFullScreen) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );
  }

  Future<void> _loadBook() async {
    final book = await ref.read(booksProvider).getBook(widget.bookId);
    if (!mounted) return;

    _fontScale = ref.read(fontScaleProvider);
    _fontSize = 16.0 * _fontScale;

    if (book != null) {
      final progress =
          await ref.read(readingProgressProvider).getProgress(widget.bookId);
      final bookmarks =
          await ref.read(bookmarkRepositoryProvider).getBookmarksForBook(
        widget.bookId,
      );
      if (!mounted) return;

      setState(() {
        _book = book;
        _currentPage = progress?.currentPage ?? book.currentPage;
        _totalPages = book.pageCount > 0 ? book.pageCount : 1;
        _progress = progress?.progressPercentage ?? book.progress;
        _bookmarks = bookmarks;
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
      if (mounted) {
        setState(() => _readingSeconds++);
      }
    });
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _saveProgress() async {
    if (!_bookLoaded) return;
    final progressRepo = ref.read(readingProgressProvider);
    final bookRepo = ref.read(booksProvider);

    await progressRepo.saveProgress(
      ReadingProgressModel(
        id: "${widget.bookId}_progress",
        bookId: widget.bookId,
        currentPage: _currentPage,
        progressPercentage: _progress,
        totalPages: _totalPages,
        lastReadAt: DateTime.now(),
        readingTimeMinutes: _readingSeconds ~/ 60,
      ),
    );

    final updatedBook = _book.copyWith(
      currentPage: _currentPage,
      progress: _progress,
      lastOpenedAt: DateTime.now(),
      pageCount: _totalPages,
    );
    await bookRepo.updateBook(updatedBook);
    _book = updatedBook;

    if (_readingSeconds >= 60) {
      await ref.read(userRepositoryProvider).updateReadingStreak();
    }
  }

  void _goToPage(int page) {
    final clamped = page.clamp(0, _totalPages - 1);
    setState(() {
      _currentPage = clamped;
      _progress = _totalPages > 0 ? clamped / _totalPages : 0.0;
    });
    _pdfController?.setPage(clamped);
    _updateEpubChapter(clamped);
  }

  void _updateEpubChapter(int page) {
    if (_epubChapterTitles.isEmpty) return;
    final idx = page.clamp(0, _epubChapterTitles.length - 1);
    setState(() {
      _currentChapterIndex = idx;
      _currentChapterName = _epubChapterTitles[idx];
    });
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
    final updated = await repo.getBookmarksForBook(widget.bookId);
    if (mounted) {
      setState(() => _bookmarks = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bookmark added at page ${_currentPage + 1}"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeBookmark(BookmarkModel bookmark) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    await repo.deleteBookmark(bookmark.id);
    final updated = await repo.getBookmarksForBook(widget.bookId);
    if (mounted) {
      setState(() => _bookmarks = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bookmark removed"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  bool get _isCurrentPageBookmarked =>
      _bookmarks.any((b) => b.pageIndex == _currentPage);

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
      final updatedTime = DateTime.now();
      await notesRepo.saveNote(
        NoteModel(
          id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: widget.bookId,
          bookTitle: _book.title,
          pageIndex: _currentPage,
          text: result,
          createdAt: note?.createdAt ?? updatedTime,
          updatedAt: updatedTime,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Note saved"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    controller.dispose();
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Table of Contents",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_epubChapterTitles.isNotEmpty)
                    Text(
                      "${_totalPages} pages",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _epubChapterTitles.isNotEmpty
                  ? ListView.builder(
                      controller: scrollController,
                      itemCount: _epubChapterTitles.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text("${i + 1}", style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(
                          _epubChapterTitles[i],
                          style: TextStyle(
                            fontWeight: i == _currentChapterIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: i == _currentChapterIndex
                            ? const Icon(Icons.bookmark, size: 18)
                            : null,
                        selected: i == _currentChapterIndex,
                        onTap: () {
                          _goToPage(i);
                          Navigator.pop(ctx);
                        },
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _totalPages,
                      itemBuilder: (_, i) => ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text("${i + 1}", style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text("Page ${i + 1}"),
                        subtitle: i == _currentPage
                            ? const Text("Current page")
                            : null,
                        trailing: _bookmarks.any((b) => b.pageIndex == i)
                            ? const Icon(Icons.bookmark_border, size: 18)
                            : null,
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
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Bookmarks",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    "${_bookmarks.length} bookmark${_bookmarks.length == 1 ? "" : "s"}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _bookmarks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No bookmarks yet",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _bookmarks.length,
                      itemBuilder: (_, i) {
                        final bm = _bookmarks[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text("${bm.pageIndex + 1}", style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(bm.title),
                          subtitle: bm.note != null && bm.note!.isNotEmpty
                              ? Text(bm.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _removeBookmark(bm),
                          ),
                          onTap: () {
                            _goToPage(bm.pageIndex);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapReader(TapUpDetails details) {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    }
  }

  Color _getBackgroundColor() {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return const Color(0xFF1A1A2E);
      case ReaderTheme.sepia:
        return const Color(0xFFF5E6C8);
      case ReaderTheme.light:
        return Colors.white;
    }
  }

  Color _getTextColor() {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return Colors.white70;
      case ReaderTheme.sepia:
        return Colors.brown.shade800;
      case ReaderTheme.light:
        return Colors.black87;
    }
  }

  Color _getHintColor() {
    switch (_readerTheme) {
      case ReaderTheme.dark:
        return Colors.white38;
      case ReaderTheme.sepia:
        return Colors.brown.shade400;
      case ReaderTheme.light:
        return Colors.black38;
    }
  }

  Widget _buildFallbackContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 80, color: _getHintColor()),
            const SizedBox(height: 24),
            Text(
              "Page ${_currentPage + 1}",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: _fontSize * 1.5,
                color: _getTextColor(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Reading content placeholder",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: _fontSize,
                color: _getHintColor(),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return PDFView(
      filePath: _book.filePath!,
      enableSwipe: true,
      swipeHorizontal: !_continuousScroll,
      autoSpacing: true,
      pageFling: true,
      defaultPage: _currentPage,
      fitEachPage: true,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) {
        if (mounted && pages != null && pages > 0) {
          setState(() => _totalPages = pages);
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
    );
  }

  Future<EpubBook> _loadEpubBook() async {
    final file = File(_book.filePath!);
    final bytes = await file.readAsBytes();
    return await EpubReader.readBook(bytes);
  }

  Widget _buildEpubView() {
    try {
      final controller = EpubController(
        document: _loadEpubBook(),
      );
      _epubController = controller;

      return EpubView(
        controller: controller,
        onDocumentLoaded: (document) {
          if (!mounted) return;
          final chapters = document.Chapters ?? [];
          final titles = chapters.map((c) => c.Title ?? "Chapter").toList();
          setState(() {
            _epubBook = document;
            _epubChapterTitles = titles;
            _totalPages = titles.isNotEmpty ? titles.length : 1;
            _currentChapterName =
                titles.isNotEmpty ? titles[_currentPage.clamp(0, titles.length - 1)] : "";
            _currentChapterIndex =
                titles.isNotEmpty ? _currentPage.clamp(0, titles.length - 1) : -1;
          });
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

    final brightnessOpacity = (1.0 - _brightness) * 0.65;

    Color themeOverlay = Colors.transparent;
    if (_readerTheme == ReaderTheme.sepia) {
      themeOverlay = const Color(0xFFF5E6C8).withOpacity(0.25);
    } else if (_readerTheme == ReaderTheme.dark) {
      themeOverlay = const Color(0xFF1A1A2E).withOpacity(0.55);
    }

    return Stack(
      children: [
        content,
        if (themeOverlay.opacity > 0.01)
          Positioned.fill(
            child: IgnorePointer(child: Container(color: themeOverlay)),
          ),
        if (brightnessOpacity > 0.01)
          Positioned.fill(
            child: IgnorePointer(child: Container(color: Colors.black.withOpacity(brightnessOpacity))),
          ),
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
    final secs = duration.inSeconds.remainder(60);
    final timeStr = "${hours > 0 ? "${hours}h " : ""}${minutes}m ${secs.toString().padLeft(2, '0')}s";
    final percent = (_progress * 100).toInt();
    final bgColor = _getBackgroundColor();
    final textColor = _getTextColor();
    final hintColor = _getHintColor();

    return AnnotatedRegion(
      value: _isFullScreen
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    color: bgColor,
                    child: _buildReaderContent(),
                  ),
                ),
              ],
            ),
            if (_showControls)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: _buildFloatingControls(bgColor, textColor, hintColor, timeStr, percent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls(Color bgColor, Color textColor, Color hintColor, String timeStr, int percent) {
    return Column(
      children: [
        AnimatedSlide(
          offset: _showControls ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor.withOpacity(0.95),
                  bgColor.withOpacity(0.0),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _saveProgress();
                      context.pop();
                    },
                    color: textColor,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                        if (_currentChapterName.isNotEmpty)
                          Text(_currentChapterName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hintColor, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        AnimatedSlide(
          offset: _showControls ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 250),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor.withOpacity(0.0),
                  bgColor.withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.pages_rounded, size: 14, color: hintColor),
                        const SizedBox(width: 4),
                        Text("${_currentPage + 1} / $_totalPages", style: TextStyle(fontSize: 13, color: textColor)),
                        const Spacer(),
                        Text("$percent%", style: TextStyle(fontSize: 13, color: hintColor)),
                        const SizedBox(width: 12),
                        Icon(Icons.timer_outlined, size: 14, color: hintColor),
                        const SizedBox(width: 4),
                        Text(timeStr, style: TextStyle(fontSize: 13, color: hintColor)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: hintColor.withOpacity(0.2),
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withOpacity(0.12),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: (_currentPage / (_totalPages - 1).clamp(1, _totalPages)).clamp(0.0, 1.0),
                        onChanged: (v) => _goToPage((v * (_totalPages - 1)).round()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(Icons.skip_previous_rounded, "Previous", hintColor, () => _goToPage(_currentPage - 1)),
                        _buildControlButton(Icons.list_rounded, "Contents", hintColor, _showTableOfContents),
                        _buildControlButton(
                          _continuousScroll ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                          "Scroll",
                          hintColor,
                          () => setState(() => _continuousScroll = !_continuousScroll),
                        ),
                        _buildControlButton(Icons.bookmarks_rounded, "Bookmarks", hintColor, _showBookmarksSheet),
                        _buildControlButton(Icons.note_add_rounded, "Note", hintColor, _showAddNoteDialog),
                        _buildControlButton(
                          _isCurrentPageBookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_rounded,
                          "Bookmark",
                          _isCurrentPageBookmarked ? AppColors.accent : hintColor,
                          _isCurrentPageBookmarked
                              ? () {
                                  final bm = _bookmarks.firstWhere(
                                    (b) => b.pageIndex == _currentPage,
                                    orElse: () => _bookmarks.first,
                                  );
                                  _removeBookmark(bm);
                                }
                              : _addBookmark,
                        ),
                        _buildControlButton(Icons.settings_rounded, "Settings", hintColor, _showSettingsSheet),
                        _buildControlButton(
                          _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          "Fullscreen",
                          hintColor,
                          _toggleFullScreen,
                        ),
                        _buildControlButton(Icons.skip_next_rounded, "Next", hintColor, () => _goToPage(_currentPage + 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        color: color,
        splashRadius: 20,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
