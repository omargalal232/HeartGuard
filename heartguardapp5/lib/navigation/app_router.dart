import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/signup_screen.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/profile_screen.dart';
import '../views/screens/monitoring_screen.dart';
import '../views/screens/settings_screen.dart';
import '../views/screens/chatbot_screen.dart';
import '../views/screens/emergency_contacts_screen.dart';


class AppRouter {
  static const String monitoring = '/monitoring';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.loginRoute:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case AppConstants.signupRoute:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      
      case AppConstants.homeRoute:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case AppConstants.profileRoute:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case monitoring:
        return MaterialPageRoute(builder: (_) => const MonitoringScreen());
      
      case AppConstants.settingsRoute:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case AppConstants.chatbotRoute:
        return MaterialPageRoute(builder: (_) => const ChatbotScreen());

      case AppConstants.emergencyContactsRoute:
        return MaterialPageRoute(builder: (_) => const EmergencyContactsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('لا يوجد مسار معرف لـ ${settings.name}'),
            ),
          ),
        );
    }
  }
} 