import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/book_model.dart';

class BookRepository {
  Box<BookModel>? _box;

  Future<Box<BookModel>> get _boxAsync async {
    _box ??= await Hive.openBox<BookModel>(AppConstants.hiveBoxBooks);
    return _box!;
  }

  Future<void> addBook(BookModel book) async {
    final box = await _boxAsync;
    await box.put(book.id, book);
  }

  Future<void> updateBook(BookModel book) async {
    final box = await _boxAsync;
    book.updatedAt = DateTime.now();
    await box.put(book.id, book);
  }

  Future<void> deleteBook(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }

  Future<BookModel?> getBook(String id) async {
    final box = await _boxAsync;
    return box.get(id);
  }

  Future<List<BookModel>> getAllBooks() async {
    final box = await _boxAsync;
    return box.values.toList();
  }

  Future<List<BookModel>> getFavoriteBooks() async {
    final box = await _boxAsync;
    return box.values.where((b) => b.isFavorite).toList();
  }

  Future<List<BookModel>> getRecentBooks({int limit = 20}) async {
    final box = await _boxAsync;
    final books = box.values.toList();
    books.sort((a, b) => (b.lastOpenedAt ?? DateTime(2000)).compareTo(a.lastOpenedAt ?? DateTime(2000)));
    return books.take(limit).toList();
  }

  Future<List<BookModel>> getContinueReading() async {
    final box = await _boxAsync;
    return box.values.where((b) => b.progress > 0 && b.progress < 1).toList();
  }

  Future<List<BookModel>> getRecentlyAdded({int limit = 10}) async {
    final box = await _boxAsync;
    final books = box.values.toList();
    books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return books.take(limit).toList();
  }

  Future<List<BookModel>> getBooksByCollection(String collectionId) async {
    final box = await _boxAsync;
    return box.values.where((b) => b.collectionIds.contains(collectionId)).toList();
  }

  Future<List<BookModel>> searchBooks(String query) async {
    final box = await _boxAsync;
    final lowerQuery = query.toLowerCase();
    return box.values.where((b) {
      return b.title.toLowerCase().contains(lowerQuery) ||
          b.author.toLowerCase().contains(lowerQuery) ||
          b.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  Future<int> getTotalBooks() async {
    final box = await _boxAsync;
    return box.length;
  }

  Future<int> getTotalPagesRead() async {
    final box = await _boxAsync;
    return box.values.fold<int>(0, (sum, b) => sum + b.currentPage);
  }

  Future<List<BookModel>> getBooksByOnlineId(String onlineBookId) async {
    final box = await _boxAsync;
    return box.values.where((b) => b.onlineBookId == onlineBookId).toList();
  }

  Future<bool> hasOnlineBook(String onlineBookId) async {
    final box = await _boxAsync;
    return box.values.any((b) => b.onlineBookId == onlineBookId);
  }
}
