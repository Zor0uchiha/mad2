import '../../core/network/api_client.dart';
import '../../core/errors/app_exception.dart';
import '../models/online_book_model.dart';

class OnlineBookService {
  final ApiClient _client;

  OnlineBookService(this._client);

  Future<List<OnlineBookModel>> searchBooks(String query) async {
    try {
      final data = await _client.get('/volumes', queryParameters: {
        'q': query,
        'maxResults': '20',
      });
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => OnlineBookModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on NetworkException {
      return [];
    }
  }

  Future<OnlineBookModel?> getBookById(String id) async {
    try {
      final data = await _client.get('/volumes/$id');
      return OnlineBookModel.fromJson(data);
    } on NetworkException {
      return null;
    }
  }
}
