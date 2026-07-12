import "package:hive_flutter/hive_flutter.dart";
import "../models/book_model.dart";
import "../models/collection_model.dart";
import "../models/reading_progress_model.dart";
import "../../core/errors/app_exception.dart";

class BookRepository {
  static const String boxName = AppConstants.hiveBoxBooks;
  final Box<BookModel> _box;

  BookRepository(this._box);

  Future<void> addBook(BookModel book) async {
    try {
      await _box.put(book.id, book);
    } catch (e) {
      throw StorageException("Failed to add book", originalError: e);
    }
  }

  Future<void> updateBook(BookModel book) async {
    try {
      book.updatedAt = DateTime.now();
      await book.save();
    } catch (e) {
      throw StorageException("Failed to update book", originalError: e);
    }
  }

  Future<void> deleteBook(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException("Failed to delete book", originalError: e);
    }
  }

  BookModel? getBook(String id) => _box.get(id);

  List<BookModel> getAllBooks() => _box.values.toList();

  List<BookModel> getFavoriteBooks() =>
      _box.values.where((b) => b.isFavorite).toList();

  List<BookModel> getRecentBooks({int limit = 20}) {
    final books = _box.values.toList();
    books.sort((a, b) => b.lastOpenedAt?.compareTo(a.lastOpenedAt ?? DateTime.now()) ?? -1);
    return books.take(limit).toList();
  }

  List<BookModel> getBooksByCollection(String collectionId) =>
      _box.values.where((b) => b.collectionIds.contains(collectionId)).toList();

  List<BookModel> searchBooks(String query) {
    final lowerQuery = query.toLowerCase();
    return _box.values
        .where((b) =>
            b.title.toLowerCase().contains(lowerQuery) ||
            b.author.toLowerCase().contains(lowerQuery) ||
            b.tags.any((t) => t.toLowerCase().contains(lowerQuery)))
        .toList();
  }
}

class CollectionRepository {
  static const String boxName = AppConstants.hiveBoxCollections;
  final Box<CollectionModel> _box;

  CollectionRepository(this._box);

  Future<void> addCollection(CollectionModel collection) async {
    try {
      await _box.put(collection.id, collection);
    } catch (e) {
      throw StorageException("Failed to add collection", originalError: e);
    }
  }

  Future<void> updateCollection(CollectionModel collection) async {
    try {
      collection.updatedAt = DateTime.now();
      await collection.save();
    } catch (e) {
      throw StorageException("Failed to update collection", originalError: e);
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException("Failed to delete collection", originalError: e);
    }
  }

  CollectionModel? getCollection(String id) => _box.get(id);

  List<CollectionModel> getAllCollections() {
    final collections = _box.values.toList();
    collections.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return collections;
  }
}
