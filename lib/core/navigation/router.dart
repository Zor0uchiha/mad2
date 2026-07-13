import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/collections/collections_screen.dart';
import '../../features/collections/collection_detail_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/browse/book_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/bookmarks/notes_screen.dart';
import '../../features/profile/reading_list_screen.dart';
import '../../features/share/share_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppConstants.routeSplash,
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOnboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAuth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHome,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeLibrary,
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCollections,
      builder: (context, state) => const CollectionsScreen(),
    ),
    GoRoute(
      path: "${AppConstants.routeCollectionDetail}/:collectionId",
      builder: (context, state) {
        final collectionId = state.pathParameters['collectionId'] ?? '';
        return CollectionDetailScreen(collectionId: collectionId);
      },
    ),
    GoRoute(
      path: AppConstants.routeBrowse,
      builder: (context, state) => const BrowseScreen(),
    ),
    GoRoute(
      path: "${AppConstants.routeBookDetail}/:bookId",
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        return BookDetailScreen(bookId: bookId);
      },
    ),
    GoRoute(
      path: AppConstants.routeSearch,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: AppConstants.routeProfile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppConstants.routeStatistics,
      builder: (context, state) => const StatisticsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSettings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: "${AppConstants.routeReader}/:bookId",
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        return ReaderScreen(bookId: bookId);
      },
    ),
    GoRoute(
      path: AppConstants.routeBookmarks,
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: AppConstants.routeNotes,
      builder: (context, state) => const NotesScreen(),
    ),
    GoRoute(
      path: "${AppConstants.routeCreateNote}/:bookId/:pageIndex",
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        final pageIndex = int.tryParse(state.pathParameters['pageIndex'] ?? '0') ?? 0;
        return NotesScreen(initialBookId: bookId, initialPageIndex: pageIndex);
      },
    ),
    GoRoute(
      path: AppConstants.routeReadingLists,
      builder: (context, state) => const ReadingListScreen(),
    ),
    GoRoute(
      path: AppConstants.routeShare,
      builder: (context, state) => const ShareScreen(),
    ),
  ],
);
