import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/online_book_model.dart';

class OpenLibraryService {
  final http.Client _client;

  OpenLibraryService() : _client = http.Client();

  Future<List<OnlineBookModel>> searchBooks(String query,
      {int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse(
          '${AppConstants.openLibraryApiUrl}/search.json').replace(
        queryParameters: {
          'q': query,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = data['docs'] as List<dynamic>? ?? [];
      return docs
          .map((doc) =>
              OnlineBookModel.fromOpenLibrary(doc as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<OnlineBookModel>> searchByCategory(String category,
      {int limit = 20}) async {
    return searchBooks('subject:$category', limit: limit);
  }

  Future<List<OnlineBookModel>> getTrending({int limit = 20}) async {
    return searchBooks('', limit: limit);
  }

  Future<List<OnlineBookModel>> getPopular({int limit = 20}) async {
    final results = await searchBooks('', limit: 50);
    results.sort((a, b) => (b.downloadCount ?? 0).compareTo(a.downloadCount ?? 0));
    return results.take(limit).toList();
  }
}
