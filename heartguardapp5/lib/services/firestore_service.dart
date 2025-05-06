import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';
import 'package:heartguardapp05/services/logger_service.dart';

/// Service class for handling Firestore operations related to user profiles.
/// 
/// Provides methods for:
/// - Creating new profiles
/// - Updating existing profiles
/// - Retrieving profile information
/// - Deleting profiles
class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LoggerService _logger;

  FirestoreService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required LoggerService logger,
  })  : _firestore = firestore,
        _auth = auth,
        _logger = logger;

  /// Creates a new user profile in Firestore
  /// 
  /// Throws [FirebaseException] if the operation fails
  Future<void> createProfile(ProfileModel profile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'User must be authenticated to create a profile',
        );
      }

      if (user.uid != profile.uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Cannot create profile for another user',
        );
      }

      await _firestore
        .collection('profiles')
        .doc(profile.uid)
        .set(profile.toMap());

      _logger.i('Profile created successfully for user: ${profile.uid}');
    } on FirebaseException catch (e) {
      _logger.e('Error creating profile: ${e.message}', e);
      throw _handleFirestoreError(e);
    }
  }

  /// Updates an existing user profile
  /// 
  /// Throws [FirebaseException] if the profile doesn't exist or the operation fails
  Future<void> updateProfile(ProfileModel profile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'User must be authenticated to update a profile',
        );
      }

      if (user.uid != profile.uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Cannot update profile for another user',
        );
      }

      final docRef = _firestore.collection('profiles').doc(profile.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Profile not found',
        );
      }

      await docRef.update(profile.toMap());
      _logger.i('Profile updated successfully for user: ${profile.uid}');
    } on FirebaseException catch (e) {
      _logger.e('Error updating profile: ${e.message}', e);
      throw _handleFirestoreError(e);
    }
  }

  /// Retrieves a user profile by ID
  /// 
  /// Returns null if the profile doesn't exist
  /// Throws [FirebaseException] if the operation fails
  Future<ProfileModel?> getProfile(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'User must be authenticated to access profiles',
        );
      }

      if (user.uid != uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Cannot access profile for another user',
        );
      }

      final doc = await _firestore
        .collection('profiles')
        .doc(uid)
        .get();

      if (!doc.exists || doc.data() == null) {
        _logger.i('Profile not found for user: $uid');
        return null;
      }

      final profile = ProfileModel.fromMap(doc.data()!);
      _logger.i('Profile retrieved successfully for user: $uid');
      return profile;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _logger.w('Permission denied accessing profile for user: $uid');
        return null;
      }
      _logger.e('Error getting profile: ${e.message}', e);
      throw _handleFirestoreError(e);
    }
  }

  /// Gets the current user's profile
  Future<ProfileModel?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.w('No authenticated user found');
      return null;
    }
    return await getProfile(user.uid);
  }

  /// Deletes a user profile
  /// 
  /// Throws [FirebaseException] if the profile doesn't exist or the operation fails
  Future<void> deleteProfile(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'User must be authenticated to delete a profile',
        );
      }

      if (user.uid != uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Cannot delete profile for another user',
        );
      }

      final docRef = _firestore.collection('profiles').doc(uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Profile not found',
        );
      }

      await docRef.delete();
      _logger.i('Profile deleted successfully for user: $uid');
    } on FirebaseException catch (e) {
      _logger.e('Error deleting profile: ${e.message}', e);
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
      case 'unauthenticated':
        message = 'You must be signed in to perform this operation';
        break;
    }

    return FirebaseException(
      plugin: e.plugin,
      code: e.code,
      message: message,
    );
  }

  Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).add(data);
      _logger.i('Document added to $collection');
    } catch (e) {
      _logger.e('Error adding document to $collection', e);
      rethrow;
    }
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
      _logger.i('Document $documentId updated in $collection');
    } catch (e) {
      _logger.e('Error updating document $documentId in $collection', e);
      rethrow;
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
      _logger.i('Document $documentId deleted from $collection');
    } catch (e) {
      _logger.e('Error deleting document $documentId from $collection', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      if (!doc.exists) {
        _logger.w('Document $documentId not found in $collection');
        return null;
      }
      _logger.i('Document $documentId retrieved from $collection');
      return doc.data();
    } catch (e) {
      _logger.e('Error getting document $documentId from $collection', e);
      rethrow;
    }
  }
}
