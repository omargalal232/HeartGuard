import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:heartguardapp05/services/sms_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';

import 'sms_service_test.mocks.dart';

/// This test file contains comprehensive tests for the SMS service.
/// It tests the functionality of sending SMS alerts for abnormal heart rate conditions.
/// The tests cover emergency contact retrieval, SMS sending, and error handling.

// Generate mocks for all external dependencies
@GenerateMocks([
  FirebaseFirestore,
  http.Client,
  Logger,
])
void main() {
  // Declare mock objects that will be used across multiple tests
  late MockFirebaseFirestore mockFirestore;
  late MockClient mockHttpClient;
  late MockLogger mockLogger;
  late SMSService smsService;
  
  /// Setup function that runs before each test
  /// Initializes all mock objects and configures their default behavior
  setUp(() {
    // Initialize mock objects
    mockFirestore = MockFirebaseFirestore();
    mockHttpClient = MockClient();
    mockLogger = MockLogger();
    
    // Configure default mock behavior
    when(mockFirestore.collection('emergencyContacts')).thenReturn(mockEmergencyContactsCollection);
    when(mockEmergencyContactsCollection.where('userId', isEqualTo: 'test-user-id')).thenReturn(mockEmergencyContactsQuery);
    when(mockEmergencyContactsQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
    
    // Initialize the SMS service with mock dependencies
    smsService = SMSService(
      firestore: mockFirestore,
      httpClient: mockHttpClient,
      logger: mockLogger,
    );
  });
  
  /// Test group for SMS service initialization
  /// Tests the setup and configuration of the SMS service
  group('SMS Service Initialization', () {
    /// Test successful initialization of SMS service
    /// Verifies that Twilio credentials are properly loaded
    test('Should initialize SMS service successfully', () async {
      // Arrange
      when(dotenv.env['TWILIO_ACCOUNT_SID']).thenReturn('test-sid');
      when(dotenv.env['TWILIO_AUTH_TOKEN']).thenReturn('test-token');
      when(dotenv.env['TWILIO_PHONE_NUMBER']).thenReturn('+1234567890');
      
      // Act
      await smsService.initialize();
      
      // Assert
      // Verify credentials were loaded
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('SMS service initialized')),
      )).called(1);
    });
    
    /// Test handling of missing Twilio credentials
    /// Verifies that the service handles missing credentials gracefully
    test('Should handle missing Twilio credentials', () async {
      // Arrange
      when(dotenv.env['TWILIO_ACCOUNT_SID']).thenReturn(null);
      
      // Act
      await smsService.initialize();
      
      // Assert
      // Verify error was logged
      verify(mockLogger.e(
        any(that: isA<String>()),
        any(that: contains('Missing Twilio credentials')),
        any(that: isA<Exception>()),
      )).called(1);
    });
  });
  
  /// Test group for emergency contact management
  /// Tests the functionality of retrieving and managing emergency contacts
  group('Emergency Contact Management', () {
    /// Test successful retrieval of emergency contacts
    /// Verifies that contacts are properly loaded from Firestore
    test('Should retrieve emergency contacts successfully', () async {
      // Arrange
      final mockContacts = [
        {'name': 'Contact 1', 'phone': '+1234567890'},
        {'name': 'Contact 2', 'phone': '+0987654321'},
      ];
      
      when(mockQuerySnapshot.docs).thenReturn(mockContacts.map((contact) {
        final mockDoc = MockQueryDocumentSnapshot();
        when(mockDoc.data()).thenReturn(contact);
        return mockDoc;
      }).toList());
      
      // Act
      final contacts = await smsService.getEmergencyContacts('test-user-id');
      
      // Assert
      expect(contacts.length, equals(2));
      expect(contacts[0]['name'], equals('Contact 1'));
      expect(contacts[1]['name'], equals('Contact 2'));
      
      // Verify Firestore query was executed
      verify(mockFirestore.collection('emergencyContacts')).called(1);
      verify(mockEmergencyContactsCollection.where('userId', isEqualTo: 'test-user-id')).called(1);
    });
    
    /// Test handling of empty emergency contacts
    /// Verifies that the service handles no contacts gracefully
    test('Should handle empty emergency contacts', () async {
      // Arrange
      when(mockQuerySnapshot.docs).thenReturn([]);
      
      // Act
      final contacts = await smsService.getEmergencyContacts('test-user-id');
      
      // Assert
      expect(contacts, isEmpty);
      
      // Verify warning was logged
      verify(mockLogger.w(
        any(that: isA<String>()),
        any(that: contains('No emergency contacts found')),
      )).called(1);
    });
  });
  
  /// Test group for SMS sending
  /// Tests the functionality of sending SMS alerts
  group('SMS Sending', () {
    /// Test sending abnormal heart rate alert
    /// Verifies that alerts are properly formatted and sent
    test('Should send abnormal heart rate alert', () async {
      // Arrange
      final userId = 'test-user-id';
      final heartRate = 120.0;
      final abnormalityType = 'high_heart_rate';
      
      final mockContacts = [
        {'name': 'Contact 1', 'phone': '+1234567890'},
        {'name': 'Contact 2', 'phone': '+0987654321'},
      ];
      
      when(mockQuerySnapshot.docs).thenReturn(mockContacts.map((contact) {
        final mockDoc = MockQueryDocumentSnapshot();
        when(mockDoc.data()).thenReturn(contact);
        return mockDoc;
      }).toList());
      
      when(mockHttpClient.post(
        any(that: isA<Uri>()),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('{"status": "sent"}', 200));
      
      // Act
      final success = await smsService.sendAbnormalHeartRateAlert(
        userId: userId,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      // Assert
      expect(success, isTrue);
      
      // Verify SMS was sent to each contact
      verify(mockHttpClient.post(
        any(that: isA<Uri>()),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).called(2);
      
      // Verify success was logged
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('SMS alerts sent successfully')),
      )).called(1);
    });
    
    /// Test handling of SMS sending failure
    /// Verifies that the service handles SMS failures gracefully
    test('Should handle SMS sending failure', () async {
      // Arrange
      final userId = 'test-user-id';
      final heartRate = 120.0;
      final abnormalityType = 'high_heart_rate';
      
      final mockContacts = [
        {'name': 'Contact 1', 'phone': '+1234567890'},
      ];
      
      when(mockQuerySnapshot.docs).thenReturn(mockContacts.map((contact) {
        final mockDoc = MockQueryDocumentSnapshot();
        when(mockDoc.data()).thenReturn(contact);
        return mockDoc;
      }).toList());
      
      when(mockHttpClient.post(
        any(that: isA<Uri>()),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenThrow(Exception('Failed to send SMS'));
      
      // Act
      final success = await smsService.sendAbnormalHeartRateAlert(
        userId: userId,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      // Assert
      expect(success, isFalse);
      
      // Verify error was logged
      verify(mockLogger.e(
        any(that: isA<String>()),
        any(that: contains('Failed to send SMS alert')),
        any(that: isA<Exception>()),
      )).called(1);
    });
  });
  
  /// Test group for complete integration scenarios
  /// Tests the entire SMS alert workflow
  group('Integration Tests', () {
    /// Test the complete SMS alert flow
    /// Verifies end-to-end functionality from contact retrieval to SMS sending
    test('Complete SMS alert flow', () async {
      // Arrange
      final userId = 'test-user-id';
      final heartRate = 120.0;
      final abnormalityType = 'high_heart_rate';
      
      final mockContacts = [
        {'name': 'Contact 1', 'phone': '+1234567890'},
        {'name': 'Contact 2', 'phone': '+0987654321'},
      ];
      
      when(mockQuerySnapshot.docs).thenReturn(mockContacts.map((contact) {
        final mockDoc = MockQueryDocumentSnapshot();
        when(mockDoc.data()).thenReturn(contact);
        return mockDoc;
      }).toList());
      
      when(mockHttpClient.post(
        any(that: isA<Uri>()),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('{"status": "sent"}', 200));
      
      // Act
      final success = await smsService.sendAbnormalHeartRateAlert(
        userId: userId,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      // Assert
      expect(success, isTrue);
      
      // Verify contacts were retrieved
      verify(mockFirestore.collection('emergencyContacts')).called(1);
      verify(mockEmergencyContactsCollection.where('userId', isEqualTo: userId)).called(1);
      
      // Verify SMS was sent to each contact
      verify(mockHttpClient.post(
        any(that: isA<Uri>()),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).called(2);
      
      // Verify success was logged
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('SMS alerts sent successfully')),
      )).called(1);
    });
  });
} 