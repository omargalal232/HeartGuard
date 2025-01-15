import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final _messageController = StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get messages => _messageController.stream;

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission for notifications');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission for notifications');
      } else {
        print('User declined permission for notifications');
        return;
      }

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      print('Firebase Messaging Token: $token');

      // Configure message handling
      FirebaseMessaging.onMessage.listen(_handleMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Get initial message if app was opened from notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      // Configure foreground notification presentation
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print('Error initializing push notifications: $e');
      throw Exception('Failed to initialize push notifications: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    print('Message received: ${message.notification?.title}');
    _messageController.add(message);
  }

  /// Subscribe to a topic for receiving specific notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
      throw Exception('Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
      throw Exception('Failed to unsubscribe from topic: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _messageController.close();
  }
}

/// Handle background messages
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Handling background message: ${message.notification?.title}');
  // Add your background message handling logic here
}
