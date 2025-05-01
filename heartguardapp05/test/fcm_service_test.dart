import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:heartguardapp05/services/fcm_service.dart';
import 'package:heartguardapp05/services/logger_service.dart';
import 'package:heartguardapp05/services/notification_settings.dart';

import 'fcm_service_test.mocks.dart';

/// This test file contains comprehensive tests for the Firebase Cloud Messaging (FCM) service.
/// It tests the functionality of sending push notifications for abnormal heart rate conditions.
/// The tests cover token management, notification sending, and error handling.

// Generate mocks for all external dependencies
@GenerateMocks([
  FirebaseMessaging,
  Logger,
  NotificationSettings,
])
void main() {
  // Declare mock objects that will be used across multiple tests
  late MockFirebaseMessaging mockMessaging;
  late MockLogger mockLogger;
  late MockNotificationSettings mockSettings;
  late FCMService fcmService;
  
  /// Setup function that runs before each test
  /// Initializes all mock objects and configures their default behavior
  setUp(() {
    // Initialize mock objects
    mockMessaging = MockFirebaseMessaging();
    mockLogger = MockLogger();
    mockSettings = MockNotificationSettings();
    
    // Configure default mock behavior
    when(mockMessaging.requestPermission()).thenAnswer((_) async => true);
    when(mockMessaging.getToken()).thenAnswer((_) async => 'test-fcm-token');
    when(mockMessaging.setForegroundNotificationPresentationOptions(
      alert: anyNamed('alert'),
      badge: anyNamed('badge'),
      sound: anyNamed('sound'),
    )).thenAnswer((_) async => null);
    
    // Initialize the FCM service with mock dependencies
    fcmService = FCMService(
      messaging: mockMessaging,
      logger: mockLogger,
      settings: mockSettings,
    );
  });
  
  /// Test group for FCM service initialization
  /// Tests the setup and configuration of the FCM service
  group('FCM Service Initialization', () {
    /// Test successful initialization of FCM service
    /// Verifies that all required permissions are requested and settings are configured
    test('Should initialize FCM service successfully', () async {
      // Act
      await fcmService.initialize();
      
      // Assert
      // Verify permissions were requested
      verify(mockMessaging.requestPermission()).called(1);
      
      // Verify notification settings were configured
      verify(mockMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      )).called(1);
      
      // Verify token was retrieved
      verify(mockMessaging.getToken()).called(1);
      
      // Verify initialization was logged
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('FCM service initialized')),
      )).called(1);
    });
    
    /// Test handling of permission denial
    /// Verifies that the service handles permission denial gracefully
    test('Should handle permission denial', () async {
      // Arrange
      when(mockMessaging.requestPermission()).thenAnswer((_) async => false);
      
      // Act
      await fcmService.initialize();
      
      // Assert
      // Verify permissions were requested
      verify(mockMessaging.requestPermission()).called(1);
      
      // Verify error was logged
      verify(mockLogger.e(
        any(that: isA<String>()),
        any(that: contains('Failed to get FCM permissions')),
        any(that: isA<Exception>()),
      )).called(1);
    });
  });
  
  /// Test group for token management
  /// Tests the functionality of getting and refreshing FCM tokens
  group('Token Management', () {
    /// Test successful token retrieval
    /// Verifies that the service can get the FCM token
    test('Should get FCM token successfully', () async {
      // Act
      final token = await fcmService.getToken();
      
      // Assert
      expect(token, equals('test-fcm-token'));
      verify(mockMessaging.getToken()).called(1);
    });
    
    /// Test token refresh
    /// Verifies that the service can refresh the FCM token
    test('Should refresh FCM token', () async {
      // Arrange
      when(mockMessaging.getToken()).thenAnswer((_) async => 'new-fcm-token');
      
      // Act
      final token = await fcmService.refreshToken();
      
      // Assert
      expect(token, equals('new-fcm-token'));
      verify(mockMessaging.getToken()).called(1);
    });
  });
  
  /// Test group for notification sending
  /// Tests the functionality of sending different types of notifications
  group('Notification Sending', () {
    /// Test sending abnormal heart rate notification
    /// Verifies that notifications are properly formatted and sent
    test('Should send abnormal heart rate notification', () async {
      // Arrange
      final deviceToken = 'test-device-token';
      final heartRate = 120.0;
      final abnormalityType = 'high_heart_rate';
      
      // Act
      final success = await fcmService.sendAbnormalHeartRateNotification(
        deviceToken: deviceToken,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      // Assert
      expect(success, isTrue);
      
      // Verify notification was sent with correct data
      verify(mockMessaging.sendMessage(
        to: deviceToken,
        data: argThat(
          isA<Map<String, String>>().having((data) => 
            data['type'] == 'abnormal_heart_rate' &&
            data['heartRate'] == heartRate.toString() &&
            data['abnormalityType'] == abnormalityType,
            'notification data',
            true
          )
        ),
      )).called(1);
      
      // Verify success was logged
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('FCM notification sent successfully')),
      )).called(1);
    });
    
    /// Test handling of notification sending failure
    /// Verifies that the service handles notification failures gracefully
    test('Should handle notification sending failure', () async {
      // Arrange
      final deviceToken = 'test-device-token';
      final heartRate = 120.0;
      final abnormalityType = 'high_heart_rate';
      
      when(mockMessaging.sendMessage(
        to: anyNamed('to'),
        data: anyNamed('data'),
      )).thenThrow(Exception('Failed to send notification'));
      
      // Act
      final success = await fcmService.sendAbnormalHeartRateNotification(
        deviceToken: deviceToken,
        heartRate: heartRate,
        abnormalityType: abnormalityType,
      );
      
      // Assert
      expect(success, isFalse);
      
      // Verify error was logged
      verify(mockLogger.e(
        any(that: isA<String>()),
        any(that: contains('Failed to send FCM notification')),
        any(that: isA<Exception>()),
      )).called(1);
    });
  });
  
  /// Test group for notification settings
  /// Tests the functionality of managing notification preferences
  group('Notification Settings', () {
    /// Test updating notification settings
    /// Verifies that notification preferences are properly saved
    test('Should update notification settings', () async {
      // Arrange
      final settings = {
        'enableNotifications': true,
        'enableSound': true,
        'enableVibration': true,
      };
      
      // Act
      await fcmService.updateNotificationSettings(settings);
      
      // Assert
      // Verify settings were saved
      verify(mockSettings.saveSettings(settings)).called(1);
      
      // Verify success was logged
      verify(mockLogger.i(
        any(that: isA<String>()),
        any(that: contains('Notification settings updated')),
      )).called(1);
    });
    
    /// Test getting notification settings
    /// Verifies that notification preferences are properly retrieved
    test('Should get notification settings', () async {
      // Arrange
      final expectedSettings = {
        'enableNotifications': true,
        'enableSound': true,
        'enableVibration': true,
      };
      
      when(mockSettings.getSettings()).thenAnswer((_) async => expectedSettings);
      
      // Act
      final settings = await fcmService.getNotificationSettings();
      
      // Assert
      expect(settings, equals(expectedSettings));
      verify(mockSettings.getSettings()).called(1);
    });
  });
} 