import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class CloudStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload file
  Future<String?> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('File upload failed: $e');
      return null;
    }
  }

  // Download file
  Future<void> downloadFile(String url, String localPath) async {
    try {
      final ref = await _storage.refFromURL(url).writeToFile(File(localPath));
      print('File downloaded to $localPath');
    } catch (e) {
      print('File download failed: $e');
    }
  }
}
