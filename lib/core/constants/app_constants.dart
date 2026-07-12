class AppConstants {
  static const String appName = "Bookstr";
  static const String appVersion = "1.0.0";
  static const String googleBooksApiBaseUrl = "https://www.googleapis.com/books/v1/volumes";

  static const int splashDelayMs = 2000;
  static const int onboardingPageCount = 5;
  static const int libraryPageSize = 50;
  static const int searchDebounceMs = 300;

  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double defaultCardRadius = 16.0;
  static const double defaultElevation = 0.0;

  static const String hiveBoxBooks = "books";
  static const String hiveBoxCollections = "collections";
  static const String hiveBoxSettings = "settings";
  static const String hiveBoxBookmarks = "bookmarks";
  static const String hiveBoxNotes = "notes";
  static const String hiveBoxReadingLists = "reading_lists";
  static const String hiveBoxReviews = "reviews";
  static const String hiveBoxUserProfile = "user_profile";
  static const String hiveBoxReadingProgress = "reading_progress";
  static const String hiveBoxSyncQueue = "sync_queue";

  static const String routeSplash = "/splash";
  static const String routeOnboarding = "/onboarding";
  static const String routeAuth = "/auth";
  static const String routeHome = "/home";
  static const String routeLibrary = "/library";
  static const String routeReader = "/reader";
  static const String routeCollections = "/collections";
  static const String routeBrowse = "/browse";
  static const String routeBookDetail = "/book-detail";
  static const String routeProfile = "/profile";
  static const String routeSearch = "/search";
  static const String routeStatistics = "/statistics";
  static const String routeSettings = "/settings";
  static const String routeShare = "/share";
}
