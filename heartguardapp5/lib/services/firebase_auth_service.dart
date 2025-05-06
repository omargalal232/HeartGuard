import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service class for handling Firebase Authentication operations
class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  FirebaseAuthService({required FirebaseAuth auth}) : _auth = auth;

  /// Returns the currently signed-in user
  User? getCurrentUser() => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in a user with email and password
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Store the email securely for future use
        await _secureStorage.write(
          key: 'last_signed_in_email',
          value: email,
        );
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign in');
    }
  }

  /// Creates a new user account with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Store the email securely for future use
        await _secureStorage.write(
          key: 'last_signed_in_email',
          value: email,
        );
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign up');
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Clear secure storage
      await _secureStorage.delete(key: 'last_signed_in_email');
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  /// Sends a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  /// Updates the user's password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Verify password strength
      if (newPassword.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password must be at least 6 characters long',
        );
      }

      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Failed to update password');
    }
  }

  /// Gets the last signed in email from secure storage
  Future<String?> getLastSignedInEmail() async {
    try {
      return await _secureStorage.read(key: 'last_signed_in_email');
    } catch (e) {
      return null;
    }
  }

  /// Handles authentication errors and provides user-friendly messages
  FirebaseAuthException _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email';
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address';
        break;
      case 'weak-password':
        message = 'Password is too weak. Please use a stronger password';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection';
        break;
      case 'user-disabled':
        message = 'This account has been disabled';
        break;
      case 'invalid-verification-code':
        message = 'Invalid verification code';
        break;
      case 'invalid-verification-id':
        message = 'Invalid verification ID';
        break;
      case 'quota-exceeded':
        message = 'Quota exceeded. Please try again later';
        break;
      case 'provider-already-linked':
        message = 'This provider is already linked to your account';
        break;
      case 'credential-already-in-use':
        message = 'This credential is already in use by another account';
        break;
      default:
        message = e.message ?? 'An error occurred during authentication';
    }

    return FirebaseAuthException(
      code: e.code,
      message: message,
      email: e.email,
      phoneNumber: e.phoneNumber,
    );
  }
}
