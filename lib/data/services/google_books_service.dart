import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/online_book_model.dart';

class GoogleBooksService {
  final ApiClient _client;

  GoogleBooksService()
      : _client = ApiClient(baseUrl: AppConstants.googleBooksApiBaseUrl);

  Future<List<OnlineBookModel>> searchBooks(String query,
      {int maxResults = 40, int startIndex = 0, String? orderBy}) async {
    try {
      final params = <String, String>{
        'q': query,
        'maxResults': maxResults.toString(),
        'startIndex': startIndex.toString(),
      };
      if (orderBy != null) params['orderBy'] = orderBy;
      final data = await _client.get('/volumes', queryParameters: params);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) =>
              OnlineBookModel.fromGoogleBooks(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<OnlineBookModel?> getBookById(String id) async {
    try {
      final data = await _client.get('/$id');
      return OnlineBookModel.fromGoogleBooks(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<OnlineBookModel>> searchByCategory(String category,
      {int maxResults = 40}) async {
    return searchBooks('subject:$category',
        maxResults: maxResults, orderBy: 'relevance');
  }

  Future<List<OnlineBookModel>> getNewReleases({int maxResults = 40}) async {
    final year = DateTime.now().year;
    return searchBooks(
        'publishedDate:$year OR publishedDate:${year - 1}',
        maxResults: maxResults,
        orderBy: 'newest');
  }

  Future<List<OnlineBookModel>> getAwardWinners({int maxResults = 40}) async {
    return searchBooks(
        '(awards:winner OR award:Pulitzer OR award:Booker OR award:Nobel)',
        maxResults: maxResults,
        orderBy: 'relevance');
  }

  Future<List<OnlineBookModel>> getEditorsPicks({int maxResults = 40}) async {
    return searchBooks('"editor${"'"}s pick" OR "best books" OR "must read"',
        maxResults: maxResults, orderBy: 'relevance');
  }

  Future<List<OnlineBookModel>> getByRating({int minRating = 4, int maxResults = 40}) async {
    return searchBooks('',
        maxResults: maxResults);
  }
}
