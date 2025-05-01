/// Model class representing a user in the application
class UserModel {
  final String uid;
  final String email;
  final String? name;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.isActive = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString(),
      isActive: map['isActive'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'isActive': isActive,
    };
  }
} 