import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/app_exception.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel?> get currentUser async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _mapFirebaseUser(user);
  }

  Future<UserModel> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return _mapFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Anonymous sign-in failed', code: e.code);
    }
  }

  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _mapFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign in failed', code: e.code);
    }
  }

  Future<UserModel> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return _mapFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign up failed', code: e.code);
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return _mapFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed', code: e.code);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  UserModel _mapFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      isAnonymous: user.isAnonymous,
      isPublicProfile: true,
      updatedAt: DateTime.now(),
    );
  }
}
