import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/auth_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final localUserProvider = FutureProvider<UserModel?>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  var user = await repo.getCurrentUser();
  if (user == null) {
    user = UserModel(
      uid: 'local_user',
      email: '',
      displayName: 'Reader',
      createdAt: DateTime.now(),
      isPublicProfile: false,
      updatedAt: DateTime.now(),
    );
    await repo.saveUser(user);
  }
  return user;
});
