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

  Future<OnlineBookModel?> getBookById(String id) async {
    try {
      final cleanId = id.replaceAll('/works/', '').replaceAll('/books/', '').replaceAll('/workd/', '');
      final uri = Uri.parse('${AppConstants.openLibraryApiUrl}/works/$cleanId.json');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return OnlineBookModel(
        id: id,
        source: 'open_library',
        title: data['title'] as String? ?? 'Unknown Title',
        authors: (data['authors'] as List<dynamic>?)
                ?.map((a) => (a as Map<String, dynamic>)['author']?['key'] as String? ?? 'Unknown')
                .toList() ??
            [],
        description: _extractDescription(data),
        thumbnail: 'https://covers.openlibrary.org/b/olid/$cleanId-M.jpg',
        pageCount: data['number_of_pages'] as int?,
        publishedDate: data['first_publish_date'] as String?,
        categories: (data['subjects'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        language: data['language'] as String?,
        isPublicDomain: true,
        isFree: true,
        borrowLink: 'https://openlibrary.org/works/$cleanId/borrow',
        readOnlineLink: 'https://openlibrary.org/works/$cleanId',
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractDescription(Map<String, dynamic> data) {
    final desc = data['description'];
    if (desc is String) return desc;
    if (desc is Map<String, dynamic>) return desc['value'] as String?;
    return null;
  }
}
