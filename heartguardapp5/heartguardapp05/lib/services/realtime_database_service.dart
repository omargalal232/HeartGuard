import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Add data
  Future<void> addData(String path, Map<String, dynamic> data) async {
    await _database.child(path).set(data);
  }

  // Fetch data
  Future<DataSnapshot> fetchData(String path) async {
    return await _database.child(path).get();
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
