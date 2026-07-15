import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/online_book_model.dart';
import '../data/services/unified_book_repository.dart';

final unifiedBookRepositoryProvider = Provider<UnifiedBookRepository>((ref) {
  return UnifiedBookRepository();
});

final trendingBooksProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getTrending();
});

final popularBooksProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getPopular();
});

final newReleasesProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getNewReleases();
});

final publicDomainProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getPublicDomain();
});

final awardWinnersProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getAwardWinners();
});

final editorsPicksProvider = FutureProvider<List<OnlineBookModel>>((ref) async {
  return ref.read(unifiedBookRepositoryProvider).getEditorsPicks();
});

final categoryBooksProvider = FutureProvider.family<List<OnlineBookModel>, String>((ref, category) async {
  return ref.read(unifiedBookRepositoryProvider).getByCategory(category);
});

final searchResultsProvider = FutureProvider.family<List<OnlineBookModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.read(unifiedBookRepositoryProvider).searchAll(query);
});

final bookDetailProvider = FutureProvider.family<OnlineBookModel?, String>((ref, combined) async {
  final parts = combined.split('|');
  if (parts.length != 2) return null;
  return ref.read(unifiedBookRepositoryProvider).getBookDetail(parts[0], parts[1]);
});
