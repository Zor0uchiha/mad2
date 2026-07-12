import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/bookmark_model.dart';
import '../models/note_model.dart';
import '../models/reading_progress_model.dart';

class ReadingProgressRepository {
  Box<ReadingProgressModel>? _box;

  Future<Box<ReadingProgressModel>> get _boxAsync async {
    _box ??= await Hive.openBox<ReadingProgressModel>(AppConstants.hiveBoxReadingProgress);
    return _box!;
  }

  Future<void> saveProgress(ReadingProgressModel progress) async {
    final box = await _boxAsync;
    await box.put(progress.id, progress);
  }

  Future<ReadingProgressModel?> getProgress(String bookId) async {
    final box = await _boxAsync;
    final all = box.values.where((p) => p.bookId == bookId).toList();
    if (all.isEmpty) return null;
    all.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return all.first;
  }

  Future<List<ReadingProgressModel>> getAllProgress() async {
    final box = await _boxAsync;
    return box.values.toList();
  }

  Future<void> deleteProgress(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }
}

class BookmarkRepository {
  Box<BookmarkModel>? _box;

  Future<Box<BookmarkModel>> get _boxAsync async {
    _box ??= await Hive.openBox<BookmarkModel>(AppConstants.hiveBoxBookmarks);
    return _box!;
  }

  Future<void> addBookmark(BookmarkModel bookmark) async {
    final box = await _boxAsync;
    await box.put(bookmark.id, bookmark);
  }

  Future<void> updateBookmark(BookmarkModel bookmark) async {
    final box = await _boxAsync;
    await box.put(bookmark.id, bookmark);
  }

  Future<void> deleteBookmark(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }

  Future<BookmarkModel?> getBookmark(String id) async {
    final box = await _boxAsync;
    return box.get(id);
  }

  Future<List<BookmarkModel>> getBookmarksForBook(String bookId) async {
    final box = await _boxAsync;
    return box.values.where((b) => b.bookId == bookId).toList();
  }

  Future<List<BookmarkModel>> getAllBookmarks() async {
    final box = await _boxAsync;
    return box.values.toList();
  }

  Future<List<BookmarkModel>> searchBookmarks(String query) async {
    final box = await _boxAsync;
    final lowerQuery = query.toLowerCase();
    return box.values.where((b) {
      return b.title.toLowerCase().contains(lowerQuery) ||
          (b.note?.toLowerCase().contains(lowerQuery) ?? false) ||
          b.bookTitle.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

class NoteRepository {
  Box<NoteModel>? _box;

  Future<Box<NoteModel>> get _boxAsync async {
    _box ??= await Hive.openBox<NoteModel>(AppConstants.hiveBoxNotes);
    return _box!;
  }

  Future<void> saveNote(NoteModel note) async {
    final box = await _boxAsync;
    if (note.id.isEmpty) {
      note.id = DateTime.now().millisecondsSinceEpoch.toString();
    }
    note.updatedAt = DateTime.now();
    await box.put(note.id, note);
  }

  Future<void> deleteNote(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }

  Future<List<NoteModel>> getNotesForBook(String bookId) async {
    final box = await _boxAsync;
    return box.values.where((n) => n.bookId == bookId).toList();
  }

  Future<List<NoteModel>> getAllNotes() async {
    final box = await _boxAsync;
    return box.values.toList();
  }
}
