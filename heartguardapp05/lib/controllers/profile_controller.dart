import '../services/firestore_service.dart';
import '../models/profile_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Controller for managing user profiles
class ProfileController {
  final FirestoreService _firestoreService = FirestoreService();

  /// Creates a new user profile
  Future<void> createProfile(ProfileModel profile) async {
    await _firestoreService.createProfile(profile);
  }

  /// Updates an existing profile
  Future<void> updateProfile(ProfileModel profile) async {
    await _firestoreService.updateProfile(profile);
  }

  /// Gets a profile by user ID
  Future<ProfileModel?> getProfile(String uid) async {
    return await _firestoreService.getProfile(uid);
  }

  /// Gets the current user's profile
  Future<ProfileModel?> getCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await getProfile(user.uid);
  }

  /// Updates the last active timestamp for a profile
  Future<void> updateLastActive(String uid) async {
    final profile = await getProfile(uid);
    if (profile != null) {
      await updateProfile(
        profile.copyWith(lastActive: DateTime.now()),
      );
    }
  }

  /// Deletes a profile
  Future<void> deleteProfile(String uid) async {
    await _firestoreService.deleteProfile(uid);
  }
} 