import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'logger_service.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  final Logger _logger = Logger();
  static const String _tag = 'SMSService';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Twilio credentials - should be stored in .env file
  String? get _twilioAccountSid => dotenv.env['TWILIO_ACCOUNT_SID'];
  String? get _twilioAuthToken => dotenv.env['TWILIO_AUTH_TOKEN'];
  String? get _twilioPhoneNumber => dotenv.env['TWILIO_PHONE_NUMBER'];

  // Initialize the service
  Future<void> init() async {
    try {
      _logger.i(_tag, 'SMS Service initialized');
      
      // Verify Twilio credentials are available
      if (_twilioAccountSid == null || _twilioAuthToken == null || _twilioPhoneNumber == null) {
        _logger.w(_tag, 'Twilio credentials not found in .env file');
      } else {
        _logger.i(_tag, 'Twilio credentials found and ready to use');
      }
    } catch (e) {
      _logger.e(_tag, 'Error initializing SMS service', e);
    }
  }

  // Get emergency contacts for a user
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    try {
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .get();

      return contactsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      _logger.e(_tag, 'Error fetching emergency contacts', e);
      return [];
    }
  }

  // Send SMS notification for abnormal heart rate
  Future<bool> sendAbnormalHeartRateAlert({
    required String userId,
    required double heartRate,
    required String abnormalityType,
  }) async {
    try {
      _logger.i(_tag, 'Sending SMS alert for abnormal heart rate: $heartRate');

      // Get emergency contacts
      final emergencyContacts = await getEmergencyContacts(userId);
      if (emergencyContacts.isEmpty) {
        _logger.w(_tag, 'No emergency contacts found for user: $userId');
        return false;
      }

      // Get user profile for name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? 'A HeartGuard user';

      // Create message based on abnormality type
      String messageBody;
      if (abnormalityType == 'high_heart_rate') {
        messageBody = 'ALERT: $userName has a high heart rate of ${heartRate.round()} BPM detected by HeartGuard app. Please check on them.';
      } else if (abnormalityType == 'low_heart_rate') {
        messageBody = 'ALERT: $userName has a low heart rate of ${heartRate.round()} BPM detected by HeartGuard app. Please check on them.';
      } else {
        messageBody = 'ALERT: $userName has an abnormal heart rate of ${heartRate.round()} BPM detected by HeartGuard app. Please check on them.';
      }

      // Send SMS to each emergency contact
      bool allSuccessful = true;
      for (final contact in emergencyContacts) {
        final phone = contact['phone'] as String;
        final name = contact['name'] as String;
        
        // Add personal greeting with contact name
        final personalizedMessage = 'Hi $name, $messageBody';
        
        final success = await _sendTwilioSMS(
          to: phone,
          body: personalizedMessage,
        );

        if (success) {
          _logger.i(_tag, 'SMS alert sent successfully to $name ($phone)');
          
          // Log successful SMS in Firestore
          await _logSMSNotification(
            userId: userId,
            contactId: contact['id'] as String,
            contactName: name,
            contactPhone: phone,
            message: personalizedMessage,
            success: true,
          );
        } else {
          _logger.w(_tag, 'Failed to send SMS alert to $name ($phone)');
          allSuccessful = false;
          
          // Log failed SMS in Firestore
          await _logSMSNotification(
            userId: userId,
            contactId: contact['id'] as String,
            contactName: name,
            contactPhone: phone,
            message: personalizedMessage,
            success: false,
          );
        }
      }

      return allSuccessful;
    } catch (e) {
      _logger.e(_tag, 'Error sending SMS alert', e);
      return false;
    }
  }

  // Send SMS using Twilio API
  Future<bool> _sendTwilioSMS({
    required String to,
    required String body,
  }) async {
    try {
      // Check if Twilio credentials are available
      if (_twilioAccountSid == null || _twilioAuthToken == null || _twilioPhoneNumber == null) {
        _logger.e(_tag, 'Twilio credentials not available');
        return false;
      }

      // Format phone number to E.164 format if needed
      String formattedPhone = to;
      if (!to.startsWith('+')) {
        formattedPhone = '+$to';
      }

      // Prepare auth header
      final auth = 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}';

      // Prepare form data
      final formData = {
        'To': formattedPhone,
        'From': _twilioPhoneNumber!,
        'Body': body,
      };

      // Make HTTP request to Twilio API
      final response = await http.post(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json'),
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _logger.i(_tag, 'SMS sent successfully via Twilio');
        return true;
      } else {
        _logger.e(_tag, 'Failed to send SMS. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error in Twilio SMS sending', e);
      return false;
    }
  }

  // Log SMS notification in Firestore
  Future<void> _logSMSNotification({
    required String userId,
    required String contactId,
    required String contactName,
    required String contactPhone,
    required String message,
    required bool success,
  }) async {
    try {
      await _firestore.collection('sms_notifications').add({
        'userId': userId,
        'contactId': contactId,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'message': message,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'provider': 'twilio',
      });
    } catch (e) {
      _logger.e(_tag, 'Error logging SMS notification', e);
    }
  }

  // Test method to send a test SMS
  Future<bool> sendTestSMS({
    required String userId,
    String? phoneNumber,
  }) async {
    try {
      _logger.i(_tag, 'Sending test SMS');

      String recipientPhone;
      String recipientName;

      // If phone number is provided, use it
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        recipientPhone = phoneNumber;
        recipientName = "Tester";
      } else {
        // Otherwise, get first emergency contact
        final contacts = await getEmergencyContacts(userId);
        if (contacts.isEmpty) {
          _logger.w(_tag, 'No emergency contacts found for test SMS');
          return false;
        }
        
        recipientPhone = contacts.first['phone'] as String;
        recipientName = contacts.first['name'] as String;
      }

      // Send test message
      final testMessage = 'Hi $recipientName, this is a test message from HeartGuard app. Your emergency contact alerts are working correctly.';
      
      final success = await _sendTwilioSMS(
        to: recipientPhone,
        body: testMessage,
      );

      if (success) {
        _logger.i(_tag, 'Test SMS sent successfully to $recipientName ($recipientPhone)');
        
        // Log test SMS
        await _logSMSNotification(
          userId: userId,
          contactId: 'test',
          contactName: recipientName,
          contactPhone: recipientPhone,
          message: testMessage,
          success: true,
        );
      } else {
        _logger.w(_tag, 'Failed to send test SMS');
      }

      return success;
    } catch (e) {
      _logger.e(_tag, 'Error sending test SMS', e);
      return false;
    }
  }
} 