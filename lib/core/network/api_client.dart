import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bookstr/core/errors/app_exception.dart';
import 'package:bookstr/core/utils/logger.dart';

class ApiClient {
  final String baseUrl;
  final http.Client httpClient;

  ApiClient({required this.baseUrl, http.Client? client})
      : httpClient = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw NetworkException('Resource not found', code: 'NOT_FOUND');
      } else {
        throw NetworkException(
          'Request failed with status ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
    } on FormatException catch (e) {
      throw NetworkException('Invalid response format', originalError: e);
    } on http.ClientException catch (e) {
      throw NetworkException('Network error', originalError: e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Unexpected error', originalError: e);
    }
  }
}
