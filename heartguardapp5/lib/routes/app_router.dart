import 'package:flutter/material.dart';
import '../views/medical_record_page.dart';
import '../views/screens/medical_records_list_screen.dart';
import '../models/profile_model.dart';
import '../models/ecg_reading.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
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
        return _errorRoute('Invalid arguments for MedicalRecordPage');
        
      case AppConstants.medicalRecordsRoute:
        return MaterialPageRoute(
          builder: (_) => const MedicalRecordsListScreen(),
        );
        
      // Add other routes here
      // case AnotherPage.routeName:
      //   return MaterialPageRoute(builder: (_) => AnotherPage());
      default:
        return _errorRoute('Unknown route: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
          ),
          body: Center(
            child: Text(message),
          ),
        );
      },
    );
  }
} 