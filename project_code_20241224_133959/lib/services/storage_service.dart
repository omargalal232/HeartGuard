import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload ECG Data (Assuming it's stored as a file)
  Future<String> uploadECGData(String userId, File ecgFile) async {
    try {
      Reference ref = _storage.ref().child('ecg_data/$userId/${DateTime.now().millisecondsSinceEpoch}.txt');
      UploadTask uploadTask = ref.putFile(ecgFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload ECG data: $e');
    }
  }

  /// Upload Profile Image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      Reference ref = _storage.ref().child('profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Download ECG Data
  Future<File> downloadECGData(String userId, String ecgFileName) async {
    try {
      Reference ref = _storage.ref().child('ecg_data/$userId/$ecgFileName');
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$ecgFileName');
      await ref.writeToFile(tempFile);
      return tempFile;
    } catch (e) {
      throw Exception('Failed to download ECG data: $e');
    }
  }

  /// Delete Profile Image
  Future<void> deleteProfileImage(String userId, String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete profile image: $e');
    }
  }

  /// Upload Additional Files (e.g., Documents)
  Future<String> uploadAdditionalFile(String userId, File file, String folder, String fileExtension) async {
    try {
      Reference ref = _storage.ref().child('$folder/$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Download Additional Files
  Future<File> downloadAdditionalFile(String userId, String folder, String fileName) async {
    try {
      Reference ref = _storage.ref().child('$folder/$userId/$fileName');
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await ref.writeToFile(tempFile);
      return tempFile;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  /// Delete Additional Files
  Future<void> deleteAdditionalFile(String userId, String folder, String fileName) async {
    try {
      Reference ref = _storage.ref().child('$folder/$userId/$fileName');
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // ... Add more storage operations as needed ...
}