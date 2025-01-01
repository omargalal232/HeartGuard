import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<Map<String, dynamic>> analyzeECG(String ecgData) async {
    // Basic ECG analysis logic
    double heartRate = calculateHeartRate(ecgData);
    bool isNormal = heartRate >= 60 && heartRate <= 100;
    
    return {
      'heartRate': heartRate,
      'isNormal': isNormal,
      'timestamp': DateTime.now(),
    };
  }

  Future<void> sendAlert(String message) async {
    // Store alert in Firestore
    await _firestore.collection('alerts').add({
      'message': message,
      'timestamp': DateTime.now(),
    });

    // Send push notification
    await _messaging.sendMessage(
      data: {
        'type': 'alert',
        'message': message,
      },
    );
  }

  double calculateHeartRate(String ecgData) {
    // Simple heart rate calculation (replace with actual ML model)
    return 72.0; // Default normal heart rate for demo
  }
} 