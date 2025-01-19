import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Firebase Cloud Messaging server key
  static const String _serverKey = 'AIzaSyAljUNCr6Qh6FikDif2oDZ6tU38wENopC0';

  Future<void> initialize() async {
    // Request permission for notifications
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotifications.initialize(initializationSettings);

    // Get FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveTokenToFirestore(user.uid, token);
      }
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _saveTokenToFirestore(user.uid, newToken);
      }
    });

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when user taps on notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling foreground message: ${message.messageId}');
    
    // Show local notification
    const androidDetails = AndroidNotificationDetails(
      'heart_guard_channel',
      'Heart Guard Notifications',
      channelDescription: 'Notifications for heart abnormalities',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Heart Guard Alert',
      message.notification?.body ?? 'Please check your heart rate readings',
      notificationDetails,
    );

    // Save notification to Firestore if it contains heart rate data
    if (message.data.containsKey('heartRate')) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveNotificationToFirestore(user.uid, message);
      }
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling background message: ${message.messageId}');
    // Handle background message if needed
  }

  Future<void> _saveNotificationToFirestore(String userId, RemoteMessage message) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': message.notification?.title ?? 'Heart Guard Alert',
        'message': message.notification?.body ?? 'Please check your heart rate readings',
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
      // Get user's FCM token
      final tokenDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc('fcm')
          .get();

      if (!tokenDoc.exists) return;

      final token = tokenDoc.data()?['token'] as String?;
      if (token == null) return;

      // Create notification message
      String message = 'Abnormality detected in your heart rate ($heartRate BPM). ';
      if (heartRate < 60) {
        message += 'Your heart rate is too low. Please contact a doctor.';
      } else if (heartRate > 100) {
        message += 'Your heart rate is too high. Please contact a doctor.';
      } else {
        message += 'Please contact a doctor for evaluation.';
      }

      // Save notification to Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'heartRate': heartRate,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'abnormalityType': abnormalityType,
      });

      // Send FCM notification
      await _sendFCMNotification(
        token: token,
        title: 'Heart Guard Alert',
        body: message,
        data: {
          'heartRate': heartRate.toString(),
          'abnormalityType': abnormalityType,
          'userId': userId,
        },
      );

      // Show local notification
      const androidDetails = AndroidNotificationDetails(
        'heart_guard_channel',
        'Heart Guard Notifications',
        channelDescription: 'Notifications for heart abnormalities',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Heart Guard Alert',
        message,
        notificationDetails,
      );
    } catch (e) {
      print('Error sending abnormality notification: $e');
    }
  }

  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
          'to': token,
          'priority': 'high',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send FCM notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
      rethrow;
    }
  }
} 