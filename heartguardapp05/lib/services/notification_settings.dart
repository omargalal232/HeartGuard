import 'package:shared_preferences/shared_preferences.dart';
import 'package:heartguardapp05/services/logger_service.dart';

/// Service for managing notification settings in the HeartGuard app.
/// Handles saving, retrieving, and updating user notification preferences.
class NotificationSettings {
  final SharedPreferences _prefs;
  final Logger _logger;
  
  /// Default values for notification settings
  static const Map<String, bool> _defaultSettings = {
    'enableNotifications': true,
    'enableSound': true,
    'enableVibration': true,
  };
  
  /// Valid notification setting keys
  static const List<String> _validKeys = [
    'enableNotifications',
    'enableSound',
    'enableVibration',
  ];
  
  /// Creates a new instance of NotificationSettings.
  /// 
  /// [prefs] - SharedPreferences instance for storing settings
  /// [logger] - Logger instance for logging operations
  NotificationSettings({
    required SharedPreferences prefs,
    required Logger logger,
  }) : _prefs = prefs,
       _logger = logger;
  
  /// Saves notification settings to SharedPreferences.
  /// 
  /// [settings] - Map of setting keys and their boolean values
  /// Returns true if settings were saved successfully, false otherwise
  Future<bool> saveSettings(Map<String, bool> settings) async {
    try {
      for (final entry in settings.entries) {
        if (!_validKeys.contains(entry.key)) {
          _logger.e('NotificationSettings', 'Invalid setting key: ${entry.key}');
          return false;
        }
        
        await _prefs.setBool(entry.key, entry.value);
      }
      
      _logger.i('NotificationSettings', 'Notification settings saved');
      return true;
    } catch (e) {
      _logger.e('NotificationSettings', 'Failed to save notification settings', e);
      return false;
    }
  }
  
  /// Retrieves all notification settings from SharedPreferences.
  /// Returns a map of setting keys and their values.
  /// If a setting is not found, the default value is used.
  Future<Map<String, bool>> getSettings() async {
    final settings = <String, bool>{};
    
    for (final key in _validKeys) {
      final value = _prefs.getBool(key);
      if (value == null) {
        _logger.w('NotificationSettings', 'Using default value for setting: $key');
        settings[key] = _defaultSettings[key]!;
      } else {
        settings[key] = value;
      }
    }
    
    return settings;
  }
  
  /// Enables a specific notification setting.
  /// 
  /// [key] - The setting key to enable
  /// Returns true if the setting was enabled successfully, false otherwise
  Future<bool> enableSetting(String key) async {
    if (!_validKeys.contains(key)) {
      _logger.e('NotificationSettings', 'Invalid notification setting key: $key');
      return false;
    }
    
    try {
      await _prefs.setBool(key, true);
      _logger.i('NotificationSettings', 'Notification setting enabled: $key');
      return true;
    } catch (e) {
      _logger.e('NotificationSettings', 'Failed to enable setting: $key', e);
      return false;
    }
  }
  
  /// Disables a specific notification setting.
  /// 
  /// [key] - The setting key to disable
  /// Returns true if the setting was disabled successfully, false otherwise
  Future<bool> disableSetting(String key) async {
    if (!_validKeys.contains(key)) {
      _logger.e('NotificationSettings', 'Invalid notification setting key: $key');
      return false;
    }
    
    try {
      await _prefs.setBool(key, false);
      _logger.i('NotificationSettings', 'Notification setting disabled: $key');
      return true;
    } catch (e) {
      _logger.e('NotificationSettings', 'Failed to disable setting: $key', e);
      return false;
    }
  }
  
  /// Checks if a specific notification setting is enabled.
  /// 
  /// [key] - The setting key to check
  /// Returns true if the setting is enabled, false otherwise
  Future<bool> isSettingEnabled(String key) async {
    if (!_validKeys.contains(key)) {
      _logger.e('NotificationSettings', 'Invalid notification setting key: $key');
      return false;
    }
    
    final value = _prefs.getBool(key);
    return value ?? _defaultSettings[key]!;
  }
} 