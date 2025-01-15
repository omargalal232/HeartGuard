import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new user
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      print('Error creating user: $e');
    }
  }

  // Read a user
  Future<UserModel?> getUser(String id) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(id).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error getting user: $e');
    }
    return null;
  }

  // Update a user
  Future<void> updateUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  // Delete a user
  Future<void> deleteUser(String id) async {
    try {
      await _db.collection('users').doc(id).delete();
    } catch (e) {
      print('Error deleting user: $e');
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _db.collection('users').get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }
} 