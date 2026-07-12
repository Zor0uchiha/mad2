import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/collection_model.dart';

class CollectionRepository {
  Box<CollectionModel>? _box;

  Future<Box<CollectionModel>> get _boxAsync async {
    _box ??= await Hive.openBox<CollectionModel>(AppConstants.hiveBoxCollections);
    return _box!;
  }

  Future<void> addCollection(CollectionModel collection) async {
    final box = await _boxAsync;
    await box.put(collection.id, collection);
  }

  Future<void> updateCollection(CollectionModel collection) async {
    final box = await _boxAsync;
    collection.updatedAt = DateTime.now();
    await box.put(collection.id, collection);
  }

  Future<void> deleteCollection(String id) async {
    final box = await _boxAsync;
    await box.delete(id);
  }

  Future<CollectionModel?> getCollection(String id) async {
    final box = await _boxAsync;
    return box.get(id);
  }

  Future<List<CollectionModel>> getAllCollections() async {
    final box = await _boxAsync;
    final collections = box.values.toList();
    collections.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return collections;
  }

  Future<void> addBookToCollection(String collectionId, String bookId) async {
    final box = await _boxAsync;
    final collection = box.get(collectionId);
    if (collection != null && !collection.bookIds.contains(bookId)) {
      collection.bookIds = [...collection.bookIds, bookId];
      collection.updatedAt = DateTime.now();
      await box.put(collectionId, collection);
    }
  }

  Future<void> removeBookFromCollection(String collectionId, String bookId) async {
    final box = await _boxAsync;
    final collection = box.get(collectionId);
    if (collection != null) {
      collection.bookIds = collection.bookIds.where((id) => id != bookId).toList();
      collection.updatedAt = DateTime.now();
      await box.put(collectionId, collection);
    }
  }
}
