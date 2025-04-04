import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:heartguardapp05/services/logger_service.dart';

class CloudStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();
  static const String _tag = 'CloudStorageService';

  // Upload file
  Future<String?> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.e(_tag, 'File upload failed: $e');
      return null;
    }
  }

  // Download file
  Future<void> downloadFile(String url, String localPath) async {
    try {
      await _storage.refFromURL(url).writeToFile(File(localPath));
      _logger.i(_tag, 'File downloaded to $localPath');
    } catch (e) {
      _logger.e(_tag, 'File download failed: $e');
    }
  }
}
