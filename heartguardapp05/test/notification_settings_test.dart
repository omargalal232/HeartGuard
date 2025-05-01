import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heartguardapp05/services/notification_settings.dart';
import 'package:heartguardapp05/services/logger_service.dart';
import 'notification_settings_test.mocks.dart';

/// This test file contains comprehensive tests for the notification settings service.
/// It tests the functionality of managing user notification preferences.
/// The tests cover saving, retrieving, and updating notification settings.

@GenerateMocks([SharedPreferences, Logger])
void main() {
  late MockSharedPreferences mockPrefs;
  late MockLogger mockLogger;
  late NotificationSettings notificationSettings;

  /// Setup function that runs before each test
  /// Initializes mock objects and the NotificationSettings instance
  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockLogger = MockLogger();
    notificationSettings = NotificationSettings(
      prefs: mockPrefs,
      logger: mockLogger,
    );
  });

  group('Notification Settings Management', () {
    test('should save valid notification settings successfully', () async {
      // Arrange
      final settings = {
        'enableNotifications': true,
        'enableSound': true,
        'enableVibration': true,
      };
      
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

      // Act
      final result = await notificationSettings.saveSettings(settings);

      // Assert
      expect(result, true);
      verify(mockPrefs.setBool('enableNotifications', true)).called(1);
      verify(mockPrefs.setBool('enableSound', true)).called(1);
      verify(mockPrefs.setBool('enableVibration', true)).called(1);
      verify(mockLogger.i('NotificationSettings', 'Notification settings saved')).called(1);
    });

    test('should reject invalid notification settings', () async {
      // Arrange
      final settings = {
        'invalidSetting': true,
      };

      // Act
      final result = await notificationSettings.saveSettings(settings);

      // Assert
      expect(result, false);
      verify(mockLogger.e('NotificationSettings', 'Invalid setting key: invalidSetting')).called(1);
      verifyNever(mockPrefs.setBool(any, any));
    });

    test('should retrieve all notification settings with defaults', () async {
      // Arrange
      when(mockPrefs.getBool('enableNotifications')).thenReturn(true);
      when(mockPrefs.getBool('enableSound')).thenReturn(null);
      when(mockPrefs.getBool('enableVibration')).thenReturn(false);

      // Act
      final settings = await notificationSettings.getSettings();

      // Assert
      expect(settings['enableNotifications'], true);
      expect(settings['enableSound'], true); // Default value
      expect(settings['enableVibration'], false);
      verify(mockLogger.w('NotificationSettings', 'Using default value for setting: enableSound')).called(1);
    });
  });

  group('Individual Setting Management', () {
    test('should enable a valid notification setting', () async {
      // Arrange
      when(mockPrefs.setBool('enableNotifications', true)).thenAnswer((_) async => true);

      // Act
      final result = await notificationSettings.enableSetting('enableNotifications');

      // Assert
      expect(result, true);
      verify(mockPrefs.setBool('enableNotifications', true)).called(1);
      verify(mockLogger.i('NotificationSettings', 'Notification setting enabled: enableNotifications')).called(1);
    });

    test('should disable a valid notification setting', () async {
      // Arrange
      when(mockPrefs.setBool('enableNotifications', false)).thenAnswer((_) async => true);

      // Act
      final result = await notificationSettings.disableSetting('enableNotifications');

      // Assert
      expect(result, true);
      verify(mockPrefs.setBool('enableNotifications', false)).called(1);
      verify(mockLogger.i('NotificationSettings', 'Notification setting disabled: enableNotifications')).called(1);
    });

    test('should reject invalid setting key', () async {
      // Act
      final result = await notificationSettings.enableSetting('invalidSetting');

      // Assert
      expect(result, false);
      verify(mockLogger.e('NotificationSettings', 'Invalid notification setting key: invalidSetting')).called(1);
      verifyNever(mockPrefs.setBool(any, any));
    });
  });

  group('Setting Status Check', () {
    test('should return true for enabled setting', () async {
      // Arrange
      when(mockPrefs.getBool('enableNotifications')).thenReturn(true);

      // Act
      final result = await notificationSettings.isSettingEnabled('enableNotifications');

      // Assert
      expect(result, true);
    });

    test('should return false for disabled setting', () async {
      // Arrange
      when(mockPrefs.getBool('enableNotifications')).thenReturn(false);

      // Act
      final result = await notificationSettings.isSettingEnabled('enableNotifications');

      // Assert
      expect(result, false);
    });

    test('should return default value for unset setting', () async {
      // Arrange
      when(mockPrefs.getBool('enableNotifications')).thenReturn(null);

      // Act
      final result = await notificationSettings.isSettingEnabled('enableNotifications');

      // Assert
      expect(result, true); // Default value
    });
  });
} 