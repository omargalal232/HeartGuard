import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:jose/jose.dart';
import 'logger_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final Logger _logger = Logger();
  static const String _tag = 'NotificationService';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Map<String, dynamic>? _credentials;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Add topic constants
  static const String topicHeartAlerts = 'heart_guard_alerts';
  static const String topicHighHeartRate = 'high_heart_rate';
  static const String topicLowHeartRate = 'low_heart_rate';
  static const String topicGeneral = 'general_updates';

  Future<void> init() async {
    try {
      // Create the Android notification channel
      const androidChannel = AndroidNotificationChannel(
        'heart_guard_channel',
        'Heart Guard Notifications',
        description: 'Notifications for heart abnormalities and campaigns',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
      );

      // Create the channel on the device
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Initialize local notifications
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _logger.i(_tag, 'Notification clicked: ${details.payload}');
          _handleNotificationClick(details.payload);
        },
      );

      // Request notification permissions with all options
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
      );
      
      _logger.i(_tag, 'User granted permission: ${settings.authorizationStatus}');

      // Get FCM token
      String? token = await _fcm.getToken();
      _logger.i(_tag, 'FCM Token: $token');

      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _saveTokenToFirestore(user.uid, token);
          await _subscribeToTopics();
        }
      }

      // Set foreground notification presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        _logger.i(_tag, 'FCM Token refreshed: $newToken');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _saveTokenToFirestore(user.uid, newToken);
        }
      });

      // Handle incoming messages when app is in foreground
      FirebaseMessaging.onMessage.listen((message) async {
        _logger.i(_tag, 'Got a message whilst in the foreground!');
        _logger.i(_tag, 'Message data: ${message.data}');
        await _handleForegroundMessage(message);
      });

      // Handle when user taps on notification when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.i(_tag, 'Message opened from background state!');
        _logger.i(_tag, 'Message data: ${message.data}');
        _handleBackgroundMessage(message);
      });
      
      _logger.i(_tag, 'NotificationService initialized successfully');
    } catch (e, stackTrace) {
      _logger.e(_tag, 'Error initializing NotificationService', e, stackTrace);
    }
  }

  Future<void> saveCredentials(String jsonContent) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/firebase_credentials.json');
      
      // Parse and validate the JSON content
      final credentials = json.decode(jsonContent);
      if (!_validateCredentials(credentials)) {
        throw Exception('Invalid credentials format');
      }

      // Save the credentials
      await file.writeAsString(jsonContent);
      _credentials = credentials;
      _logger.i(_tag, 'Credentials saved successfully');
    } catch (e) {
      _logger.e(_tag, 'Error saving credentials', e);
      rethrow;
    }
  }

  bool _validateCredentials(Map<String, dynamic> credentials) {
    final requiredFields = [
      'type',
      'project_id',
      'private_key_id',
      'private_key',
      'client_email',
      'client_id',
    ];
    
    return requiredFields.every((field) => 
      credentials.containsKey(field) && 
      credentials[field] != null &&
      credentials[field].toString().isNotEmpty
    );
  }

  String _generateJWT() {
    if (_credentials == null) {
      throw Exception('Credentials not loaded');
    }

    final now = DateTime.now();
    final expiry = now.add(const Duration(hours: 1));

    final claims = {
      'iss': _credentials!['client_email'],
      'sub': _credentials!['client_email'],
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'scope': 'https://www.googleapis.com/auth/firebase.messaging',
    };

    final privateKey = _credentials!['private_key']
        .replaceAll(r'\n', '\n')
        .replaceAll('-----BEGIN PRIVATE KEY-----\n', '')
        .replaceAll('\n-----END PRIVATE KEY-----', '');

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..setProtectedHeader('alg', 'RS256')
      ..setProtectedHeader('typ', 'JWT')
      ..addRecipient(JsonWebKey.fromJson({
        'kty': 'RSA',
        'k': privateKey,
        'alg': 'RS256'
      }));

    return builder.build().toCompactSerialization();
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tokens')
        .doc('fcm')
        .set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': 'android',
    });
  }

  Future<void> _subscribeToTopics() async {
    try {
      await _fcm.subscribeToTopic(topicHeartAlerts);
      await _fcm.subscribeToTopic(topicHighHeartRate);
      await _fcm.subscribeToTopic(topicLowHeartRate);
      await _fcm.subscribeToTopic(topicGeneral);
      
      _logger.i(_tag, 'Subscribed to all notification topics');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notification_topics': {
            topicHeartAlerts: true,
            topicHighHeartRate: true,
            topicLowHeartRate: true,
            topicGeneral: true,
          },
          'last_topic_update': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.e(_tag, 'Error subscribing to topics', e);
    }
  }

  Future<void> _handleNotificationClick(String? payload) async {
    if (payload == null) return;
    
    try {
      final data = json.decode(payload);
      final notificationId = data['notificationId'];
      final type = data['type'];
      
      // Mark notification as read
      if (notificationId != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore
              .collection('notifications')
              .doc(notificationId)
              .update({'isRead': true});
        }
      }

      // Handle different notification types
      switch (type) {
        case 'high_heart_rate':
        case 'low_heart_rate':
          // Add specific handling for heart rate alerts
          _logger.i(_tag, 'Handling heart rate alert click: $type');
          break;
        case 'campaign':
          // Handle campaign notification clicks
          final campaignId = data['campaignId'];
          if (campaignId != null) {
            await _trackCampaignClick(campaignId);
          }
          break;
        default:
          _logger.i(_tag, 'Unknown notification type: $type');
      }
    } catch (e) {
      _logger.e(_tag, 'Error handling notification click', e);
    }
  }

  Future<void> _trackCampaignClick(String campaignId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('campaign_analytics').add({
          'userId': user.uid,
          'campaignId': campaignId,
          'action': 'click',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.e(_tag, 'Error tracking campaign click', e);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i(_tag, 'Handling foreground message: ${message.messageId}');
    _logger.i(_tag, 'Message data: ${message.data}');

    try {
      // Prepare notification data
      final notificationData = {
        ...message.data,
        'notificationId': message.messageId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

    // Show local notification
      final androidDetails = AndroidNotificationDetails(
      'heart_guard_channel',
      'Heart Guard Notifications',
        channelDescription: 'Notifications for heart abnormalities and campaigns',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          message.notification?.body ?? '',
          htmlFormatBigText: true,
          contentTitle: message.notification?.title,
          htmlFormatContentTitle: true,
          summaryText: message.data['summary'],
          htmlFormatSummaryText: true,
        ),
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);

      // Show the notification
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Heart Guard Alert',
        message.notification?.body ?? '',
      notificationDetails,
        payload: json.encode(notificationData),
    );

      // Save notification to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('notifications').add({
          'userId': user.uid,
          'title': message.notification?.title ?? 'Heart Guard Alert',
          'message': message.notification?.body ?? '',
          'data': notificationData,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'source': message.data['source'] ?? 'campaign',
          'topic': message.data['topic'],
          'campaignId': message.data['campaignId'],
          'heartRate': int.tryParse(message.data['heartRate'] ?? '0'),
          'abnormalityType': message.data['abnormalityType'],
        });
      }
    } catch (e) {
      _logger.e(_tag, 'Error handling foreground message', e);
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i(_tag, 'Handling background message: ${message.messageId}');
    // Background messages are handled by the global handler in main.dart
  }

  Future<void> sendAbnormalityNotification({
    required String userId,
    required int heartRate,
    required String abnormalityType,
  }) async {
    try {
      _logger.i(_tag, 'Sending automatic abnormality notification for user: $userId');
      _logger.i(_tag, 'Heart rate: $heartRate BPM, Type: $abnormalityType');

      // Get user's FCM token
      final tokenDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc('fcm')
          .get();

      if (!tokenDoc.exists) {
        _logger.i(_tag, 'Error: No FCM token found for user: $userId');
        return;
      }

      final token = tokenDoc.data()?['token'] as String?;
      if (token == null) {
        _logger.i(_tag, 'Error: FCM token is null for user: $userId');
        return;
      }

      // Create detailed notification message
      String title = 'Heart Rate Alert';
      String message;
      String severity;
      
      if (abnormalityType == 'low_heart_rate') {
        message = 'Your heart rate is critically low at $heartRate BPM. Please seek medical attention if you feel unwell.';
        severity = 'Low';
      } else if (abnormalityType == 'high_heart_rate') {
        message = 'Your heart rate is critically high at $heartRate BPM. Please seek medical attention if you feel unwell.';
        severity = 'High';
      } else {
        message = 'Abnormal heart rate detected ($heartRate BPM). Please monitor your condition.';
        severity = 'Unknown';
      }

      _logger.i(_tag, 'Saving notification to Firestore...');
      // Save notification with additional metadata
      final notificationRef = await _firestore.collection('notifications').add({
        'userId': userId,
        'heartRate': heartRate,
        'message': message,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'abnormalityType': abnormalityType,
        'severity': severity,
        'source': 'automatic_monitoring',
        'requiresAction': true,
      });
      _logger.i(_tag, 'Notification saved with ID: ${notificationRef.id}');

      // Send FCM notification with enhanced data
      _logger.i(_tag, 'Sending FCM notification...');
      final success = await _sendFCMNotification(
        token: token,
        title: title,
        body: message,
        data: {
          'heartRate': heartRate.toString(),
          'abnormalityType': abnormalityType,
          'userId': userId,
          'notificationId': notificationRef.id,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'severity': severity,
          'source': 'automatic_monitoring',
          'requiresAction': 'true',
        },
      );

      if (success) {
        _logger.i(_tag, 'Automatic abnormality notification sent successfully');
        
        // Update analytics
        await _firestore.collection('campaign_analytics').add({
          'userId': userId,
          'type': 'automatic_notification',
          'abnormalityType': abnormalityType,
          'heartRate': heartRate,
          'timestamp': FieldValue.serverTimestamp(),
          'success': true,
        });
      } else {
        _logger.i(_tag, 'Failed to send automatic abnormality notification');
        
        // Log failure in analytics
        await _firestore.collection('campaign_analytics').add({
          'userId': userId,
          'type': 'automatic_notification',
          'abnormalityType': abnormalityType,
          'heartRate': heartRate,
          'timestamp': FieldValue.serverTimestamp(),
          'success': false,
          'error': 'FCM delivery failed',
        });
      }
    } catch (e, stackTrace) {
      _logger.e(_tag, 'Error sending abnormality notification', e, stackTrace);
      
      // Log error in analytics
      try {
        await _firestore.collection('campaign_analytics').add({
          'userId': userId,
          'type': 'automatic_notification',
          'abnormalityType': abnormalityType,
          'heartRate': heartRate,
          'timestamp': FieldValue.serverTimestamp(),
          'success': false,
          'error': e.toString(),
        });
      } catch (analyticsError) {
        _logger.e(_tag, 'Error logging to analytics', analyticsError);
      }
    }
  }

  Future<bool> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/heart-guard-1c49e/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _fcm.getToken()}',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data,
            'android': {
              'notification': {
                'channel_id': 'heart_guard_channel',
                'default_sound': true,
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_HIGH',
                'visibility': 'PUBLIC',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        _logger.i(_tag, 'FCM notification sent successfully');
        return true;
      } else {
        _logger.i(_tag, 'Failed to send FCM notification. Status: ${response.statusCode}');
        _logger.i(_tag, 'Response: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error sending FCM notification', e);
      return false;
    }
  }

  Future<String?> _getAccessToken() async {
    try {
      if (_credentials == null) {
        _logger.i(_tag, 'Error: No credentials available. Please ensure credentials are loaded.');
        return null;
      }

      if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        _logger.i(_tag, 'Using cached access token (expires in: ${_tokenExpiry!.difference(DateTime.now()).inMinutes} minutes)');
        return _accessToken;
      }

      _logger.i(_tag, 'Generating new access token...');
      final jwt = _generateJWT();
      
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        _logger.i(_tag, 'New access token generated successfully (expires in: ${data['expires_in']} seconds)');
        return _accessToken;
      } else {
        _logger.i(_tag, 'Failed to get access token. Status: ${response.statusCode}');
        _logger.i(_tag, 'Response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e(_tag, 'Error getting access token', e, stackTrace);
      return null;
    }
  }

  Future<bool> verifyCredentials() async {
    try {
      _logger.i(_tag, 'Verifying Firebase credentials...');
      
      if (_credentials == null) {
        _logger.i(_tag, 'Error: No credentials loaded');
        return false;
      }

      // Verify project ID
      if (_credentials!['project_id'] != 'heart-guard-1c49e') {
        _logger.i(_tag, 'Error: Invalid project ID');
        return false;
      }

      // Test JWT generation
      try {
        _logger.i(_tag, 'Testing JWT generation...');
        final jwt = _generateJWT();
        if (jwt.isEmpty) {
          _logger.i(_tag, 'Error: Generated JWT is empty');
          return false;
        }
        _logger.i(_tag, 'JWT generation successful');
      } catch (e) {
        _logger.e(_tag, 'Error generating JWT', e);
        return false;
      }

      // Test access token generation
      _logger.i(_tag, 'Testing access token generation...');
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        _logger.i(_tag, 'Error: Failed to generate access token');
        return false;
      }

      _logger.i(_tag, 'Credentials verified successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.e(_tag, 'Error verifying credentials', e, stackTrace);
      return false;
    }
  }

  Future<bool> sendTestNotification({
    required String fcmToken,
    String title = 'Heart Guard Alert',
    String body = 'Test notification from Heart Guard',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _logger.i(_tag, 'Sending test notification to token: ${fcmToken.substring(0, 10)}...');
      
      if (_credentials == null) {
        _logger.i(_tag, 'Error: No credentials available. Please save your service account credentials first.');
        return false;
      }

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        _logger.i(_tag, 'Error: Failed to get access token');
        return false;
      }

      _logger.i(_tag, 'Sending FCM request...');
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${_credentials!['project_id']}/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': additionalData ?? {},
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'heart_guard_channel',
                'priority': 'high',
                'default_sound': true,
                'default_vibrate_timings': true,
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        _logger.i(_tag, 'Test notification sent successfully');
        final responseData = json.decode(response.body);
        _logger.i(_tag, 'FCM Message ID: ${responseData['name']}');
        return true;
      } else {
        _logger.i(_tag, 'Failed to send test notification. Status: ${response.statusCode}');
        _logger.i(_tag, 'Response: ${response.body}');
        
        // Parse error response
        try {
          final errorData = json.decode(response.body);
          _logger.i(_tag, 'Error details:');
          _logger.i(_tag, '  Code: ${errorData['error']['code']}');
          _logger.i(_tag, '  Message: ${errorData['error']['message']}');
          _logger.i(_tag, '  Status: ${errorData['error']['status']}');
        } catch (e) {
          _logger.i(_tag, 'Could not parse error response: $e');
        }
        
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e(_tag, 'Error sending test notification', e, stackTrace);
      return false;
    }
  }
}
