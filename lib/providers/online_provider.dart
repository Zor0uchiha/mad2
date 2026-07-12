import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../data/services/online_book_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConstants.googleBooksApiBaseUrl);
});

final onlineBookServiceProvider = Provider<OnlineBookService>((ref) {
  return OnlineBookService(ref.watch(apiClientProvider));
});
