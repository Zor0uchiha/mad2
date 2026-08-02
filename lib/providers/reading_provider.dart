import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/repositories/reading_repository.dart';
import '../data/models/bookmark_model.dart';
import '../data/models/note_model.dart';
import '../data/models/quote_model.dart';
import '../data/models/reading_progress_model.dart';
import '../data/models/reading_list_model.dart';
import '../features/reader/highlights/highlight_model.dart';
import '../features/reader/highlights/highlight_repository.dart';
import '../core/constants/app_constants.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository();
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository();
});

final readingProgressProvider = Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository();
});

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

final allBookmarksProvider = FutureProvider<List<BookmarkModel>>((ref) async {
  final repo = ref.watch(bookmarkRepositoryProvider);
  return repo.getAllBookmarks();
});

final bookmarksForBookProvider = FutureProvider.family<List<BookmarkModel>, String>((ref, bookId) async {
  final repo = ref.watch(bookmarkRepositoryProvider);
  return repo.getBookmarksForBook(bookId);
});

final allNotesProvider = FutureProvider<List<NoteModel>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.getAllNotes();
});

final notesForBookProvider = FutureProvider.family<List<NoteModel>, String>((ref, bookId) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.getNotesForBook(bookId);
});

final readingListsBoxProvider = FutureProvider<Box<ReadingListModel>>((ref) async {
  return await Hive.openBox<ReadingListModel>(AppConstants.hiveBoxReadingLists);
});

final readingProgressForBookProvider = FutureProvider.family<ReadingProgressModel?, String>((ref, bookId) async {
  final repo = ref.watch(readingProgressProvider);
  return repo.getProgress(bookId);
});

final allQuotesProvider = FutureProvider<List<QuoteModel>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getAllQuotes();
});

final quotesForBookProvider = FutureProvider.family<List<QuoteModel>, String>((ref, bookId) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getQuotesForBook(bookId);
});

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository();
});

final allHighlightsProvider = FutureProvider<List<HighlightModel>>((ref) async {
  final repo = ref.watch(highlightRepositoryProvider);
  return repo.getAllHighlights();
});

final highlightsForBookProvider = FutureProvider.family<List<HighlightModel>, String>((ref, bookId) async {
  final repo = ref.watch(highlightRepositoryProvider);
  return repo.getHighlightsForBook(bookId);
});
