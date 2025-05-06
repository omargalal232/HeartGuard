import 'package:heartguardapp05/services/firestore_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';
import 'package:heartguardapp05/models/profile_model.dart';

/// Controller for managing user profiles
class ProfileController {
  final FirestoreService _firestoreService;
  final LoggerService _logger;

  ProfileController({
    required FirestoreService firestoreService,
    required LoggerService logger,
  })  : _firestoreService = firestoreService,
        _logger = logger;

  /// Creates a new user profile
  Future<void> createProfile(ProfileModel profile) async {
    try {
      await _firestoreService.createProfile(profile);
      _logger.i('Profile created successfully for user: ${profile.uid}');
    } catch (e) {
      _logger.e('Error creating profile: $e');
      rethrow;
    }
  }

  /// Updates an existing profile
  Future<void> updateProfile(ProfileModel profile) async {
    try {
      await _firestoreService.updateProfile(profile);
      _logger.i('Profile updated successfully for user: ${profile.uid}');
    } catch (e) {
      _logger.e('Error updating profile: $e');
      rethrow;
    }
  }

  /// Gets a profile by user ID
  Future<ProfileModel?> getProfile(String uid) async {
    try {
      final profile = await _firestoreService.getProfile(uid);
      if (profile == null) {
        _logger.w('Profile not found for user: $uid');
      } else {
        _logger.i('Profile retrieved successfully for user: $uid');
      }
      return profile;
    } catch (e) {
      _logger.e('Error getting profile: $e');
      rethrow;
    }
  }

  /// Gets the current user's profile
  Future<ProfileModel?> getCurrentProfile() async {
    try {
      final profile = await _firestoreService.getCurrentProfile();
      if (profile == null) {
        _logger.w('No profile found for current user');
      } else {
        _logger.i('Current user profile retrieved successfully');
      }
      return profile;
    } catch (e) {
      _logger.e('Error getting current profile: $e');
      rethrow;
    }
  }

  /// Deletes a user profile
  Future<void> deleteProfile(String uid) async {
    try {
      await _firestoreService.deleteProfile(uid);
      _logger.i('Profile deleted successfully for user: $uid');
    } catch (e) {
      _logger.e('Error deleting profile: $e');
      rethrow;
    }
  }
} 