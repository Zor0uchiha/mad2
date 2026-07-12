import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class UserRepository {
  Box<UserModel>? _box;

  Future<Box<UserModel>> get _boxAsync async {
    _box ??= await Hive.openBox<UserModel>(AppConstants.hiveBoxUserProfile);
    return _box!;
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
}
