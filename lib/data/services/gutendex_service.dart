import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/online_book_model.dart';

class GutendexService {
  final http.Client _client;

  GutendexService() : _client = http.Client();

  Future<List<OnlineBookModel>> searchBooks(String query,
      {int page = 1}) async {
    try {
      final uri = Uri.parse(AppConstants.gutendexApiUrl).replace(
        queryParameters: {
          'search': query,
          'page': page.toString(),
        },
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((r) =>
              OnlineBookModel.fromGutendex(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<OnlineBookModel>> getPublicDomainBooks(
      {int page = 1, int count = 40}) async {
    try {
      final uri = Uri.parse(AppConstants.gutendexApiUrl).replace(
        queryParameters: {
          'page': page.toString(),
        },
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((r) =>
              OnlineBookModel.fromGutendex(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<OnlineBookModel>> getByTopic(String topic,
      {int page = 1}) async {
    try {
      final uri = Uri.parse(AppConstants.gutendexApiUrl).replace(
        queryParameters: {
          'topic': topic,
          'page': page.toString(),
        },
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((r) =>
              OnlineBookModel.fromGutendex(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<OnlineBookModel?> getBookById(int id) async {
    try {
      final uri = Uri.parse('${AppConstants.gutendexApiUrl}/$id');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OnlineBookModel.fromGutendex(data);
    } catch (_) {
      return null;
    }
  }
}
