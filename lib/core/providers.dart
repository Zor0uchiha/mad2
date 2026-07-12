import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../network/api_client.dart";
import "../constants/app_constants.dart";
import "../models/book_model.dart";
import "../models/collection_model.dart";
import "../models/review_model.dart";
import "../models/reading_list_model.dart";
import "../services/auth_service.dart";
import "../services/online_book_service.dart";
import "../services/settings_service.dart";
import "../services/notification_service.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs.requireValue);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService()..initialize();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConstants.googleBooksApiBaseUrl);
});

final onlineBookServiceProvider = Provider<OnlineBookService>((ref) {
  return OnlineBookService(ref.watch(apiClientProvider));
});

final booksProvider = Provider<BookRepository>((ref) {
  return BookRepository(Hive.box<BookModel>(AppConstants.hiveBoxBooks));
});

final collectionsProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(Hive.box<CollectionModel>(AppConstants.hiveBoxCollections));
});

final bookmarksProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(Hive.box<BookmarkModel>(AppConstants.hiveBoxBookmarks));
});

final notesProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(Hive.box<NoteModel>(AppConstants.hiveBoxNotes));
});

final readingProgressProvider = Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository(Hive.box<ReadingProgressModel>(AppConstants.hiveBoxReadingProgress));
});

final reviewsProvider = Provider<dynamic>((ref) {
  return Hive.box<ReviewModel>(AppConstants.hiveBoxReviews);
});

final readingListsProvider = Provider<dynamic>((ref) {
  return Hive.box<ReadingListModel>(AppConstants.hiveBoxReadingLists);
});
