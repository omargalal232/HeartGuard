class UserModel {
  final String id;
  final String email;

  UserModel({
    required this.id,
    required this.email,
  });

  // Convert a UserModel into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
    };
  }

  // Create a UserModel from a Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
    );
  }
}