import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new user
  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  // Read a user
  Future<UserModel?> getUser(String id) async {
    DocumentSnapshot doc = await _db.collection('users').doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Update a user
  Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }

  // Delete a user
  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    QuerySnapshot snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
} 