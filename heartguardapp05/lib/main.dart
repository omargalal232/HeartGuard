import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/signup_screen.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/monitoring_screen.dart';
import 'views/screens/history_screen.dart';
import 'views/screens/profile_screen.dart';
import 'views/screens/emergency_screen.dart';
import 'providers/emergency_provider.dart';
import 'firebase_options.dart'; // Import the generated firebase_options.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Pass the generated options here
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EmergencyProvider>(create: (_) => EmergencyProvider()),
      ],
      child: MaterialApp(
        title: 'Heart Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/monitoring': (context) => const MonitoringScreen(),
          '/analysis': (context) => const HistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/emergency': (context) => const EmergencyScreen(),
        },
      ),
    );
  }
}
