import "package:hive_flutter/hive_flutter.dart";
import "../constants/app_constants.dart";
import "../models/reading_progress_model.dart";
import "../models/bookmark_model.dart";
import "../models/note_model.dart";
import "../../core/errors/app_exception.dart";

class ReadingProgressRepository {
  static const String boxName = AppConstants.hiveBoxReadingProgress;
  final Box<ReadingProgressModel> _box;

  ReadingProgressRepository(this._box);

  Future<void> saveProgress(ReadingProgressModel progress) async {
    try {
      await _box.put(progress.id, progress);
    } catch (e) {
      throw StorageException("Failed to save reading progress", originalError: e);
    }
  }

  ReadingProgressModel? getProgress(String bookId) {
    try {
      final all = _box.values.where((p) => p.bookId == bookId).toList();
      if (all.isEmpty) return null;
      all.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      return all.first;
    } catch (e) {
      return null;
    }
  }
}

class BookmarkRepository {
  static const String boxName = AppConstants.hiveBoxBookmarks;
  final Box<BookmarkModel> _box;

  BookmarkRepository(this._box);

  Future<void> addBookmark(BookmarkModel bookmark) async {
    try {
      await _box.put(bookmark.id, bookmark);
    } catch (e) {
      throw StorageException("Failed to add bookmark", originalError: e);
    }
  }

  Future<void> deleteBookmark(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException("Failed to delete bookmark", originalError: e);
    }
  }

  List<BookmarkModel> getBookmarksForBook(String bookId) =>
      _box.values.where((b) => b.bookId == bookId).toList();

  List<BookmarkModel> getAllBookmarks() => _box.values.toList();
}

class NoteRepository {
  static const String boxName = AppConstants.hiveBoxNotes;
  final Box<NoteModel> _box;

  NoteRepository(this._box);

  Future<void> saveNote(NoteModel note) async {
    try {
      if (note.id.isEmpty) note.id = DateTime.now().millisecondsSinceEpoch.toString();
      note.updatedAt = DateTime.now();
      await _box.put(note.id, note);
    } catch (e) {
      throw StorageException("Failed to save note", originalError: e);
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException("Failed to delete note", originalError: e);
    }
  }

  List<NoteModel> getNotesForBook(String bookId) =>
      _box.values.where((n) => n.bookId == bookId).toList();

  List<NoteModel> getAllNotes() => _box.values.toList();
}
