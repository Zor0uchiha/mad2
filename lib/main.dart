import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../data/services/settings_service.dart";
import "../data/services/auth_service.dart";
import "../data/services/online_book_service.dart";
import "../data/models/book_model.dart";
import "../data/models/collection_model.dart";
import "../data/models/user_model.dart";
import "../data/models/review_model.dart";
import "../data/models/reading_list_model.dart";
import "../data/models/bookmark_model.dart";
import "../data/models/note_model.dart";
import "../data/models/reading_progress_model.dart";
import "../data/models/reading_goal_model.dart";
import "../../core/theme/app_theme.dart";
import "../../core/constants/app_constants.dart";
import "package:firebase_core/firebase_core.dart";
import "package:hive_flutter/hive_flutter.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Hive.initFlutter();
  Hive.registerAdapter(BookModelAdapter());
  Hive.registerAdapter(CollectionModelAdapter());
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(ReviewModelAdapter());
  Hive.registerAdapter(ReadingListModelAdapter());
  Hive.registerAdapter(BookmarkModelAdapter());
  Hive.registerAdapter(NoteModelAdapter());
  Hive.registerAdapter(ReadingProgressModelAdapter());
  Hive.registerAdapter(ReadingGoalModelAdapter());

  await Hive.openBox<BookModel>(AppConstants.hiveBoxBooks);
  await Hive.openBox<CollectionModel>(AppConstants.hiveBoxCollections);
  await Hive.openBox<BookmarkModel>(AppConstants.hiveBoxBookmarks);
  await Hive.openBox<NoteModel>(AppConstants.hiveBoxNotes);
  await Hive.openBox<ReadingProgressModel>(AppConstants.hiveBoxReadingProgress);
  await Hive.openBox(AppConstants.hiveBoxSettings);
  await Hive.openBox<ReadingListModel>(AppConstants.hiveBoxReadingLists);
  await Hive.openBox<ReviewModel>(AppConstants.hiveBoxReviews);
  await Hive.openBox<UserModel>(AppConstants.hiveBoxUserProfile);

  runApp(const ProviderScope(child: AppWidget()));
}
