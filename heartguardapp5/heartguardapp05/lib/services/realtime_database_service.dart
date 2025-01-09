import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class RealtimeDatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Add data
  Future<void> addData(String path, Map<String, dynamic> data) async {
    await _database.child(path).set(data);
  }

  /// Fetch users data and convert to List<UserModel>
  Future<List<UserModel>> fetchData(String path) async {
    final snapshot = await _database.child(path).get();
    final List<UserModel> users = [];
    
    if (snapshot.value != null && snapshot.value is Map) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        if (value is Map) {
          users.add(UserModel.fromMap(Map<String, dynamic>.from(value)));
        }
      });
    }
    
    return users;
  }

  // Update data
  Future<void> updateData(String path, Map<String, dynamic> data) async {
    await _database.child(path).update(data);
  }

  // Delete data
  Future<void> deleteData(String path) async {
    await _database.child(path).remove();
  }
}
