import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class SMSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get emergency contacts from Firebase
  Future<List<String>> getEmergencyContacts() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        return [];
      }

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print('User document does not exist');
        return [];
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> contacts = data['emergency_contacts'] ?? [];
      return contacts.map((contact) => contact.toString()).toList();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }

  // Send emergency message to all contacts
  Future<void> sendEmergencyMessage(String abnormalityType) async {
    try {
      final List<String> emergencyContacts = await getEmergencyContacts();
      
      if (emergencyContacts.isEmpty) {
        print('No emergency contacts found');
        return;
      }

      for (String phoneNumber in emergencyContacts) {
        await _sendSingleMessage(phoneNumber, abnormalityType);
      }
    } catch (e) {
      print('Error in sendEmergencyMessage: $e');
    }
  }

  // Send message to a single contact
  Future<void> _sendSingleMessage(String phoneNumber, String abnormalityType) async {
    try {
      final message = '''EMERGENCY ALERT from HeartGuard
Abnormal heart condition detected: $abnormalityType
Please check on the patient immediately.
Time: ${DateTime.now().toString()}''';

      final Uri smsUri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        await _logMessageAttempt(phoneNumber, abnormalityType, true);
      } else {
        print('Could not launch SMS for $phoneNumber');
        await _logMessageAttempt(phoneNumber, abnormalityType, false);
      }
    } catch (e) {
      print('Error sending message to $phoneNumber: $e');
      await _logMessageAttempt(phoneNumber, abnormalityType, false);
    }
  }

  // Log message attempts to Firebase
  Future<void> _logMessageAttempt(String phoneNumber, String abnormalityType, bool success) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('emergency_alerts').add({
          'userId': user.uid,
          'phoneNumber': phoneNumber,
          'abnormalityType': abnormalityType,
          'timestamp': FieldValue.serverTimestamp(),
          'success': success,
        });
      }
    } catch (e) {
      print('Error logging message attempt: $e');
    }
  }
}
