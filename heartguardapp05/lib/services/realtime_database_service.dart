import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get user's profile data
  Future<DataSnapshot> getUserProfile(String userId) async {
    try {
      final DatabaseReference userProfileRef = _database.ref('users/$userId/profile');
      return await userProfileRef.get();
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user's profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      final DatabaseReference userProfileRef = _database.ref('users/$userId/profile');
      profileData['updatedAt'] = ServerValue.timestamp;
      await userProfileRef.update(profileData);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Get user's heart rate data
  Future<DataSnapshot> getHeartRateData(String userId) async {
    try {
      final DatabaseReference heartRateRef = _database.ref('users/$userId/heartRate/latest');
      return await heartRateRef.get();
    } catch (e) {
      throw Exception('Failed to get heart rate data: $e');
    }
  }

  // Save user's heart rate data
  Future<void> saveHeartRateData(String userId, Map<String, dynamic> heartRateData) async {
    try {
      final DatabaseReference userHeartRateRef = _database.ref('users/$userId/heartRate');
      // Save to history
      await userHeartRateRef.child('history').push().set(heartRateData);
      // Update latest
      await userHeartRateRef.child('latest').set(heartRateData);
    } catch (e) {
      throw Exception('Failed to save heart rate data: $e');
    }
  }

  // Get user's heart rate history
  Stream<DatabaseEvent> getHeartRateHistory(String userId) {
    try {
      final DatabaseReference userHeartRateRef = _database.ref('users/$userId/heartRate/history');
      return userHeartRateRef.orderByChild('timestamp').limitToLast(100).onValue;
    } catch (e) {
      throw Exception('Failed to get heart rate history: $e');
    }
  }

  // Save user's alert
  Future<void> saveAlert(String userId, Map<String, dynamic> alertData) async {
    try {
      final DatabaseReference userAlertsRef = _database.ref('users/$userId/alerts');
      await userAlertsRef.push().set(alertData);
    } catch (e) {
      throw Exception('Failed to save alert: $e');
    }
  }

  // Delete user's alert
  Future<void> deleteAlert(String userId, String alertId) async {
    try {
      final DatabaseReference alertRef = _database.ref('users/$userId/alerts/$alertId');
      await alertRef.remove();
    } catch (e) {
      throw Exception('Failed to delete alert: $e');
    }
  }

  // Get user's alerts
  Stream<DatabaseEvent> getAlerts(String userId) {
    try {
      final DatabaseReference userAlertsRef = _database.ref('users/$userId/alerts');
      return userAlertsRef.orderByChild('timestamp').onValue;
    } catch (e) {
      throw Exception('Failed to get alerts: $e');
    }
  }

  // Update user's emergency contacts
  Future<void> updateEmergencyContacts(String userId, List<Map<String, dynamic>> contacts) async {
    try {
      final DatabaseReference emergencyContactsRef = _database.ref('users/$userId/emergencyContacts');
      await emergencyContactsRef.set(contacts);
    } catch (e) {
      throw Exception('Failed to update emergency contacts: $e');
    }
  }

  // Get user's emergency contacts
  Future<DataSnapshot> getEmergencyContacts(String userId) async {
    try {
      final DatabaseReference emergencyContactsRef = _database.ref('users/$userId/emergencyContacts');
      return await emergencyContactsRef.get();
    } catch (e) {
      throw Exception('Failed to get emergency contacts: $e');
    }
  }

  // Update user's health profile
  Future<void> updateHealthProfile(String userId, Map<String, dynamic> healthProfile) async {
    try {
      final DatabaseReference healthProfileRef = _database.ref('users/$userId/healthProfile');
      await healthProfileRef.update(healthProfile);
    } catch (e) {
      throw Exception('Failed to update health profile: $e');
    }
  }

  // Get user's health profile
  Future<DataSnapshot> getHealthProfile(String userId) async {
    try {
      final DatabaseReference healthProfileRef = _database.ref('users/$userId/healthProfile');
      return await healthProfileRef.get();
    } catch (e) {
      throw Exception('Failed to get health profile: $e');
    }
  }
}
