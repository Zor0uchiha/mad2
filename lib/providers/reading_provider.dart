import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/repositories/reading_repository.dart';
import '../data/models/bookmark_model.dart';
import '../data/models/note_model.dart';
import '../data/models/reading_progress_model.dart';
import '../data/models/reading_list_model.dart';
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
