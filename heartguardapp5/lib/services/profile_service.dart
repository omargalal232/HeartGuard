import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';
import 'firestore_service.dart';
import 'logger_service.dart';

/// Service for managing user profiles
/// Wraps FirestoreService to provide a simpler interface
class ProfileService {
  late final FirestoreService _firestoreService;
  
  ProfileService() {
    _firestoreService = FirestoreService(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
      logger: LoggerService(),
    );
  }

  /// Gets the current user's profile
  Future<ProfileModel> getCurrentUserProfile() async {
    final profile = await _firestoreService.getCurrentProfile();
    if (profile == null) {
      throw Exception('User profile not found. Please complete your profile setup.');
    }
    return profile;
  }

  /// Get a user's profile by user ID
  Future<ProfileModel?> getUserProfile(String uid) async {
    return await _firestoreService.getProfile(uid);
  }

  /// Updates the current user's profile
  Future<void> updateProfile(ProfileModel profile) async {
    await _firestoreService.updateProfile(profile);
  }
} 