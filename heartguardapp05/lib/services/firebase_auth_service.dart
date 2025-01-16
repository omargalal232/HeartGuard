import 'package:firebase_auth/firebase_auth.dart';

/// Service class for handling Firebase Authentication operations
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the currently signed-in user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in a user with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
<<<<<<< Updated upstream:heartguardapp05/lib/services/firebase_auth_service.dart
      print('Error signing in: $e');
=======
>>>>>>> Stashed changes:heartguardapp5/heartguardapp05/lib/services/firebase_auth_service.dart
      rethrow;
    }
  }

  /// Creates a new user account with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
<<<<<<< Updated upstream:heartguardapp05/lib/services/firebase_auth_service.dart
      print('Error signing up: $e');
=======
>>>>>>> Stashed changes:heartguardapp5/heartguardapp05/lib/services/firebase_auth_service.dart
      rethrow;
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
<<<<<<< Updated upstream:heartguardapp05/lib/services/firebase_auth_service.dart
    await _auth.signOut();
=======
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
>>>>>>> Stashed changes:heartguardapp5/heartguardapp05/lib/services/firebase_auth_service.dart
  }
}
