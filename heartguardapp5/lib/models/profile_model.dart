import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing a user profile in the application.
/// 
/// Contains user information such as:
/// - Basic details (uid, email, name)
/// - Profile photo URL
/// - Last active timestamp
class ProfileModel {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
  final DateTime? lastActive;

  const ProfileModel({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
    this.lastActive,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      lastActive: map['lastActive'] != null 
        ? (map['lastActive'] as Timestamp).toDate()
        : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    }..removeWhere((key, value) => value == null);
  }

  /// Creates a copy of this profile with the given fields replaced with new values
  ProfileModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    DateTime? lastActive,
  }) {
    return ProfileModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileModel &&
      other.uid == uid &&
      other.email == email &&
      other.name == name &&
      other.photoUrl == photoUrl &&
      other.lastActive?.isAtSameMomentAs(lastActive ?? DateTime(0)) == true;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      name,
      photoUrl,
      lastActive,
    );
  }

  @override
  String toString() {
    return 'ProfileModel('
      'uid: $uid, '
      'email: $email, '
      'name: $name, '
      'photoUrl: $photoUrl, '
      'lastActive: $lastActive'
      ')';
  }
} 