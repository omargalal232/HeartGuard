import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_model.dart';

/// Controller responsible for handling authentication-related operations
class AuthController {
  final FirebaseAuthService _authService = FirebaseAuthService();

  /// Signs in a user with email and password
  /// 
  /// Returns a [UserModel] if successful, null otherwise
  /// Throws an exception if the sign-in fails
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final User? user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        return UserModel(
          id: user.uid,
          email: user.email!,
          name: user.displayName ?? 'No Name',
          isActive: true,
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred';
    }
  }

  /// Signs up a new user with email and password
  /// 
  /// Returns a [UserModel] if successful, null otherwise
  /// Throws an exception if the sign-up fails
  Future<UserModel?> signUp(String email, String password) async {
    try {
      final User? user = await _authService.signUpWithEmail(email, password);
      if (user != null) {
        return UserModel(
          id: user.uid,
          email: user.email!,
          name: user.displayName ?? 'No Name',
          isActive: true,
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred';
    }
  }

  /// Handles Firebase Authentication exceptions and returns user-friendly error messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'The password provided is too weak';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
} 