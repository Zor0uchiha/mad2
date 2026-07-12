import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/collection_repository.dart';
import '../data/models/collection_model.dart';
import '../data/models/book_model.dart';
import 'book_provider.dart';

final _collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository();
});

final collectionsProvider = Provider<CollectionRepository>((ref) {
  return ref.watch(_collectionRepositoryProvider);
});

final allCollectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final repo = ref.watch(collectionsProvider);
  return repo.getAllCollections();
});

final collectionProvider = FutureProvider.family<CollectionModel?, String>((ref, id) async {
  final repo = ref.watch(collectionsProvider);
  return repo.getCollection(id);
});

final booksInCollectionProvider = FutureProvider.family<List<BookModel>, String>((ref, collectionId) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  return bookRepo.getBooksByCollection(collectionId);
});
