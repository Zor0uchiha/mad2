import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../models/online_book_model.dart';
import '../services/storage_service.dart';
import 'google_books_service.dart';
import 'open_library_service.dart';
import 'gutendex_service.dart';

const _cacheDuration = Duration(hours: 6);

class UnifiedBookRepository {
  final GoogleBooksService googleBooks;
  final OpenLibraryService openLibrary;
  final GutendexService gutendex;

  UnifiedBookRepository()
      : googleBooks = GoogleBooksService(),
        openLibrary = OpenLibraryService(),
        gutendex = GutendexService();

  Future<List<OnlineBookModel>> searchAll(String query,
      {int limit = 20}) async {
    final cacheKey = 'search_${query.toLowerCase().trim()}';
    final cached = await _getCached(cacheKey);
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await Future.wait([
        googleBooks.searchBooks(query, maxResults: 20),
        openLibrary.searchBooks(query, limit: 10),
        gutendex.searchBooks(query),
      ]);
      final merged = _merge(results.expand((l) => l).toList());
      await _setCached(cacheKey, merged);
      return merged.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<OnlineBookModel?> getBookDetail(String id, String source) async {
    final cacheKey = 'detail_${source}_$id';
    final cached = await _getCachedSingle(cacheKey);
    if (cached != null) return cached;

    try {
      OnlineBookModel? book;
      switch (source) {
        case 'google_books':
          book = await googleBooks.getBookById(id);
          break;
        case 'open_library':
          book = await openLibrary.getBookById(id);
          break;
        case 'gutendex':
          final numId = int.tryParse(id.replaceAll('gutendex_', ''));
          if (numId != null) book = await gutendex.getBookById(numId);
          break;
      }
      if (book != null) await _setCachedSingle(cacheKey, book);
      return book;
    } catch (_) {
      return cached;
    }
  }

  Future<List<OnlineBookModel>> getTrending({int limit = 20}) async {
    final cached = await _getCached('trending');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await Future.wait([
        googleBooks.searchBooks('trending', maxResults: 20, orderBy: 'relevance'),
        openLibrary.getTrending(limit: 10),
        gutendex.searchBooks('', page: 1),
      ]);
      final merged = _merge(results.expand((l) => l).toList());
      await _setCached('trending', merged);
      return merged.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getPopular({int limit = 20}) async {
    final cached = await _getCached('popular');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await Future.wait([
        googleBooks.searchBooks('popular', maxResults: 20, orderBy: 'relevance'),
        openLibrary.getPopular(limit: 10),
        gutendex.searchBooks('', page: 1),
      ]);
      final merged = _merge(results.expand((l) => l).toList());
      merged.sort(
          (a, b) => (b.downloadCount ?? 0).compareTo(a.downloadCount ?? 0));
      await _setCached('popular', merged);
      return merged.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getNewReleases({int limit = 20}) async {
    final cached = await _getCached('new_releases');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await googleBooks.getNewReleases(maxResults: 40);
      await _setCached('new_releases', results);
      return results.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getPublicDomain({int limit = 20}) async {
    final cached = await _getCached('public_domain');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await gutendex.getPublicDomainBooks(count: 40);
      await _setCached('public_domain', results);
      return results.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getByCategory(String category,
      {int limit = 20}) async {
    final cacheKey = 'category_${category.toLowerCase()}';
    final cached = await _getCached(cacheKey);
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await Future.wait([
        googleBooks.searchByCategory(category, maxResults: 20),
        openLibrary.searchByCategory(category, limit: 10),
        gutendex.getByTopic(category),
      ]);
      final merged = _merge(results.expand((l) => l).toList());
      await _setCached(cacheKey, merged);
      return merged.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getAwardWinners({int limit = 20}) async {
    final cached = await _getCached('award_winners');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await googleBooks.getAwardWinners(maxResults: 40);
      await _setCached('award_winners', results);
      return results.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  Future<List<OnlineBookModel>> getEditorsPicks({int limit = 20}) async {
    final cached = await _getCached('editors_picks');
    if (cached != null) return cached.take(limit).toList();

    try {
      final results = await googleBooks.getEditorsPicks(maxResults: 40);
      await _setCached('editors_picks', results);
      return results.take(limit).toList();
    } catch (_) {
      return cached?.take(limit).toList() ?? [];
    }
  }

  List<OnlineBookModel> _merge(List<OnlineBookModel> books) {
    final seen = <String>{};
    final merged = <OnlineBookModel>[];
    for (final book in books) {
      final key = book.title.toLowerCase().trim();
      if (seen.add(key)) {
        merged.add(book);
      }
    }
    return merged;
  }

  Future<List<OnlineBookModel>?> _getCached(String key) async {
    try {
      final box = await StorageService.openBrowseCacheBox();
      final entry = box.get(key) as String?;
      if (entry == null) return null;
      final data = jsonDecode(entry) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      if (DateTime.now().difference(timestamp) > _cacheDuration) {
        return null;
      }
      final list = data['data'] as List<dynamic>;
      return list
          .map((e) =>
              OnlineBookModel.fromStorageJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _setCached(String key, List<OnlineBookModel> books) async {
    try {
      final box = await StorageService.openBrowseCacheBox();
      final data = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': books.map((b) => b.toStorageJson()).toList(),
      });
      await box.put(key, data);
    } catch (_) {}
  }

  Future<OnlineBookModel?> _getCachedSingle(String key) async {
    try {
      final box = await StorageService.openOnlineCacheBox();
      final entry = box.get(key) as String?;
      if (entry == null) return null;
      final data = jsonDecode(entry) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      if (DateTime.now().difference(timestamp) > _cacheDuration) {
        return null;
      }
      return OnlineBookModel.fromStorageJson(
          data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setCachedSingle(String key, OnlineBookModel book) async {
    try {
      final box = await StorageService.openOnlineCacheBox();
      final data = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': book.toStorageJson(),
      });
      await box.put(key, data);
    } catch (_) {}
  }
}
