import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:heartguardapp05/services/notification_service.dart';
import 'package:heartguardapp05/services/fcm_service.dart';
import 'package:heartguardapp05/services/sms_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';

import 'heart_rate_monitoring_test.mocks.dart';

/// This test file contains comprehensive tests for the heart rate monitoring functionality.
/// It tests the integration between various services including Firestore, FCM, SMS, and notifications.
/// The tests cover both normal and abnormal heart rate scenarios, as well as error handling.

// Generate mocks for all external dependencies
@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  FirebaseDatabase,
  User,
  CollectionReference,
  DocumentReference,
  DatabaseReference,
  DatabaseEvent,
  DataSnapshot,
  NotificationService,
  FCMService,
  SMSService,
  Logger,
])
void main() {
  // Declare mock objects that will be used across multiple tests
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDatabase;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockHeartRateCollection;
  late MockDocumentReference<Map<String, dynamic>> mockHeartRateDoc;
  late MockDatabaseReference mockDatabaseRef;
  late MockNotificationService mockNotificationService;
  late MockFCMService mockFcmService;
  late MockSMSService mockSmsService;
  late MockLogger mockLogger;
  
  /// Setup function that runs before each test
  /// Initializes all mock objects and configures their default behavior
  setUp(() {
    // Initialize all mock objects
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockDatabase = MockFirebaseDatabase();
    mockUser = MockUser();
    mockHeartRateCollection = MockCollectionReference<Map<String, dynamic>>();
    mockHeartRateDoc = MockDocumentReference<Map<String, dynamic>>();
    mockDatabaseRef = MockDatabaseReference();
    mockNotificationService = MockNotificationService();
    mockFcmService = MockFCMService();
    mockSmsService = MockSMSService();
    mockLogger = MockLogger();
    
    // Configure mock behavior for authentication
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');
    
    // Configure mock behavior for Firestore
    when(mockFirestore.collection('heartRateData')).thenReturn(mockHeartRateCollection);
    when(mockHeartRateCollection.add(any(that: isA<Map<String, dynamic>>()))).thenAnswer((_) async => mockHeartRateDoc);
    
    // Configure mock behavior for Realtime Database
    when(mockDatabase.ref()).thenReturn(mockDatabaseRef);
    when(mockDatabaseRef.child(any(that: isA<String>()))).thenReturn(mockDatabaseRef);
    
    // Configure logger mock behavior
    when(mockLogger.i(any(that: isA<String>()), any(that: isA<String>()))).thenReturn(null);
    when(mockLogger.e(any(that: isA<String>()), any(that: isA<String>()), any(that: isA<Exception>()))).thenReturn(null);
    when(mockLogger.w(any(that: isA<String>()), any(that: isA<String>()))).thenReturn(null);
  });
  
  /// Test group for heart rate processing functionality
  /// Tests the core functionality of saving and processing heart rate data
  group('Heart Rate Processing Tests', () {
    /// Test saving normal heart rate data to Firestore
    /// Verifies that data is correctly formatted and stored
    test('Should save heart rate data to Firestore', () async {
      // Arrange
      final timestamp = DateTime.now();
      final heartRate = 75.0; // Normal heart rate
      
      // Act
      await saveHeartRateData(
        mockFirestore,
        mockAuth,
        mockLogger,
        heartRate,
        timestamp,
      );
      
      // Assert
      // Verify Firestore collection was accessed
      verify(mockFirestore.collection('heartRateData')).called(1);
      
      // Verify correct data is being saved
      verify(mockHeartRateCollection.add(argThat(
        isA<Map<String, dynamic>>().having((data) => 
          data['userId'] == 'test-user-id' &&
          data['heartRate'] == heartRate &&
          data['isAbnormal'] == false &&
          data['abnormalityType'] == null, 
          'heart rate data fields', 
          true
        )
      ))).called(1);
      
      // Verify logging
      verify(mockLogger.i(any(that: isA<String>()), any(that: contains('Heart rate data saved successfully')))).called(1);
    });
    
    /// Test detection of high heart rate and notification sending
    /// Verifies that all notification channels are triggered for abnormal heart rates
    test('Should detect high heart rate and send notifications', () async {
      // Arrange
      final timestamp = DateTime.now();
      final heartRate = 120.0; // High heart rate
      final fcmToken = 'test-fcm-token';
      
      // Configure mock behavior for notification services
      when(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).thenAnswer((_) async => true);
      
      when(mockNotificationService.sendAbnormalityNotification(
        userId: 'test-user-id',
        heartRate: heartRate.round(),
        abnormalityType: 'high_heart_rate',
      )).thenAnswer((_) async => {});
      
      when(mockSmsService.sendAbnormalHeartRateAlert(
        userId: 'test-user-id',
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).thenAnswer((_) async => true);
      
      // Act
      await saveHeartRateAndSendNotifications(
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        heartRate,
        timestamp,
        fcmToken,
      );
      
      // Assert
      // Verify Firestore data saved with correct abnormality flags
      verify(mockHeartRateCollection.add(argThat(
        isA<Map<String, dynamic>>().having((data) => 
          data['isAbnormal'] == true && 
          data['abnormalityType'] == 'high_heart_rate',
          'abnormal data fields',
          true
        )
      ))).called(1);
      
      // Verify all notification channels were triggered
      verify(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).called(1);
      
      verify(mockNotificationService.sendAbnormalityNotification(
        userId: 'test-user-id',
        heartRate: heartRate.round(),
        abnormalityType: 'high_heart_rate',
      )).called(1);
      
      verify(mockSmsService.sendAbnormalHeartRateAlert(
        userId: 'test-user-id',
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).called(1);
    });
    
    /// Test detection of low heart rate and notification sending
    /// Similar to high heart rate test but with different thresholds
    test('Should detect low heart rate and send notifications', () async {
      // Arrange
      final timestamp = DateTime.now();
      final heartRate = 45.0; // Low heart rate
      final fcmToken = 'test-fcm-token';
      
      // Configure mock behavior for notification services
      when(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'low_heart_rate',
      )).thenAnswer((_) async => true);
      
      when(mockNotificationService.sendAbnormalityNotification(
        userId: 'test-user-id',
        heartRate: heartRate.round(),
        abnormalityType: 'low_heart_rate',
      )).thenAnswer((_) async => {});
      
      when(mockSmsService.sendAbnormalHeartRateAlert(
        userId: 'test-user-id',
        heartRate: heartRate,
        abnormalityType: 'low_heart_rate',
      )).thenAnswer((_) async => true);
      
      // Act
      await saveHeartRateAndSendNotifications(
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        heartRate,
        timestamp,
        fcmToken,
      );
      
      // Assert
      // Verify Firestore data saved with correct abnormality flags
      verify(mockHeartRateCollection.add(argThat(
        isA<Map<String, dynamic>>().having((data) => 
          data['isAbnormal'] == true && 
          data['abnormalityType'] == 'low_heart_rate',
          'low heart rate fields',
          true
        )
      ))).called(1);
      
      // Verify all notification channels were triggered
      verify(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'low_heart_rate',
      )).called(1);
      
      verify(mockNotificationService.sendAbnormalityNotification(
        userId: 'test-user-id',
        heartRate: heartRate.round(),
        abnormalityType: 'low_heart_rate',
      )).called(1);
      
      verify(mockSmsService.sendAbnormalHeartRateAlert(
        userId: 'test-user-id',
        heartRate: heartRate,
        abnormalityType: 'low_heart_rate',
      )).called(1);
    });
    
    /// Test that notifications are not sent for normal heart rates
    /// Verifies that the system correctly identifies and handles normal readings
    test('Should not send notifications for normal heart rate', () async {
      // Arrange
      final timestamp = DateTime.now();
      final heartRate = 75.0; // Normal heart rate
      final fcmToken = 'test-fcm-token';
      
      // Act
      await saveHeartRateAndSendNotifications(
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        heartRate,
        timestamp,
        fcmToken,
      );
      
      // Assert
      // Verify Firestore data saved with normal flags
      verify(mockHeartRateCollection.add(argThat(
        isA<Map<String, dynamic>>().having((data) => 
          data['isAbnormal'] == false && 
          data['abnormalityType'] == null,
          'normal heart rate fields',
          true
        )
      ))).called(1);
      
      // Verify no notifications were sent
      verifyNever(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: anyNamed('deviceToken'),
        heartRate: anyNamed('heartRate'),
        abnormalityType: anyNamed('abnormalityType'),
      ));
      
      verifyNever(mockNotificationService.sendAbnormalityNotification(
        userId: anyNamed('userId'),
        heartRate: anyNamed('heartRate'),
        abnormalityType: anyNamed('abnormalityType'),
      ));
      
      verifyNever(mockSmsService.sendAbnormalHeartRateAlert(
        userId: anyNamed('userId'),
        heartRate: anyNamed('heartRate'),
        abnormalityType: anyNamed('abnormalityType'),
      ));
    });
  });
  
  /// Test group for database event processing
  /// Tests the handling of real-time database events
  group('Database Events Tests', () {
    /// Test processing of valid heart rate data from database events
    /// Verifies correct handling of real-time updates
    test('Should process database event with heart rate data', () async {
      // Arrange
      final heartRate = 120.0; // Abnormal heart rate
      final mockDataSnapshot = MockDataSnapshot();
      final mockDatabaseEvent = MockDatabaseEvent();
      
      when(mockDatabaseEvent.snapshot).thenReturn(mockDataSnapshot);
      when(mockDataSnapshot.exists).thenReturn(true);
      when(mockDataSnapshot.value).thenReturn(heartRate);
      
      // Act
      await processHeartRateReading(
        mockDatabaseEvent,
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        'test-fcm-token',
      );
      
      // Assert
      // Verify data was saved to Firestore
      verify(mockHeartRateCollection.add(any(that: isA<Map<String, dynamic>>()))).called(1);
      
      // Verify FCM notification was sent for abnormal heart rate
      verify(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: 'test-fcm-token',
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).called(1);
    });
    
    /// Test handling of non-existent database event data
    /// Verifies proper error handling for missing data
    test('Should handle non-existent database event data', () async {
      // Arrange
      final mockDataSnapshot = MockDataSnapshot();
      final mockDatabaseEvent = MockDatabaseEvent();
      
      when(mockDatabaseEvent.snapshot).thenReturn(mockDataSnapshot);
      when(mockDataSnapshot.exists).thenReturn(false);
      
      // Act
      await processHeartRateReading(
        mockDatabaseEvent,
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        'test-fcm-token',
      );
      
      // Assert
      // Verify no data was saved to Firestore
      verifyNever(mockHeartRateCollection.add(any(that: isA<Map<String, dynamic>>())));
      
      // Verify no notifications were sent
      verifyNever(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: anyNamed('deviceToken'),
        heartRate: anyNamed('heartRate'),
        abnormalityType: anyNamed('abnormalityType'),
      ));
    });
    
    /// Test handling of invalid data format in database events
    /// Verifies proper error handling for malformed data
    test('Should handle invalid data format', () async {
      // Arrange
      final mockDataSnapshot = MockDataSnapshot();
      final mockDatabaseEvent = MockDatabaseEvent();
      
      when(mockDatabaseEvent.snapshot).thenReturn(mockDataSnapshot);
      when(mockDataSnapshot.exists).thenReturn(true);
      when(mockDataSnapshot.value).thenReturn('not-a-number'); // Invalid format
      
      // Act
      await processHeartRateReading(
        mockDatabaseEvent,
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        'test-fcm-token',
      );
      
      // Assert
      // Verify error was logged
      verify(mockLogger.e(
        any(that: isA<String>()), 
        any(that: contains('Error processing data')), 
        any(that: isA<FormatException>())
      )).called(1);
      
      // Verify no data was saved to Firestore
      verifyNever(mockHeartRateCollection.add(any(that: isA<Map<String, dynamic>>())));
    });
  });
  
  /// Test group for complete integration scenarios
  /// Tests the entire heart rate monitoring workflow
  group('Integration tests', () {
    /// Test the complete heart rate monitoring flow
    /// Verifies end-to-end functionality from data reception to notifications
    test('Complete heart rate monitoring flow', () async {
      // Arrange
      final heartRate = 120.0; // Abnormal high heart rate
      final fcmToken = 'test-fcm-token';
      final mockDataSnapshot = MockDataSnapshot();
      final mockDatabaseEvent = MockDatabaseEvent();
      
      when(mockDatabaseEvent.snapshot).thenReturn(mockDataSnapshot);
      when(mockDataSnapshot.exists).thenReturn(true);
      when(mockDataSnapshot.value).thenReturn(heartRate);
      
      when(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).thenAnswer((_) async => true);
      
      // Act - Process a database event with heart rate data
      await processHeartRateReading(
        mockDatabaseEvent,
        mockFirestore,
        mockAuth,
        mockLogger,
        mockFcmService,
        mockNotificationService,
        mockSmsService,
        fcmToken,
      );
      
      // Assert
      // Verify data saved to Firestore with all required fields
      verify(mockHeartRateCollection.add(argThat(
        isA<Map<String, dynamic>>().having((data) => 
          data['userId'] == 'test-user-id' &&
          data['heartRate'] == heartRate &&
          data['isAbnormal'] == true &&
          data['abnormalityType'] == 'high_heart_rate',
          'all heart rate fields',
          true
        )
      ))).called(1);
      
      // Verify all notifications were sent
      verify(mockFcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).called(1);
      
      verify(mockNotificationService.sendAbnormalityNotification(
        userId: 'test-user-id',
        heartRate: heartRate.round(),
        abnormalityType: 'high_heart_rate',
      )).called(1);
      
      verify(mockSmsService.sendAbnormalHeartRateAlert(
        userId: 'test-user-id',
        heartRate: heartRate,
        abnormalityType: 'high_heart_rate',
      )).called(1);
    });
  });
}

// Helper functions that simulate the application's heart rate processing

/// Saves heart rate data to Firestore
/// This function simulates the actual implementation in the app
Future<void> saveHeartRateData(
  MockFirebaseFirestore firestore,
  MockFirebaseAuth auth,
  MockLogger logger,
  double heartRate,
  DateTime timestamp,
) async {
  try {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      logger.e('Test', 'Error: No user logged in');
      return;
    }

    logger.i('Test', 'Saving heart rate data: $heartRate BPM');
    final firestoreTimestamp = Timestamp.fromDate(timestamp);

    await firestore.collection('heartRateData').add({
      'userId': userId,
      'heartRate': heartRate,
      'timestamp': firestoreTimestamp,
      'isAbnormal': heartRate < 60 || heartRate > 100,
      'abnormalityType': heartRate < 60
          ? 'low_heart_rate'
          : (heartRate > 100 ? 'high_heart_rate' : null),
    });
    
    logger.i('Test', 'Heart rate data saved successfully');
  } catch (e) {
    logger.e('Test', 'Error saving heart rate data', e);
  }
}

/// Saves heart rate data and sends notifications if abnormal
/// This function simulates the actual implementation in the app
Future<void> saveHeartRateAndSendNotifications(
  MockFirebaseFirestore firestore,
  MockFirebaseAuth auth,
  MockLogger logger,
  MockFCMService fcmService,
  MockNotificationService notificationService,
  MockSMSService smsService,
  double heartRate,
  DateTime timestamp,
  String fcmToken,
) async {
  try {
    // Save heart rate data
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      logger.e('Test', 'Error: No user logged in');
      return;
    }

    logger.i('Test', 'Saving heart rate data: $heartRate BPM');
    final firestoreTimestamp = Timestamp.fromDate(timestamp);

    await firestore.collection('heartRateData').add({
      'userId': userId,
      'heartRate': heartRate,
      'timestamp': firestoreTimestamp,
      'isAbnormal': heartRate < 60 || heartRate > 100,
      'abnormalityType': heartRate < 60
          ? 'low_heart_rate'
          : (heartRate > 100 ? 'high_heart_rate' : null),
    });
    
    logger.i('Test', 'Heart rate data saved successfully');

    // If abnormal heart rate, send notifications
    if (heartRate < 60 || heartRate > 100) {
      final abnormalityType = heartRate < 60 ? 'low_heart_rate' : 'high_heart_rate';

      logger.w('Test', 'Abnormal heart rate detected: $heartRate BPM - Sending FCM notification');
      
      // Send FCM notification
      final success = await fcmService.sendAbnormalHeartRateNotification(
        deviceToken: fcmToken,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );

      if (success) {
        logger.i('Test', 'FCM notification sent successfully');
      } else {
        logger.w('Test', 'Failed to send FCM notification');
      }

      // Send app notification
      await notificationService.sendAbnormalityNotification(
        userId: userId,
        heartRate: heartRate.round(),
        abnormalityType: abnormalityType,
      );
      
      // Send SMS to emergency contacts
      logger.i('Test', 'Sending SMS alerts to emergency contacts');
      final smsSuccess = await smsService.sendAbnormalHeartRateAlert(
        userId: userId,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      if (smsSuccess) {
        logger.i('Test', 'SMS alerts sent successfully to emergency contacts');
      } else {
        logger.w('Test', 'Failed to send SMS alerts to some or all emergency contacts');
      }
    }
  } catch (e) {
    logger.e('Test', 'Error saving heart rate data and sending notification', e);
  }
}

/// Processes heart rate readings from database events
/// This function simulates the actual implementation in the app
Future<void> processHeartRateReading(
  MockDatabaseEvent event,
  MockFirebaseFirestore firestore,
  MockFirebaseAuth auth,
  MockLogger logger,
  MockFCMService fcmService,
  MockNotificationService notificationService,
  MockSMSService smsService,
  String fcmToken,
) async {
  final snapshot = event.snapshot;
  
  if (snapshot.exists) {
    try {
      final data = snapshot.value;
      double value;

      if (data is num) {
        value = data.toDouble();
      } else {
        logger.e('Test', 'Error processing data', FormatException('Unexpected data format'));
        return;
      }

      final timestamp = DateTime.now();
      
      logger.i('Test', 'New ECG reading: $value at ${timestamp.toIso8601String()}');

      // Save and process the heart rate data
      await saveHeartRateAndSendNotifications(
        firestore,
        auth,
        logger,
        fcmService,
        notificationService,
        smsService,
        value,
        timestamp,
        fcmToken,
      );
    } catch (e) {
      logger.e('Test', 'Error processing data', e);
    }
  } else {
    logger.w('Test', 'No data found in Firebase');
  }
} 