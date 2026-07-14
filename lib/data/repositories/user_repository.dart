import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/reading_progress_model.dart';

class UserRepository {
  Box<UserModel>? _box;
  Box<ReadingProgressModel>? _progressBox;

  Future<Box<UserModel>> get _boxAsync async {
    _box ??= await Hive.openBox<UserModel>(AppConstants.hiveBoxUserProfile);
    return _box!;
  }

  Future<Box<ReadingProgressModel>> get _progressBoxAsync async {
    _progressBox ??= await Hive.openBox<ReadingProgressModel>(AppConstants.hiveBoxReadingProgress);
    return _progressBox!;
  }

  Future<void> saveUser(UserModel user) async {
    final box = await _boxAsync;
    await box.put('current_user', user);
  }

  Future<UserModel?> getCurrentUser() async {
    final box = await _boxAsync;
    return box.get('current_user');
  }

  Future<void> deleteUser() async {
    final box = await _boxAsync;
    await box.delete('current_user');
  }

  Future<void> updateProfile({String? displayName, String? photoUrl, String? bio, bool? isPublicProfile}) async {
    final box = await _boxAsync;
    final user = box.get('current_user');
    if (user != null) {
      final updated = user.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
        bio: bio,
        isPublicProfile: isPublicProfile,
        updatedAt: DateTime.now(),
      );
      await box.put('current_user', updated);
    }
  }

  Future<int> updateReadingStreak() async {
    final box = await _boxAsync;
    final user = box.get('current_user');
    if (user == null) return 0;

    final progressBox = await _progressBoxAsync;
    final dates = <DateTime>{};
    for (final p in progressBox.values) {
      final d = p.lastReadAt;
      dates.add(DateTime(d.year, d.month, d.day));
    }

    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
    if (sorted.isEmpty) {
      final updated = user.copyWith(readingStreak: 0, updatedAt: DateTime.now());
      await box.put('current_user', updated);
      return 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (sorted.first != today && sorted.first != yesterday) {
      final updated = user.copyWith(readingStreak: 0, updatedAt: DateTime.now());
      await box.put('current_user', updated);
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      final diff = sorted[i].difference(sorted[i + 1]).inDays;
      if (diff <= 1) {
        streak++;
      } else {
        break;
      }
    }

    final updated = user.copyWith(readingStreak: streak, updatedAt: DateTime.now());
    await box.put('current_user', updated);
    return streak;
  }
}
