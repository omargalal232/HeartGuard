/// Model class representing a user profile in the application.
/// 
/// Contains user information such as:
/// - Basic details (uid, email, name)
/// - Profile photo URL
/// - Last active timestamp
class ProfileModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final String gender;
  final int height;
  final int weight;
  final String bloodType;
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> allergies;
  final List<Map<String, dynamic>> emergencyContacts;

  const ProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.height,
    required this.weight,
    required this.bloodType,
    required this.medicalConditions,
    required this.medications,
    required this.allergies,
    required this.emergencyContacts,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'height': height,
      'weight': weight,
      'bloodType': bloodType,
      'medicalConditions': medicalConditions,
      'medications': medications,
      'allergies': allergies,
      'emergencyContacts': emergencyContacts,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    try {
      return ProfileModel(
        uid: map['uid']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        phoneNumber: map['phoneNumber']?.toString() ?? '',
        dateOfBirth: map['dateOfBirth'] != null 
          ? DateTime.tryParse(map['dateOfBirth'].toString()) ?? DateTime.now()
          : DateTime.now(),
        gender: map['gender']?.toString() ?? 'Not specified',
        height: map['height'] != null ? int.tryParse(map['height'].toString()) ?? 0 : 0,
        weight: map['weight'] != null ? int.tryParse(map['weight'].toString()) ?? 0 : 0,
        bloodType: map['bloodType']?.toString() ?? 'Unknown',
        medicalConditions: (map['medicalConditions'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ?? [],
        medications: (map['medications'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ?? [],
        allergies: (map['allergies'] as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ?? [],
        emergencyContacts: (map['emergencyContacts'] as List?)
            ?.map((e) => (e as Map<String, dynamic>?) ?? {})
            .where((e) => e.isNotEmpty)
            .toList() ?? [],
      );
    } catch (e) {
      // If there's any error in parsing, return a default profile
      return ProfileModel(
        uid: map['uid']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        phoneNumber: '',
        dateOfBirth: DateTime.now(),
        gender: 'Not specified',
        height: 0,
        weight: 0,
        bloodType: 'Unknown',
        medicalConditions: [],
        medications: [],
        allergies: [],
        emergencyContacts: [],
      );
    }
  }

  /// Creates a copy of this profile with the given fields replaced with new values
  ProfileModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? gender,
    int? height,
    int? weight,
    String? bloodType,
    List<String>? medicalConditions,
    List<String>? medications,
    List<String>? allergies,
    List<Map<String, dynamic>>? emergencyContacts,
  }) {
    return ProfileModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodType: bloodType ?? this.bloodType,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileModel &&
      other.uid == uid &&
      other.email == email &&
      other.name == name;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      name,
    );
  }

  @override
  String toString() {
    return 'ProfileModel('
      'uid: $uid, '
      'email: $email, '
      'name: $name'
      ')';
  }
} 