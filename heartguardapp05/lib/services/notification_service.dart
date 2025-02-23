import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:jose/jose.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Map<String, dynamic>? _credentials;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Add topic constants
  static const String TOPIC_HEART_ALERTS = 'heart_guard_alerts';
  static const String TOPIC_HIGH_HEART_RATE = 'high_heart_rate';
  static const String TOPIC_LOW_HEART_RATE = 'low_heart_rate';
  static const String TOPIC_GENERAL = 'general_updates';

  Future<void> initialize() async {
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
          print('Notification clicked: ${details.payload}');
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
      
      print('User granted permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _fcm.getToken();
      print('FCM Token: $token');

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
        print('FCM Token refreshed: $newToken');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
          await _saveTokenToFirestore(user.uid, newToken);
      }
    });

    // Handle incoming messages when app is in foreground
      FirebaseMessaging.onMessage.listen((message) async {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
        await _handleForegroundMessage(message);
      });

    // Handle when user taps on notification when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('Message opened from background state!');
        print('Message data: ${message.data}');
        _handleBackgroundMessage(message);
      });
      
      print('NotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing NotificationService: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadCredentials() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/firebase_credentials.json');
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        _credentials = json.decode(contents);
        print('Credentials loaded successfully');
      } else {
        print('No credentials file found');
      }
    } catch (e) {
      print('Error loading credentials: $e');
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
      print('Credentials saved successfully');
    } catch (e) {
      print('Error saving credentials: $e');
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
      await _fcm.subscribeToTopic(TOPIC_HEART_ALERTS);
      await _fcm.subscribeToTopic(TOPIC_HIGH_HEART_RATE);
      await _fcm.subscribeToTopic(TOPIC_LOW_HEART_RATE);
      await _fcm.subscribeToTopic(TOPIC_GENERAL);
      
      print('Subscribed to all notification topics');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notification_topics': {
            TOPIC_HEART_ALERTS: true,
            TOPIC_HIGH_HEART_RATE: true,
            TOPIC_LOW_HEART_RATE: true,
            TOPIC_GENERAL: true,
          },
          'last_topic_update': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error subscribing to topics: $e');
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
          print('Handling heart rate alert click: $type');
          break;
        case 'campaign':
          // Handle campaign notification clicks
          final campaignId = data['campaignId'];
          if (campaignId != null) {
            await _trackCampaignClick(campaignId);
          }
          break;
        default:
          print('Unknown notification type: $type');
      }
    } catch (e) {
      print('Error handling notification click: $e');
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
      print('Error tracking campaign click: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling foreground message: ${message.messageId}');
    print('Message data: ${message.data}');

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
      print('Error handling foreground message: $e');
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling background message: ${message.messageId}');
    // Background messages are handled by the global handler in main.dart
  }

  Future<void> _saveNotificationToFirestore(
      String userId, RemoteMessage message) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': message.notification?.title ?? 'Heart Guard Alert',
        'message': message.notification?.body ??
            'Please check your heart rate readings',
        'heartRate': int.tryParse(message.data['heartRate'] ?? '0'),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  Future<void> sendAbnormalityNotification({
    required String userId,
    required int heartRate,
    required String abnormalityType,
  }) async {
    try {
      print('Sending automatic abnormality notification for user: $userId');
      print('Heart rate: $heartRate BPM, Type: $abnormalityType');

      // Get user's FCM token
      final tokenDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc('fcm')
          .get();

      if (!tokenDoc.exists) {
        print('Error: No FCM token found for user: $userId');
        return;
      }

      final token = tokenDoc.data()?['token'] as String?;
      if (token == null) {
        print('Error: FCM token is null for user: $userId');
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

      print('Saving notification to Firestore...');
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
      print('Notification saved with ID: ${notificationRef.id}');

      // Send FCM notification with enhanced data
      print('Sending FCM notification...');
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
        print('Automatic abnormality notification sent successfully');
        
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
        print('Failed to send automatic abnormality notification');
        
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
      print('Error sending abnormality notification: $e');
      print('Stack trace: $stackTrace');
      
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
        print('Error logging to analytics: $analyticsError');
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
        print('FCM notification sent successfully');
        return true;
      } else {
        print('Failed to send FCM notification. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
      return false;
    }
  }

  Future<String?> _getAccessToken() async {
    try {
      if (_credentials == null) {
        print('Error: No credentials available. Please ensure credentials are loaded.');
        return null;
      }

      if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        print('Using cached access token (expires in: ${_tokenExpiry!.difference(DateTime.now()).inMinutes} minutes)');
        return _accessToken;
      }

      print('Generating new access token...');
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
        print('New access token generated successfully (expires in: ${data['expires_in']} seconds)');
        return _accessToken;
      } else {
        print('Failed to get access token. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('Error getting access token: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> verifyCredentials() async {
    try {
      print('Verifying Firebase credentials...');
      
      if (_credentials == null) {
        print('Error: No credentials loaded');
        return false;
      }

      // Verify project ID
      if (_credentials!['project_id'] != 'heart-guard-1c49e') {
        print('Error: Invalid project ID');
        return false;
      }

      // Test JWT generation
      try {
        print('Testing JWT generation...');
        final jwt = _generateJWT();
        if (jwt.isEmpty) {
          print('Error: Generated JWT is empty');
          return false;
        }
        print('JWT generation successful');
      } catch (e) {
        print('Error generating JWT: $e');
        return false;
      }

      // Test access token generation
      print('Testing access token generation...');
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('Error: Failed to generate access token');
        return false;
      }

      print('Credentials verified successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error verifying credentials: $e');
      print('Stack trace: $stackTrace');
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
      print('Sending test notification to token: ${fcmToken.substring(0, 10)}...');
      
      if (_credentials == null) {
        print('Error: No credentials available. Please save your service account credentials first.');
        return false;
      }

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('Error: Failed to get access token');
        return false;
      }

      print('Sending FCM request...');
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
        print('Test notification sent successfully');
        final responseData = json.decode(response.body);
        print('FCM Message ID: ${responseData['name']}');
        return true;
      } else {
        print('Failed to send test notification. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        
        // Parse error response
        try {
          final errorData = json.decode(response.body);
          print('Error details:');
          print('  Code: ${errorData['error']['code']}');
          print('  Message: ${errorData['error']['message']}');
          print('  Status: ${errorData['error']['status']}');
        } catch (e) {
          print('Could not parse error response: $e');
        }
        
        return false;
      }
    } catch (e, stackTrace) {
      print('Error sending test notification: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}
