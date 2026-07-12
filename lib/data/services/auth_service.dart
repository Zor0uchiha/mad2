import "package:firebase_auth/firebase_auth.dart";
import "../../core/errors/app_exception.dart";
import "../models/user_model.dart";

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> get currentUser async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserModel(
      uid: user.uid,
      email: user.email ?? "",
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      isAnonymous: user.isAnonymous,
      isPublicProfile: true,
      updatedAt: DateTime.now(),
    );
  }

  Future<UserModel> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      final user = result.user;
      return UserModel(
        uid: user!.uid,
        email: user.email ?? "",
        isAnonymous: true,
        isPublicProfile: false,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? "Anonymous sign-in failed", code: e.code);
    }
  }

  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = result.user;
      return UserModel(
        uid: user!.uid,
        email: user.email ?? "",
        displayName: user.displayName,
        photoUrl: user.photoURL,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? "Sign in failed", code: e.code);
    }
  }

  Future<UserModel> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = result.user;
      return UserModel(
        uid: user!.uid,
        email: user.email ?? "",
        displayName: user.displayName,
        photoUrl: user.photoURL,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? "Sign up failed", code: e.code);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
