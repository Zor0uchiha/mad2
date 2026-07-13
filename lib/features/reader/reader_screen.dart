import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/constants/app_constants.dart";
import "../../core/providers.dart";
import "../../data/models/book_model.dart";
import "../../data/models/bookmark_model.dart";
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
  late int _totalPages;
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

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  void _loadBook() {
    ref.read(booksProvider).getBook(widget.bookId).then((book) {
      if (!mounted) return;
      if (book != null) {
        setState(() {
          _book = book;
          _currentPage = book.currentPage;
          _totalPages = book.pageCount > 0 ? book.pageCount : 1;
          _progress = book.progress;
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
    });
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
    setState(() {
      _currentPage = page.clamp(0, _totalPages - 1);
      _progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bookmark added at page ${_currentPage + 1}")),
      );
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

  void _onTapReader() {
    setState(() => _showControls = !_showControls);
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
              child: GestureDetector(
                onTap: _onTapReader,
                child: Container(
                  color: _readerTheme == ReaderTheme.dark
                      ? const Color(0xFF1A1A2E)
                      : _readerTheme == ReaderTheme.sepia
                          ? const Color(0xFFF5E6C8)
                          : Colors.white,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Page ${_currentPage + 1}",
                            style:
                                Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontSize: _fontSize * 1.5,
                                      color: _readerTheme == ReaderTheme.dark
                                          ? Colors.white70
                                          : null,
                                    ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Reading content placeholder",
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontSize: _fontSize,
                                      color: _readerTheme == ReaderTheme.dark
                                          ? Colors.white54
                                          : null,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                        IconButton(
                          icon: const Icon(Icons.note_add_rounded),
                          onPressed: () {},
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
