/// Model class representing a user in the application
class UserModel {
  String id;
  String name;
  String email;
  bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.isActive = false,
  });

  // Convert a UserModel into a Map. The keys must correspond to the
  // names of the fields in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isActive': isActive,
    };
  }

  // Extract a UserModel from a Map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      isActive: map['isActive'] ?? false,
    );
  }
} 