import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/recording_model.dart';
import '../models/alert_model.dart';
import '../models/emergency_contact_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add User Data
  Future<void> addUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  // Get User Data as a Stream
  Stream<UserModel?> getUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  // Update User Data
  Future<void> updateUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete User Data
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Add ECG Recording
  Future<void> addECGRecording(RecordingModel recording) async {
    try {
      await _db
          .collection('users')
          .doc(recording.userId)
          .collection('recordings')
          .add(recording.toMap());
    } catch (e) {
      throw Exception('Failed to add ECG recording: $e');
    }
  }

  // Get ECG Recordings as a Stream
  Stream<List<RecordingModel>> getECGRecordings(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecordingModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update ECG Recording
  Future<void> updateECGRecording(String userId, String recordingId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recordingId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update ECG recording: $e');
    }
  }

  // Delete ECG Recording
  Future<void> deleteECGRecording(String userId, String recordingId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recordingId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete ECG recording: $e');
    }
  }

  // Add Alert
  Future<void> addAlert(String userId, AlertModel alert) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .add(alert.toMap());
    } catch (e) {
      throw Exception('Failed to add alert: $e');
    }
  }

  // Get Alerts as a Stream
  Stream<List<AlertModel>> getUserAlerts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlertModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Update Alert
  Future<void> updateAlert(String userId, String alertId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(alertId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update alert: $e');
    }
  }

  // Delete Alert
  Future<void> deleteAlert(String userId, String alertId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }

  // Add Emergency Contact
  Future<void> addEmergencyContact(String userId, EmergencyContactModel contact) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .add(contact.toMap());
    } catch (e) {
      throw Exception('Failed to add emergency contact: $e');
    }
  }

  // Get Emergency Contacts as a Stream
  Stream<List<EmergencyContactModel>> getEmergencyContacts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('emergency_contacts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmergencyContactModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update Emergency Contact
  Future<void> updateEmergencyContact(String userId, String contactId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contactId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update emergency contact: $e');
    }
  }

  // Delete Emergency Contact
  Future<void> deleteEmergencyContact(String userId, String contactId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete emergency contact: $e');
    }
  }

  // Add Connected Device
  Future<void> addConnectedDevice(String userId, Map<String, dynamic> deviceData) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('connected_devices')
          .add(deviceData);
    } catch (e) {
      throw Exception('Failed to add connected device: $e');
    }
  }

  // Get Connected Devices as a Stream
  Stream<List<Map<String, dynamic>>> getConnectedDevices(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('connected_devices')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  // Update Connected Device
  Future<void> updateConnectedDevice(String userId, String deviceId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('connected_devices')
          .doc(deviceId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update connected device: $e');
    }
  }

  // Delete Connected Device
  Future<void> deleteConnectedDevice(String userId, String deviceId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('connected_devices')
          .doc(deviceId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete connected device: $e');
    }
  }

  // Add Recording Data
  Future<void> addRecording(RecordingModel recording) async {
    try {
      await _db
          .collection('users')
          .doc(recording.userId)
          .collection('recordings')
          .doc(recording.recordingId)
          .set(recording.toMap());
    } catch (e) {
      throw Exception('Failed to add recording: $e');
    }
  }

  // Get Recordings as a Stream
  Stream<List<RecordingModel>> getUserRecordings(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecordingModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update Recording Status
  Future<void> updateRecordingStatus(String userId, String recordingId, String status) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recordingId)
          .update({'status': status});
    } catch (e) {
      throw Exception('Failed to update recording status: $e');
    }
  }

  // Delete Recording
  Future<void> deleteRecording(String userId, String recordingId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recordingId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete recording: $e');
    }
  }

  // ... Additional Firestore operations as needed ...
}

// Extension for FirestoreService (if needed)
extension FirestoreServiceExtension on FirestoreService {
  // You can add additional helper methods here if necessary
}