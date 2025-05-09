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
import '../views/screens/medical_records_list_screen.dart';
import '../views/medical_record_page.dart';
import '../models/profile_model.dart';
import '../models/ecg_reading.dart';


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

      case AppConstants.medicalRecordsRoute:
        return MaterialPageRoute(builder: (_) => const MedicalRecordsListScreen());
        
      case MedicalRecordPage.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null &&
            args['patientProfile'] is ProfileModel &&
            args['ecgReading'] is EcgReading) {
          return MaterialPageRoute(
            builder: (_) => MedicalRecordPage(
              patientProfile: args['patientProfile'] as ProfileModel,
              ecgReading: args['ecgReading'] as EcgReading,
            ),
          );
        }
        // If args are not valid, navigate to an error page or show a dialog
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Invalid arguments for Medical Record')),
          ),
        );

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