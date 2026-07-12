import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/book_repository.dart';
import '../data/models/book_model.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final booksProvider = Provider<BookRepository>((ref) {
  return ref.watch(bookRepositoryProvider);
});

final allBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getAllBooks();
});

final favoriteBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getFavoriteBooks();
});

final recentBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getRecentBooks();
});

final continueReadingProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getContinueReading();
});

final totalBooksProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getTotalBooks();
});

final totalPagesReadProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getTotalPagesRead();
});

final recentlyAddedBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final repo = ref.watch(booksProvider);
  return repo.getRecentlyAdded();
});
