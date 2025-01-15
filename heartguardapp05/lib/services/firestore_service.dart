import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile_model.dart';

/// Service class for handling Firestore operations related to user profiles.
/// 
/// Provides methods for:
/// - Creating new profiles
/// - Updating existing profiles
/// - Retrieving profile information
/// - Deleting profiles
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'profiles';

  /// Creates a new user profile in Firestore
  /// 
  /// Throws [FirebaseException] if the operation fails
  Future<void> createProfile(ProfileModel profile) async {
    try {
      await _firestore
        .collection(_collection)
        .doc(profile.uid)
        .set(profile.toMap());
    } on FirebaseException catch (e) {
      throw _handleFirestoreError(e);
    }
  }

  /// Updates an existing user profile
  /// 
  /// Throws [FirebaseException] if the profile doesn't exist or the operation fails
  Future<void> updateProfile(ProfileModel profile) async {
    try {
      final docRef = _firestore.collection(_collection).doc(profile.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Profile not found',
        );
      }

      await docRef.update(profile.toMap());
    } on FirebaseException catch (e) {
      throw _handleFirestoreError(e);
    }
  }

  /// Retrieves a user profile by ID
  /// 
  /// Returns null if the profile doesn't exist
  /// Throws [FirebaseException] if the operation fails
  Future<ProfileModel?> getProfile(String uid) async {
    try {
      final doc = await _firestore
        .collection(_collection)
        .doc(uid)
        .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return ProfileModel.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw _handleFirestoreError(e);
    }
  }

  /// Deletes a user profile
  /// 
  /// Throws [FirebaseException] if the profile doesn't exist or the operation fails
  Future<void> deleteProfile(String uid) async {
    try {
      final docRef = _firestore.collection(_collection).doc(uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Profile not found',
        );
      }

      await docRef.delete();
    } on FirebaseException catch (e) {
      throw _handleFirestoreError(e);
    }
  }

  /// Handles Firestore errors and provides user-friendly error messages
  FirebaseException _handleFirestoreError(FirebaseException e) {
    String message = 'An error occurred while accessing Firestore';
    
    switch (e.code) {
      case 'permission-denied':
        message = 'You do not have permission to perform this operation';
        break;
      case 'not-found':
        message = 'The requested profile was not found';
        break;
      case 'already-exists':
        message = 'A profile with this ID already exists';
        break;
      case 'unavailable':
        message = 'The service is currently unavailable. Please try again later';
        break;
    }

    return FirebaseException(
      plugin: e.plugin,
      code: e.code,
      message: message,
    );
  }
}
