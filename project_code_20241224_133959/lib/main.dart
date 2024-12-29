import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:heartguard/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/constants.dart';
import 'pages/onboarding_screen.dart';
import 'pages/main_screen.dart';
import 'styles/theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'services/websocket_service.dart';
import 'services/alert_service.dart';
import 'services/ecg_service.dart';
import 'pages/ecg_monitoring_screen.dart';
import 'pages/ecg_results_screen.dart';
import 'pages/history_screen.dart';
import 'pages/analysis_&_alerts_screen.dart';
import 'pages/profile_&_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Push Notification Service
  await PushNotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
        ChangeNotifierProvider<AlertService>(
          create: (_) => AlertService(),
        ),
        ChangeNotifierProvider<ECGService>(
          create: (_) => ECGService(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        StreamProvider<UserModel?>(
          create: (context) {
            final auth = context.read<AuthService>();
            if (auth.currentUser != null) {
              return context.read<FirestoreService>().getUser(auth.currentUser!.uid);
            }
            return Stream.value(null);
          },
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: theme,
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/monitoring': (context) => const ECGMonitoringScreen(),
        '/results': (context) => const ECGResultsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/analysis': (context) => const AnalysisAndAlertsScreen(),
        '/profile': (context) => const ProfileSettingsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();

    // If the user is logged in, show the MainScreen
    if (user != null) {
      return const MainScreen();
    }

    // If the user is not logged in, show the OnboardingScreen
    return const OnboardingScreen();
  }
}