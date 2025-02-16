import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/signup_screen.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/profile_screen.dart';
import 'views/screens/monitoring_screen.dart';
import 'views/screens/notification_screen.dart';
import 'firebase_options.dart';
import 'views/screens/file_upload_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'views/screens/chatbot_screen.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize NotificationService first
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Initialize FCM Service and get access token
    final fcmService = FCMService();
    final accessToken = await fcmService.getAccessToken();
    if (accessToken != null) {
      print('\n=== FCM Access Token ===');
      print(accessToken);
      print('========================\n');

      // Send a test notification
      print('Sending test notification...');
      final success = await fcmService.sendTestNotification();
      print('Test notification ${success ? 'sent successfully' : 'failed'}');
    }

    // Request notification permissions with all options
    final messaging = FirebaseMessaging.instance;
    
    // Set background message handler before anything else
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Request permission with all options
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      carPlay: true,
      criticalAlert: true,
      provisional: false,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Set foreground notification presentation options
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token and print it for debugging
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error initializing app: $e');
    print('Stack trace: $stackTrace');
    // Run app with error state
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeartGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/monitoring': (context) => const MonitoringScreen(),
        '/heart sound': (context) => const FileUploadScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/signup': (context) => const SignupScreen(),
        '/chatbot': (context) => ChatbotScreen(),
      },
    );
  }
}

class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $_error'),
          ),
        ),
      );
    }

    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}



  