import 'package:logger/logger.dart';
import '../models/ecg_reading.dart';


class ChatbotService {
  final Logger _logger = Logger();

  // Constants for heart rate ranges
  static const int minHeartRate = 60;
  static const int maxHeartRate = 100;
  static const double normalEcgLowerBound = -0.5;
  static const double normalEcgUpperBound = 0.5;

  String generateResponse(String userInput, {EcgReading? latestReading}) {
    try {
      final input = userInput.toLowerCase();

      // Handle greetings
      if (_isGreeting(input)) {
        return _handleGreeting(latestReading);
      }

      // Handle health status queries
      if (_isHealthStatusQuery(input)) {
        return _handleHealthStatus(latestReading);
      }

      // Handle heart rate queries
      if (_isHeartRateQuery(input)) {
        return _handleHeartRate(latestReading);
      }

      // Handle ECG queries
      if (_isEcgQuery(input)) {
        return _handleEcgStatus(latestReading);
      }

      // Handle lifestyle recommendations
      if (_isLifestyleQuery(input)) {
        return _handleLifestyleRecommendations(latestReading);
      }

      // Handle emergency detection
      if (_isEmergencyQuery(input)) {
        return _handleEmergencyResponse(latestReading);
      }

      // Default response with suggestions
      return "I can help you with:\n\n"
             "1. Health status check\n"
             "2. Heart rate monitoring\n"
             "3. ECG analysis\n"
             "4. Lifestyle recommendations\n"
             "5. Emergency assistance\n\n"
             "What would you like to know about?";

    } catch (e, stackTrace) {
      _logger.e('Error generating response', error: e, stackTrace: stackTrace);
      return "I'm sorry, I encountered an error processing your request. Please try again.";
    }
  }

  bool _isGreeting(String input) {
    return input.contains('hello') || 
           input.contains('hi') || 
           input.contains('hey') ||
           input.contains('good morning') ||
           input.contains('good afternoon') ||
           input.contains('good evening');
  }

  bool _isHealthStatusQuery(String input) {
    return input.contains('how am i') || 
           input.contains('how do i look') || 
           input.contains('my health') ||
           input.contains('my condition') ||
           input.contains('my status') ||
           input.contains('health status');
  }

  bool _isHeartRateQuery(String input) {
    return input.contains('heart rate') || 
           input.contains('bpm') || 
           input.contains('pulse') ||
           input.contains('heartbeat');
  }

  bool _isEcgQuery(String input) {
    return input.contains('ecg') || 
           input.contains('electrocardiogram') || 
           input.contains('heart rhythm') ||
           input.contains('heart pattern');
  }

  bool _isLifestyleQuery(String input) {
    return input.contains('recommend') || 
           input.contains('advice') || 
           input.contains('suggestion') ||
           input.contains('what should i do') ||
           input.contains('how can i improve') ||
           input.contains('lifestyle') ||
           input.contains('exercise') ||
           input.contains('diet') ||
           input.contains('sleep') ||
           input.contains('life style') ||
           input.contains('health tips');
  }

  bool _isEmergencyQuery(String input) {
    return input.contains('emergency') || 
           input.contains('help') || 
           input.contains('not feeling well') ||
           input.contains('feel sick') ||
           input.contains('feel dizzy') ||
           input.contains('chest pain') ||
           input.contains('short of breath');
  }

  String _handleGreeting(EcgReading? reading) {
    if (reading == null || reading.bpm == null) {
      return "Hello! I'm your health assistant. I can help you with health monitoring and lifestyle recommendations. "
             "Would you like to know about:\n"
             "• Your current health status\n"
             "• Lifestyle recommendations\n"
             "• Exercise suggestions\n"
             "• Heart health tips";
    }

    final bpm = reading.bpm!;
    if (bpm < minHeartRate) {
      return "Hello! I notice your heart rate is a bit low at $bpm BPM. I can provide some recommendations to help improve your heart rate. Would you like that?";
    } else if (bpm > maxHeartRate) {
      return "Hello! I notice your heart rate is elevated at $bpm BPM. I can suggest some relaxation techniques and lifestyle adjustments. Would you like to hear them?";
    }
    
    return "Hello! Your heart rate looks good at $bpm BPM. "
           "I can provide lifestyle recommendations to help maintain your health. What would you like to know about?";
  }

  String _handleLifestyleRecommendations(EcgReading? reading) {
    // Even without readings, we can provide general recommendations
    String baseRecommendations = "Here are some general lifestyle recommendations:\n\n"
        "1. Exercise Routine:\n"
        "   • Aim for 150 minutes of moderate exercise per week\n"
        "   • Include both cardio and strength training\n"
        "   • Start with walking 30 minutes daily\n\n"
        "2. Heart Health:\n"
        "   • Maintain a balanced diet\n"
        "   • Stay hydrated (8 glasses of water daily)\n"
        "   • Get 7-9 hours of sleep\n\n"
        "3. Stress Management:\n"
        "   • Practice deep breathing exercises\n"
        "   • Take regular breaks during work\n"
        "   • Consider meditation or yoga\n\n";

    if (reading == null || reading.bpm == null) {
      return "${baseRecommendations}Would you like more specific recommendations about any of these areas?";
    }

    final bpm = reading.bpm!;
    String specificRecommendations = "";

    if (bpm < minHeartRate) {
      specificRecommendations = "\nBased on your current heart rate ($bpm BPM), which is lower than normal, I also recommend:\n• Gradually increasing physical activity\n• Checking iron levels with your doctor\n• Having small, frequent meals\n• Staying well-hydrated\n• Avoiding sudden position changes\n";
    } else if (bpm > maxHeartRate) {
      specificRecommendations = "\nBased on your elevated heart rate ($bpm BPM), I also recommend:\n• Taking regular breaks to practice deep breathing\n• Limiting caffeine intake\n• Ensuring adequate rest periods\n• Practicing relaxation techniques\n• Monitoring stress levels\n";
    } else {
      specificRecommendations = "\nYour current heart rate ($bpm BPM) is within normal range. To maintain this:\n"
          "• Continue with regular moderate exercise\n"
          "• Maintain a consistent sleep schedule\n"
          "• Practice stress management techniques\n"
          "• Stay active throughout the day\n";
    }

    return "$baseRecommendations$specificRecommendations\nWould you like more specific details about any of these recommendations?";
  }

  String _handleHealthStatus(EcgReading? reading) {
    if (reading == null || reading.bpm == null) {
      return "I don't have your current health readings, but I can still provide general health advice and recommendations. "
             "Would you like to hear some general health tips?";
    }

    final bpm = reading.bpm!;
    final status = _getHeartRateStatus(bpm.toInt());
    final ecgStatus = _getEcgPatternStatus(reading);

    return "Here's your current health status:\n\n"
           "• Heart Rate: $bpm BPM ($status)\n"
           "• ECG Pattern: $ecgStatus\n\n"
           "Based on these readings, here are my recommendations:\n"
           "${_getHealthRecommendations(bpm.toInt())}\n\n"
           "Would you like more specific advice about any of these areas?";
  }

  String _handleHeartRate(EcgReading? reading) {
    if (reading == null) {
      return "I don't have any current heart rate readings. Please ensure your monitoring device is connected and active.";
    }

    final bpm = reading.bpm;
    if (bpm == null) {
      return "I don't have your current heart rate reading. Please ensure your monitoring device is connected and active.";
    }

    final status = _getHeartRateStatus(bpm.toInt());
    final trend = _getHeartRateTrend(reading);

    return "Your current heart rate is $bpm BPM, which is $status.\n\n"
           "Recent trend: $trend\n\n"
           "Would you like to know more about what this means or get some recommendations?";
  }

  String _handleEcgStatus(EcgReading? reading) {
    if (reading == null) {
      return "I don't have any current ECG readings. Please ensure your monitoring device is connected and active.";
    }

    final patternStatus = _getEcgPatternStatus(reading);
    final bpm = reading.bpm;

    return "Your ECG pattern shows $patternStatus with a heart rate of ${bpm ?? 'unknown'} BPM.\n\n"
           "This suggests ${_getEcgInterpretation(reading)}.\n\n"
           "Would you like to know more about what this means or get some recommendations?";
  }

  String _handleEmergencyResponse(EcgReading? reading) {
    if (reading == null) {
      return "⚠️ ATTENTION: I don't have current health readings, but based on your message, you may need medical attention. Please seek immediate medical help or call emergency services.";
    }

    final bpm = reading.bpm;
    if (bpm == null) {
      return "⚠️ ATTENTION: I don't have your current heart rate reading, but based on your message, you may need medical attention. Please seek immediate medical help or call emergency services.";
    }

    if (bpm < minHeartRate || bpm > maxHeartRate) {
      return "⚠️ ATTENTION: Your heart rate of $bpm BPM is outside the normal range. "
             "This could indicate a medical emergency. Please seek immediate medical attention. "
             "Would you like me to contact emergency services?";
    }

    return "I understand you're feeling unwell. Your current heart rate is $bpm BPM, which is within the normal range. "
           "However, if you're experiencing severe symptoms like chest pain, difficulty breathing, or severe dizziness, "
           "please seek immediate medical attention. Would you like me to contact emergency services?";
  }

  String _getHeartRateStatus(int bpm) {
    if (bpm < minHeartRate) return "below normal";
    if (bpm > maxHeartRate) return "above normal";
    return "normal";
  }

  String _getHeartRateTrend(EcgReading reading) {
    final bpm = reading.bpm;
    if (bpm == null) return "No heart rate data available";
    
    if (bpm < minHeartRate) return "Your heart rate has been consistently low";
    if (bpm > maxHeartRate) return "Your heart rate has been consistently high";
    return "Your heart rate has been stable";
  }

  String _getEcgPatternStatus(EcgReading reading) {
    if (!reading.hasValidData) return "no valid data";
    
    final values = reading.values;
    if (values == null || values.isEmpty) return "no data points";
    
    // Simple pattern analysis
    final hasIrregularities = values.any((v) => 
      v < normalEcgLowerBound || v > normalEcgUpperBound);
    
    return hasIrregularities ? "some irregularities" : "normal pattern";
  }

  String _getEcgInterpretation(EcgReading reading) {
    final patternStatus = _getEcgPatternStatus(reading);
    final bpm = reading.bpm;
    
    if (patternStatus == "no valid data" || patternStatus == "no data points") {
      return "insufficient data for interpretation";
    }
    
    if (patternStatus == "some irregularities" && bpm != null && (bpm < minHeartRate || bpm > maxHeartRate)) {
      return "potential cardiac concerns that should be evaluated by a healthcare professional";
    }
    
    if (patternStatus == "some irregularities") {
      return "minor variations that may be normal, but should be monitored";
    }
    
    return "normal cardiac activity";
  }

  String _getHealthRecommendations(int bpm) {
    if (bpm < minHeartRate) {
      return "• Consider light exercise to increase heart rate\n"
             "• Stay hydrated\n"
             "• Monitor for symptoms of fatigue or dizziness";
    } else if (bpm > maxHeartRate) {
      return "• Take deep breaths and try to relax\n"
             "• Avoid strenuous activity\n"
             "• Monitor for symptoms of chest pain or shortness of breath";
    } else {
      return "• Maintain regular exercise routine\n"
             "• Stay hydrated\n"
             "• Get adequate sleep\n"
             "• Manage stress levels";
    }
  }
} 