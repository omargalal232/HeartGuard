import 'package:firebase_auth/firebase_auth.dart';
import 'package:heartguardapp05/services/firebase_auth_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';
import '../models/user_model.dart';

/// Controller responsible for handling authentication-related operations
class AuthController {
  final FirebaseAuthService _authService;
  final LoggerService _logger;

  AuthController({
    required FirebaseAuthService authService,
    required LoggerService logger,
  })  : _authService = authService,
        _logger = logger;

  /// Signs in a user with email and password
  /// 
  /// Returns a [UserModel] if successful, null otherwise
  /// Throws an exception if the sign-in fails
  Future<UserModel?> signIn(String email, String password) async {
    try {
      _logger.i('Attempting to sign in user: $email');
      
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      final User? user = await _authService.signIn(
        email: email,
        password: password,
      );

      if (user == null) {
        _logger.w('Sign in returned null user');
        throw 'Authentication failed. Please try again.';
      }

      _logger.i('User signed in successfully: ${user.email}');
      return UserModel(
        uid: user.uid,
        email: user.email!,
        name: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during sign in: ${e.code}', e);
      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Unexpected error during sign in', e);
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Signs up a new user with email and password
  /// 
  /// Returns a [UserModel] if successful, null otherwise
  /// Throws an exception if the sign-up fails
  Future<UserModel?> signUp(String email, String password) async {
    try {
      _logger.i('Attempting to sign up user: $email');
      
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      final User? user = await _authService.signUpWithEmail(email, password);
      
      if (user == null) {
        _logger.w('Sign up returned null user');
        throw 'Account creation failed. Please try again.';
      }

      _logger.i('User signed up successfully: ${user.email}');
      return UserModel(
        uid: user.uid,
        email: user.email!,
        name: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during sign up: ${e.code}', e);
      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Unexpected error during sign up', e);
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sends a password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Attempting to send password reset email to: $email');
      
      if (email.isEmpty) {
        throw 'Please enter your email address';
      }

      await _authService.sendPasswordResetEmail(email);
      _logger.i('Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during password reset: ${e.code}', e);
      throw _handleAuthException(e);
    } catch (e) {
      _logger.e('Unexpected error during password reset', e);
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  /// Gets the last signed in email from secure storage
  Future<String?> getLastSignedInEmail() async {
    try {
      return await _authService.getLastSignedInEmail();
    } catch (e) {
      _logger.e('Error getting last signed in email', e);
      return null;
    }
  }

  /// Handles Firebase Authentication exceptions and returns user-friendly error messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password provided is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        _logger.e('Unhandled auth error code: ${e.code}', e);
        return 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _logger.i('User signed out successfully');
    } catch (e) {
      _logger.e('Error signing out', e);
      throw 'Failed to sign out. Please try again.';
    }
  }

  /// Returns the currently signed-in user
  User? getCurrentUser() {
    final user = _authService.getCurrentUser();
    if (user == null) {
      _logger.w('No user currently signed in');
    } else {
      _logger.i('Current user: ${user.email}');
    }
    return user;
  }

  /// Returns a stream of authentication state changes
  Stream<User?> get authStateChanges => _authService.authStateChanges;
} 