import "dart:async";
import "dart:io";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:flutter_pdfview/flutter_pdfview.dart";
import "package:share_plus/share_plus.dart";
import "package:wakelock_plus/wakelock_plus.dart";
import "../../core/constants/app_constants.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/bookmark_model.dart";
import "../../data/models/note_model.dart";
import "../../data/models/reading_progress_model.dart";
import "../../data/models/quote_model.dart";
import "reader_preferences.dart";
import "epub/epub_parser.dart";
import "epub/epub_reader_view.dart";
import "highlights/highlight_model.dart";
import "widgets/ai_tools.dart";
import "widgets/reader_selection_toolbar.dart";
import "widgets/reader_tools_sheet.dart";
import "widgets/reader_style_sheet.dart";
import "widgets/pdf_quote_editor.dart";

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

  int _readingSeconds = 0;
  Timer? _timer;
  Timer? _saveTimer;
  Timer? _hideControlsTimer;

  late BookModel _book;
  bool _bookLoaded = false;
  PDFViewController? _pdfController;

  ParsedEpub? _epub;
  bool _epubLoaded = false;
  int _currentChapterIndex = 0;
  double _epubScrollFraction = 0.0;
  int _epubPage = 0;
  final GlobalKey<EpubReaderViewState> _epubViewKey =
      GlobalKey<EpubReaderViewState>();

  List<BookmarkModel> _bookmarks = [];
  List<HighlightModel> _highlights = [];
  String _lastSelection = "";
  bool _lastKeepAwake = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _loadBook();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _timer?.cancel();
    _saveTimer?.cancel();
    _hideControlsTimer?.cancel();
    ReaderAiTools.stopSpeaking();
    _tryResetOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  void _tryResetOrientation() {
    if (!_isFullScreen) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  bool get _isPdf => _book.format == BookFormat.pdf;
  bool get _isEpub => _book.format == BookFormat.epub;

  Future<void> _loadBook() async {
    await ref.read(readerPreferencesProvider.notifier).load();
    final prefs = ref.read(readerPreferencesProvider);
    final book = await ref.read(booksProvider).getBook(widget.bookId);
    if (!mounted) return;

    if (book != null) {
      final progress = await ref.read(readingProgressProvider).getProgress(widget.bookId);
      final bookmarks = await ref.read(bookmarkRepositoryProvider).getBookmarksForBook(widget.bookId);
      final highlights = await ref.read(highlightRepositoryProvider).getHighlightsForBook(widget.bookId);
      if (!mounted) return;

      setState(() {
        _book = book;
        _currentPage = progress?.currentPage ?? book.currentPage;
        _totalPages = book.pageCount > 0 ? book.pageCount : 1;
        _progress = progress?.progressPercentage ?? book.progress;
        _bookmarks = bookmarks;
        _highlights = highlights;
        _bookLoaded = true;
      });

      if (_isEpub) {
        _loadEpub(book, progress);
      }
      _startTimers();
      _applyKeepAwake(prefs.keepScreenAwake);
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

  Future<void> _loadEpub(BookModel book, ReadingProgressModel? progress) async {
    final path = book.filePath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _epubLoaded = true);
      return;
    }
    final epub = await EpubParser.parseFile(path);
    if (!mounted) return;
    if (epub == null || epub.chapters.isEmpty) {
      setState(() => _epubLoaded = true);
      return;
    }
    final total = epub.chapters.length;
    final chapterIdx = (progress?.currentPage ?? book.currentPage).clamp(0, total - 1).toInt();
    var fraction = 0.0;
    if (progress != null && progress.progressPercentage > 0) {
      fraction = (progress.progressPercentage * total - chapterIdx).clamp(0.0, 1.0).toDouble();
    }
    setState(() {
      _epub = epub;
      _epubLoaded = true;
      _currentChapterIndex = chapterIdx;
      _epubScrollFraction = fraction;
      _totalPages = total;
      _currentChapterName = epub.chapters[chapterIdx].title;
    });
  }

  String _currentChapterName = "";

  void _startTimers() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _readingSeconds++);
    });
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _saveProgress() async {
    if (!_bookLoaded) return;
    final progressRepo = ref.read(readingProgressProvider);
    final bookRepo = ref.read(booksProvider);

    var currentPage = _currentPage;
    var totalPages = _totalPages;
    var progressFraction = _progress;

    if (_isEpub && _epub != null && _epub!.chapters.isNotEmpty) {
      totalPages = _epub!.chapters.length;
      currentPage = _currentChapterIndex;
      final frac = _epubScrollFraction.clamp(0.0, 1.0).toDouble();
      progressFraction = (currentPage + frac) / totalPages;
    } else if (_isPdf) {
      progressFraction = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    }

    await progressRepo.saveProgress(
      ReadingProgressModel(
        id: "${widget.bookId}_progress",
        bookId: widget.bookId,
        currentPage: currentPage,
        progressPercentage: progressFraction,
        totalPages: totalPages,
        lastReadAt: DateTime.now(),
        readingTimeMinutes: _readingSeconds ~/ 60,
      ),
    );

    if (!mounted) return;

    final updatedBook = _book.copyWith(
      currentPage: currentPage,
      progress: progressFraction,
      lastOpenedAt: DateTime.now(),
      pageCount: totalPages,
    );
    await bookRepo.updateBook(updatedBook);
    _book = updatedBook;
    ref.invalidate(allBooksProvider);

    if (_readingSeconds >= 60) {
      await ref.read(userRepositoryProvider).updateReadingStreak();
    }
  }

  void _applyKeepAwake(bool enabled) {
    if (enabled) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _goToChapter(int index) {
    if (_epub == null || index < 0 || index >= _epub!.chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
      _epubScrollFraction = 0.0;
      _epubPage = 0;
      _currentChapterName = _epub!.chapters[index].title;
      _currentPage = index;
      _progress = _epub!.chapters.length > 0 ? index / _epub!.chapters.length : 0.0;
    });
    _saveProgress();
  }

  void _goToPdfPage(int page) {
    final clamped = page.clamp(0, _totalPages - 1).toInt();
    setState(() {
      _currentPage = clamped;
      _progress = _totalPages > 0 ? clamped / _totalPages : 0.0;
    });
    _pdfController?.setPage(clamped);
  }

  bool get _isCurrentPageBookmarked {
    final target = _isEpub ? _currentChapterIndex : _currentPage;
    return _bookmarks.any((b) => b.pageIndex == target);
  }

  Future<void> _addBookmark() async {
    final repo = ref.read(bookmarkRepositoryProvider);
    final target = _isEpub ? _currentChapterIndex : _currentPage;
    final title = _isEpub
        ? "Chapter ${_currentChapterIndex + 1}"
        : "Page ${target + 1}";
    final bookmark = BookmarkModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      bookTitle: _book.title,
      title: title,
      pageIndex: target,
      createdAt: DateTime.now(),
    );
    await repo.addBookmark(bookmark);
    final updated = await repo.getBookmarksForBook(widget.bookId);
    if (mounted) {
      setState(() => _bookmarks = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bookmark added · $title"),
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
        const SnackBar(content: Text("Bookmark removed"), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _showAddNoteDialog() async {
    final notesRepo = ref.read(noteRepositoryProvider);
    final existingNotes = await notesRepo.getNotesForBook(widget.bookId);
    final pageIndex = _isEpub ? _currentChapterIndex : _currentPage;
    final note = existingNotes.where((n) => n.pageIndex == pageIndex).firstOrNull;
    final controller = TextEditingController(text: note?.text ?? "");

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Note — ${_isEpub ? "Chapter ${pageIndex + 1}" : "Page ${pageIndex + 1}"}"),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Write your note...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Save")),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final now = DateTime.now();
      await notesRepo.saveNote(
        NoteModel(
          id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: widget.bookId,
          bookTitle: _book.title,
          pageIndex: pageIndex,
          text: result,
          createdAt: note?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note saved"), duration: Duration(seconds: 2)),
        );
      }
    }
    controller.dispose();
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showToolsSheet() {
    final delegate = ReaderToolsDelegate(
      onTableOfContents: _showTableOfContents,
      onBookmarks: _showBookmarksSheet,
      onAddNote: _showAddNoteDialog,
      onNotes: () => context.push(AppConstants.routeNotes),
      onSearch: _showSearchSheet,
      onHighlights: () => context.push("${AppConstants.routeHighlights}?bookId=${widget.bookId}"),
      onQuoteEditor: _showPdfQuoteEditor,
      onGoToPage: _showGoToPage,
      onToggleFullscreen: _toggleFullScreen,
      onTypography: _showStyleSheet,
      onAiExplain: () => _runTextTool((t) => ReaderAiTools.localExplain(t)),
      onAiSummarize: () => _runTextTool((t) => ReaderAiTools.localSummarize(t)),
      onDictionary: _dictionaryTool,
      onTranslate: _translateTool,
      onReadAloud: _readAloudTool,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderToolsSheet(delegate: delegate),
    );
  }

  void _showStyleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReaderStyleSheet(),
    );
  }

  void _showPdfQuoteEditor() {
    if (_isPdf) {
      showPdfQuoteEditor(context, _book, _currentPage + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select text on the page, then tap a highlight color.")),
      );
    }
  }

  void _showGoToPage() {
    if (_isPdf) {
      final controller = TextEditingController(text: "${_currentPage + 1}");
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Go to page"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Page number"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text.trim()) ?? 1;
                _goToPdfPage(page - 1);
                Navigator.pop(ctx);
              },
              child: const Text("Go"),
            ),
          ],
        ),
      );
    } else if (_epub != null) {
      _showTableOfContents();
    }
  }

  void _showTableOfContents() {
    if (_isEpub && _epub != null) {
      _showChapterList();
    } else {
      _showPageList();
    }
  }

  void _showChapterList() {
    final chapters = _epub!.chapters;
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
                  Text("Contents", style: Theme.of(context).textTheme.titleLarge),
                  Text("${chapters.length} chapters", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: chapters.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text("${i + 1}", style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(
                    chapters[i].title,
                    style: TextStyle(
                      fontWeight: i == _currentChapterIndex ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: i == _currentChapterIndex ? const Icon(Icons.bookmark, size: 18) : null,
                  selected: i == _currentChapterIndex,
                  onTap: () {
                    _goToChapter(i);
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

  void _showPageList() {
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
                  Text("Pages", style: Theme.of(context).textTheme.titleLarge),
                  Text("$_totalPages pages", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _totalPages,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(radius: 16, child: Text("${i + 1}", style: const TextStyle(fontSize: 12))),
                  title: Text("Page ${i + 1}"),
                  subtitle: i == _currentPage ? const Text("Current page") : null,
                  trailing: _bookmarks.any((b) => b.pageIndex == i) ? const Icon(Icons.bookmark_border, size: 18) : null,
                  selected: i == _currentPage,
                  onTap: () {
                    _goToPdfPage(i);
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
                  Text("Bookmarks", style: Theme.of(context).textTheme.titleLarge),
                  Text("${_bookmarks.length} bookmark${_bookmarks.length == 1 ? "" : "s"}", style: Theme.of(context).textTheme.bodySmall),
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
                          Icon(Icons.bookmark_border, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text("No bookmarks yet", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _bookmarks.length,
                      itemBuilder: (_, i) {
                        final bm = _bookmarks[i];
                        return ListTile(
                          leading: CircleAvatar(radius: 16, child: Text("${bm.pageIndex + 1}", style: const TextStyle(fontSize: 12))),
                          title: Text(bm.title),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _removeBookmark(bm),
                          ),
                          onTap: () {
                            if (_isEpub) {
                              _goToChapter(bm.pageIndex);
                            } else {
                              _goToPdfPage(bm.pageIndex);
                            }
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

  void _showSearchSheet() {
    if (!_isEpub || _epub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Text search is available for EPUB books.")),
      );
      return;
    }
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SearchSheet(
          controller: controller,
          epub: _epub!,
          currentChapter: _currentChapterIndex,
          onOpenChapter: (i) {
            _goToChapter(i);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _currentTextForTools() {
    if (_lastSelection.trim().isNotEmpty) return _lastSelection;
    if (_isEpub && _epub != null && _currentChapterIndex < _epub!.chapters.length) {
      final text = _epub!.chapters[_currentChapterIndex].plainText.trim();
      if (text.isNotEmpty) return text.length > 1500 ? text.substring(0, 1500) : text;
    }
    return "";
  }

  void _runTextTool(String Function(String) fn) {
    final text = _currentTextForTools();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No text available. Select some text on the page first.")),
      );
      return;
    }
    ReaderAiTools.showResultDialog(context, "Result", fn(text));
  }

  void _dictionaryTool() {
    final text = _currentTextForTools();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No text available to look up.")));
      return;
    }
    final word = text.split(RegExp(r'\s+')).first;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Dictionary"),
        content: const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
    ReaderAiTools.dictionaryLookup(word).then((result) {
      if (!mounted) return;
      Navigator.pop(context);
      ReaderAiTools.showResultDialog(context, "Dictionary · $word", result);
    });
  }

  void _translateTool() {
    final text = _currentTextForTools();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No text available to translate.")));
      return;
    }
    const langs = <(String, String)>[
      ("en", "English"),
      ("es", "Spanish"),
      ("fr", "French"),
      ("de", "German"),
      ("hi", "Hindi"),
      ("ar", "Arabic"),
      ("zh-CN", "Chinese"),
      ("ja", "Japanese"),
    ];
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Translate to"),
        children: [
          for (final (code, name) in langs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, code),
              child: Text(name),
            ),
        ],
      ),
    ).then((code) {
      if (code == null || !mounted) return;
      ReaderAiTools.translateText(text, toLang: code).then((result) {
        if (!mounted) return;
        ReaderAiTools.showResultDialog(context, "Translation", result);
      });
    });
  }

  void _readAloudTool() {
    final text = _currentTextForTools();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No text available to read aloud.")));
      return;
    }
    ReaderAiTools.speak(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reading aloud..."), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _saveHighlight(
    String text,
    HighlightColor color, {
    bool underlined = false,
    String? note,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final now = DateTime.now();
    final highlight = HighlightModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      bookTitle: _book.title,
      chapterName: _isEpub ? _currentChapterName : "Page ${_currentPage + 1}",
      pageIndex: _isEpub ? _currentChapterIndex : _currentPage,
      text: clean,
      note: note,
      color: color,
      underlined: underlined,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(highlightRepositoryProvider).saveHighlight(highlight);
    ref.invalidate(allHighlightsProvider);
    ref.invalidate(highlightsForBookProvider);
    if (mounted) {
      final updated = await ref.read(highlightRepositoryProvider).getHighlightsForBook(widget.bookId);
      if (mounted) setState(() => _highlights = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Highlight saved"), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _saveQuote(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final quote = QuoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      bookTitle: _book.title,
      bookAuthor: _book.author,
      pageIndex: _isEpub ? _currentChapterIndex : _currentPage,
      text: clean,
      createdAt: DateTime.now(),
    );
    await ref.read(quoteRepositoryProvider).saveQuote(quote);
    ref.invalidate(allQuotesProvider);
    ref.invalidate(quotesForBookProvider);
    if (!mounted) return;
    context.push(
      "${AppConstants.routeQuoteCard}"
      "?quote=${Uri.encodeComponent(clean)}"
      "&title=${Uri.encodeComponent(_book.title)}"
      "&author=${Uri.encodeComponent(_book.author)}"
      "&bookId=${widget.bookId}"
      "&page=${_isEpub ? _currentChapterIndex : _currentPage}"
      "&chapter=${Uri.encodeComponent(_isEpub ? _currentChapterName : "")}",
    );
  }

  Future<void> _addNoteToSelection(String text) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text, maxLines: 3),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(hintText: "Your note...", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Save")),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await _saveHighlight(text, HighlightColor.yellow, note: result.trim());
    }
  }

  void _onSelectionAction(ReaderSelectionAction action, String text) {
    _lastSelection = text;
    switch (action) {
      case ReaderSelectionAction.highlightYellow:
        _saveHighlight(text, HighlightColor.yellow);
        break;
      case ReaderSelectionAction.highlightGreen:
        _saveHighlight(text, HighlightColor.green);
        break;
      case ReaderSelectionAction.highlightBlue:
        _saveHighlight(text, HighlightColor.blue);
        break;
      case ReaderSelectionAction.highlightPink:
        _saveHighlight(text, HighlightColor.pink);
        break;
      case ReaderSelectionAction.highlightOrange:
        _saveHighlight(text, HighlightColor.orange);
        break;
      case ReaderSelectionAction.highlightPurple:
        _saveHighlight(text, HighlightColor.purple);
        break;
      case ReaderSelectionAction.underline:
        _saveHighlight(text, HighlightColor.blue, underlined: true);
        break;
      case ReaderSelectionAction.note:
        _addNoteToSelection(text);
        break;
      case ReaderSelectionAction.copy:
        Clipboard.setData(ClipboardData(text: text));
        _snack("Copied");
        break;
      case ReaderSelectionAction.translate:
        _translateTool();
        break;
      case ReaderSelectionAction.dictionary:
        _dictionaryTool();
        break;
      case ReaderSelectionAction.explain:
        _runTextTool((t) => ReaderAiTools.localExplain(t));
        break;
      case ReaderSelectionAction.summarize:
        _runTextTool((t) => ReaderAiTools.localSummarize(t));
        break;
      case ReaderSelectionAction.readAloud:
        ReaderAiTools.speak(text);
        break;
      case ReaderSelectionAction.share:
        Share.share('"$text"');
        break;
      case ReaderSelectionAction.saveQuote:
        _saveQuote(text);
        break;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onTapReader(TapUpDetails details) {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  Color _hintColor() {
    final spec = ref.watch(readerPreferencesProvider).themeSpec;
    return spec.hint;
  }

  @override
  Widget build(BuildContext context) {
    if (!_bookLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final prefs = ref.watch(readerPreferencesProvider);
    if (prefs.keepScreenAwake != _lastKeepAwake) {
      _lastKeepAwake = prefs.keepScreenAwake;
      _applyKeepAwake(prefs.keepScreenAwake);
    }

    final bgColor = prefs.themeSpec.background;
    final textColor = prefs.highContrast ? Colors.black : prefs.themeSpec.text;
    final hintColor = prefs.themeSpec.hint;
    final duration = Duration(seconds: _readingSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    final timeStr = "${hours > 0 ? "${hours}h " : ""}${minutes}m ${secs.toString().padLeft(2, '0')}s";
    final percent = (_progress * 100).toInt();

    final highlights = _isEpub
        ? ref.watch(highlightsForBookProvider(widget.bookId)).valueOrNull ?? _highlights
        : _highlights;

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
            Positioned.fill(child: _buildReaderContent(prefs, highlights)),
            if (_showControls)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: _buildChrome(bgColor, textColor, hintColor, timeStr, percent, prefs),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderContent(ReaderPreferences prefs, List<HighlightModel> highlights) {
    Widget content;
    if (_isPdf) {
      content = _buildPdfView();
    } else if (_isEpub) {
      if (!_epubLoaded || _epub == null || _epub!.chapters.isEmpty) {
        content = _buildLoading();
      } else {
        content = _buildEpubView(prefs, highlights);
      }
    } else {
      content = _buildFallbackContent();
    }

    final brightnessOpacity = (1.0 - prefs.brightness) * 0.65;

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (brightnessOpacity > 0.01)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(brightnessOpacity)),
            ),
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

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 16),
          Text("Opening book..."),
        ],
      ),
    );
  }

  Widget _buildFallbackContent() {
    final hint = _hintColor();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 72, color: hint),
          const SizedBox(height: 16),
          Text("Could not open this book.", style: TextStyle(color: hint)),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
    final filePath = _book.filePath;
    if (filePath == null || filePath.isEmpty || !_isValidPdfFile(filePath)) {
      return _buildFallbackContent();
    }
    return PDFView(
      filePath: filePath,
      enableSwipe: true,
      swipeHorizontal: !ref.watch(readerPreferencesProvider).verticalScroll,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitEachPage: true,
      fitPolicy: FitPolicy.BOTH,
      defaultPage: _currentPage,
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

  Widget _buildEpubView(ReaderPreferences prefs, List<HighlightModel> highlights) {
    final chapter = _epub!.chapters[_currentChapterIndex];
    final paged = !prefs.verticalScroll;
    return Column(
      children: [
        Expanded(
          child: EpubReaderView(
            key: _epubViewKey,
            chapter: chapter,
            prefs: prefs,
            highlights: highlights,
            paged: paged,
            initialScrollFraction: _epubScrollFraction,
            initialPage: _epubPage,
            onScrollFraction: (f) => _epubScrollFraction = f,
            onPageChanged: (p) {
              _epubPage = p;
              setState(() {
                _currentPage = _currentChapterIndex;
                _progress = _epub!.chapters.length > 0
                    ? (_currentChapterIndex + (paged && _epubViewKey.currentState != null
                            ? (p / (_epubViewKey.currentState!.pageCount > 1 ? _epubViewKey.currentState!.pageCount - 1 : 1))
                            : 0.0)) /
                        _epub!.chapters.length
                    : 0.0;
              });
            },
            onSelection: _onSelectionAction,
          ),
        ),
      ],
    );
  }

  bool _isValidPdfFile(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final raf = file.openSync();
      final bytes = raf.readSync(4);
      raf.closeSync();
      return bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
    } catch (_) {
      return false;
    }
  }

  Widget _buildChrome(
    Color bgColor,
    Color textColor,
    Color hintColor,
    String timeStr,
    int percent,
    ReaderPreferences prefs,
  ) {
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
                colors: [bgColor.withOpacity(0.97), bgColor.withOpacity(0.0)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
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
                          Text(
                            _book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (_currentChapterName.isNotEmpty)
                            Text(
                              _currentChapterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: hintColor, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, size: 22),
                      tooltip: "Search in book",
                      onPressed: _showSearchSheet,
                      color: textColor,
                    ),
                    IconButton(
                      icon: Icon(
                        _isCurrentPageBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 22,
                        color: _isCurrentPageBookmarked ? AppColors.accent : textColor,
                      ),
                      tooltip: _isCurrentPageBookmarked ? "Remove bookmark" : "Add bookmark",
                      onPressed: () {
                        if (_isCurrentPageBookmarked) {
                          final target = _isEpub ? _currentChapterIndex : _currentPage;
                          final bm = _bookmarks.where((b) => b.pageIndex == target).firstOrNull;
                          if (bm != null) _removeBookmark(bm);
                        } else {
                          _addBookmark();
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: textColor),
                      color: bgColor,
                      onSelected: (value) {
                        switch (value) {
                          case "contents":
                            _showTableOfContents();
                            break;
                          case "bookmarks":
                            _showBookmarksSheet();
                            break;
                          case "highlights":
                            context.push("${AppConstants.routeHighlights}?bookId=${widget.bookId}");
                            break;
                          case "notes":
                            context.push(AppConstants.routeNotes);
                            break;
                          case "fullscreen":
                            _toggleFullScreen();
                            break;
                          case "typography":
                            _showStyleSheet();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: "contents", child: _menuItem(Icons.list_rounded, "Table of Contents")),
                        PopupMenuItem(value: "bookmarks", child: _menuItem(Icons.bookmarks_rounded, "Bookmarks")),
                        PopupMenuItem(value: "highlights", child: _menuItem(Icons.highlight_rounded, "Highlights")),
                        PopupMenuItem(value: "notes", child: _menuItem(Icons.notes_rounded, "My Notes")),
                        PopupMenuItem(value: "typography", child: _menuItem(Icons.text_fields_rounded, "Typography")),
                        PopupMenuItem(
                          value: "fullscreen",
                          child: _menuItem(_isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, "Fullscreen"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        AnimatedSlide(
          offset: _showControls ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgColor.withOpacity(0.0), bgColor.withOpacity(0.97)],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _pageLabel(),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: hintColor.withOpacity(0.25),
                              thumbColor: AppColors.accent,
                              overlayColor: AppColors.accent.withOpacity(0.12),
                            ),
                            child: Slider(
                              value: _progress.clamp(0.0, 1.0).toDouble(),
                              onChanged: _isPdf
                                  ? (v) => _goToPdfPage((v * (_totalPages - 1)).round())
                                  : (v) {
                                      if (_epub != null && _epub!.chapters.isNotEmpty) {
                                        final target = (v * _epub!.chapters.length).floor().clamp(0, _epub!.chapters.length - 1).toInt();
                                        if (target != _currentChapterIndex) _goToChapter(target);
                                      }
                                    },
                            ),
                          ),
                        ),
                        Text(
                          "$percent% · $timeStr",
                          style: TextStyle(fontSize: 11, color: hintColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 30),
                          color: textColor,
                          onPressed: () {
                            if (_isPdf) {
                              _goToPdfPage(_currentPage - 1);
                            } else {
                              _epubViewKey.currentState?.previousPage();
                            }
                          },
                        ),
                        FilledButton.icon(
                          onPressed: _showToolsSheet,
                          icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                          label: const Text("Tools"),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 30),
                          color: textColor,
                          onPressed: () {
                            if (_isPdf) {
                              _goToPdfPage(_currentPage + 1);
                            } else {
                              _epubViewKey.currentState?.nextPage();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _pageLabel() {
    if (_isEpub) {
      if (_epub == null) return "";
      final paged = !ref.read(readerPreferencesProvider).verticalScroll;
      if (paged) {
        final state = _epubViewKey.currentState;
        final count = state?.pageCount ?? 1;
        final page = state?.currentPage ?? 0;
        return "${_currentChapterIndex + 1}/${_epub!.chapters.length} · Page ${page + 1}/$count";
      }
      return "Chapter ${_currentChapterIndex + 1}/${_epub!.chapters.length}";
    }
    return "${_currentPage + 1}/$_totalPages";
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final TextEditingController controller;
  final ParsedEpub epub;
  final int currentChapter;
  final ValueChanged<int> onOpenChapter;

  const _SearchSheet({
    required this.controller,
    required this.epub,
    required this.currentChapter,
    required this.onOpenChapter,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  List<(int, int, String)> _results = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final query = widget.controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final results = <(int, int, String)>[];
    for (var c = 0; c < widget.epub.chapters.length; c++) {
      final plain = widget.epub.chapters[c].plainText;
      final lower = plain.toLowerCase();
      var idx = lower.indexOf(query);
      var hits = 0;
      while (idx != -1 && hits < 5) {
        final start = (idx - 40).clamp(0, plain.length);
        final end = (idx + query.length + 80).clamp(0, plain.length);
        final snippet = plain.substring(start, end).replaceAll('\n', ' ');
        results.add((c, idx, snippet));
        hits++;
        idx = lower.indexOf(query, idx + 1);
      }
    }
    setState(() => _results = results.take(50).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text("Search in book", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: "Search within the book...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      widget.controller.text.trim().isEmpty
                          ? "Type something to search the whole book."
                          : "No matches found.",
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final (chapter, _, snippet) = _results[i];
                      return ListTile(
                        leading: CircleAvatar(radius: 14, child: Text("${chapter + 1}", style: const TextStyle(fontSize: 11))),
                        title: Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          widget.epub.chapters[chapter].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => widget.onOpenChapter(chapter),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
