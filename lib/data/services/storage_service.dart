import 'package:hive_flutter/hive_flutter.dart';
import '../../core/hive/adapters.dart' as adapters;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../models/collection_model.dart';
import '../models/note_model.dart';
import '../models/reading_goal_model.dart';
import '../models/reading_list_model.dart';
import '../models/reading_progress_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';

class StorageService {
  static Future<void> initialize() async {
    await Hive.initFlutter();
  }

  static Future<void> registerAdapters() async {
    Hive.registerAdapter(adapters.BookModelAdapter());
    Hive.registerAdapter(adapters.BookmarkModelAdapter());
    Hive.registerAdapter(adapters.CollectionModelAdapter());
    Hive.registerAdapter(adapters.NoteModelAdapter());
    Hive.registerAdapter(adapters.ReadingGoalModelAdapter());
    Hive.registerAdapter(adapters.ReadingListModelAdapter());
    Hive.registerAdapter(adapters.ReadingProgressModelAdapter());
    Hive.registerAdapter(adapters.ReviewModelAdapter());
    Hive.registerAdapter(adapters.UserModelAdapter());
  }

  static Future<Box<dynamic>> openBox(String name) async {
    return await Hive.openBox(name);
  }

  static Future<Box<BookModel>> openBooksBox() async {
    return await Hive.openBox<BookModel>(AppConstants.hiveBoxBooks);
  }

  static Future<Box<CollectionModel>> openCollectionsBox() async {
    return await Hive.openBox<CollectionModel>(AppConstants.hiveBoxCollections);
  }

  static Future<Box<BookmarkModel>> openBookmarksBox() async {
    return await Hive.openBox<BookmarkModel>(AppConstants.hiveBoxBookmarks);
  }

  static Future<Box<NoteModel>> openNotesBox() async {
    return await Hive.openBox<NoteModel>(AppConstants.hiveBoxNotes);
  }

  static Future<Box<ReadingProgressModel>> openReadingProgressBox() async {
    return await Hive.openBox<ReadingProgressModel>(AppConstants.hiveBoxReadingProgress);
  }

  static Future<Box<ReadingListModel>> openReadingListsBox() async {
    return await Hive.openBox<ReadingListModel>(AppConstants.hiveBoxReadingLists);
  }

  static Future<Box<ReviewModel>> openReviewsBox() async {
    return await Hive.openBox<ReviewModel>(AppConstants.hiveBoxReviews);
  }

  static Future<Box<UserModel>> openUserProfileBox() async {
    return await Hive.openBox<UserModel>(AppConstants.hiveBoxUserProfile);
  }

  static Future<Box<ReadingGoalModel>> openReadingGoalsBox() async {
    return await Hive.openBox<ReadingGoalModel>(AppConstants.hiveBoxReadingGoals);
  }

  static Future<Box<dynamic>> openSettingsBox() async {
    return await Hive.openBox(AppConstants.hiveBoxSettings);
  }

  static Future<Box<dynamic>> openOnlineCacheBox() async {
    return await Hive.openBox(AppConstants.hiveBoxOnlineCache);
  }

  static Future<Box<dynamic>> openBrowseCacheBox() async {
    return await Hive.openBox(AppConstants.hiveBoxBrowseCache);
  }

  static Future<void> clearAll() async {
    const boxNames = [
      AppConstants.hiveBoxBooks,
      AppConstants.hiveBoxBookmarks,
      AppConstants.hiveBoxCollections,
      AppConstants.hiveBoxNotes,
      AppConstants.hiveBoxReadingGoals,
      AppConstants.hiveBoxReadingLists,
      AppConstants.hiveBoxReadingProgress,
      AppConstants.hiveBoxReviews,
      AppConstants.hiveBoxUserProfile,
      AppConstants.hiveBoxSettings,
      AppConstants.hiveBoxSyncQueue,
      AppConstants.hiveBoxOnlineCache,
      AppConstants.hiveBoxBrowseCache,
    ];
    for (final name in boxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    }
  }

  static Future<void> deleteBox(String name) async {
    await Hive.deleteBoxFromDisk(name);
  }
}
