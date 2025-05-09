import 'package:logger/logger.dart';
import '../models/ecg_reading.dart';

class ChatbotService {
  final Logger _logger = Logger();
  
  // Conversation context tracking
  final Map<String, dynamic> _conversationContext = {};
  final List<String> _recentQueries = [];
  
  // Track user's reported symptoms
  final Set<String> _reportedSymptoms = {};
  String? _lastTopic;
  
  // Track user sentiment
  int _sentimentScore = 0; // Negative values = negative sentiment, positive values = positive sentiment
  
  // Keep track of repeated topics
  final Map<String, int> _topicFrequency = {};
  
  // Constants for heart rate ranges
  static const int minHeartRate = 60;
  static const int maxHeartRate = 100;
  static const double normalEcgLowerBound = -0.5;
  static const double normalEcgUpperBound = 0.5;
  
  // Singleton pattern
  static final ChatbotService _instance = ChatbotService._internal();
  
  factory ChatbotService() => _instance;
  
  ChatbotService._internal();

  String generateResponse(String userInput, {EcgReading? latestReading}) {
    try {
      final input = userInput.toLowerCase();
      _recentQueries.add(input);
      if (_recentQueries.length > 5) {
        _recentQueries.removeAt(0);
      }
      
      // Track symptoms mentioned in the message
      _checkForSymptoms(input);
      
      // Track sentiment in the message
      _updateSentiment(input);
      
      // Check for follow-up questions first
      if (_isFollowUpQuestion(input) && _lastTopic != null) {
        return _handleFollowUp(input, _lastTopic!, latestReading);
      }

      // Handle specific intents
      String response = "";
      String topic = "";
      
      if (_isGreeting(input)) {
        topic = 'greeting';
        response = _handleGreeting(latestReading);
      } else if (_isHealthStatusQuery(input)) {
        topic = 'health_status';
        response = _handleHealthStatus(latestReading);
      } else if (_isHeartRateQuery(input)) {
        topic = 'heart_rate';
        response = _handleHeartRate(latestReading);
      } else if (_isEcgQuery(input)) {
        topic = 'ecg';
        response = _handleEcgStatus(latestReading);
      } else if (_isLifestyleQuery(input)) {
        topic = 'lifestyle';
        response = _handleLifestyleRecommendations(latestReading);
      } else if (_isStressQuery(input)) {
        topic = 'stress';
        response = _handleStressManagement(latestReading);
      } else if (_isSleepQuery(input)) {
        topic = 'sleep';
        response = _handleSleepAdvice(latestReading);
      } else if (_isDietQuery(input)) {
        topic = 'diet';
        response = _handleDietAdvice(latestReading);
      } else if (_isEmergencyQuery(input)) {
        topic = 'emergency';
        response = _handleEmergencyResponse(latestReading);
      } else if (_isExerciseQuery(input)) {
        topic = 'exercise';
        response = _handleExerciseAdvice(latestReading);
      } else {
        topic = 'general';
        response = _generateContextualSuggestions(latestReading);
      }
      
      // Update topic frequency
      _updateTopicFrequency(topic);
      
      // Update the last topic for context
      _lastTopic = topic;
      
      // Add suggested follow-up questions if not an emergency
      if (topic != 'emergency') {
        final suggestions = _generateSuggestedFollowUps(topic, latestReading);
        if (suggestions.isNotEmpty) {
          response += "\n\nYou might also want to ask:\n$suggestions";
        }
      }
      
      return response;
    } catch (e, stackTrace) {
      _logger.e('Error generating response', error: e, stackTrace: stackTrace);
      return "I'm sorry, I encountered an error processing your request. Please try again.";
    }
  }
  
  String _generateSuggestedFollowUps(String topic, EcgReading? latestReading) {
    List<String> suggestions = [];
    
    switch (topic) {
      case 'health_status':
        suggestions.add("• How can I improve my heart health?");
        if (_sentimentScore < 0) {
          suggestions.add("• What should I be concerned about?");
        }
        break;
        
      case 'heart_rate':
        suggestions.add("• What is a normal heart rate?");
        suggestions.add("• How can I lower my resting heart rate?");
        if (latestReading?.bpm != null) {
          final bpm = latestReading!.bpm!;
          if (bpm > maxHeartRate) {
            suggestions.add("• Why is my heart rate elevated?");
          } else if (bpm < minHeartRate) {
            suggestions.add("• Is my low heart rate a concern?");
          }
        }
        break;
        
      case 'ecg':
        suggestions.add("• What does my ECG pattern mean?");
        suggestions.add("• How often should I check my ECG?");
        break;
        
      case 'lifestyle':
        if (!_topicFrequency.containsKey('exercise')) {
          suggestions.add("• What exercise is best for heart health?");
        }
        if (!_topicFrequency.containsKey('diet')) {
          suggestions.add("• What foods are heart-healthy?");
        }
        break;
        
      case 'stress':
        suggestions.add("• How does stress affect my heart?");
        suggestions.add("• Can you teach me a breathing exercise?");
        break;
        
      case 'sleep':
        suggestions.add("• How does sleep affect heart health?");
        suggestions.add("• What's the ideal sleep schedule?");
        break;
        
      case 'diet':
        suggestions.add("• Which foods should I avoid?");
        suggestions.add("• Can you suggest a heart-healthy meal plan?");
        break;
        
      case 'exercise':
        suggestions.add("• How much exercise do I need each week?");
        suggestions.add("• What's the best time to exercise?");
        break;
        
      case 'general':
      case 'greeting':
        if (_reportedSymptoms.isNotEmpty) {
          suggestions.add("• Are my symptoms concerning?");
        }
        if (latestReading?.bpm != null) {
          suggestions.add("• How's my heart rate looking?");
        }
        suggestions.add("• Can you give me health tips?");
        break;
    }
    
    // Limit to 3 suggestions
    if (suggestions.length > 3) {
      suggestions = suggestions.sublist(0, 3);
    }
    
    return suggestions.join("\n");
  }

  void _updateSentiment(String input) {
    // Simple sentiment analysis
    final positiveWords = ['good', 'great', 'better', 'improved', 'happy', 'well', 'fine', 'excellent', 'amazing'];
    final negativeWords = ['bad', 'worse', 'worried', 'anxious', 'scared', 'afraid', 'terrible', 'poor', 'sick', 'pain'];
    
    for (final word in positiveWords) {
      if (input.contains(word)) {
        _sentimentScore += 1;
      }
    }
    
    for (final word in negativeWords) {
      if (input.contains(word)) {
        _sentimentScore -= 1;
      }
    }
    
    // Clamp the score to prevent extremes
    _sentimentScore = _sentimentScore.clamp(-5, 5);
  }
  
  void _updateTopicFrequency(String topic) {
    if (_topicFrequency.containsKey(topic)) {
      _topicFrequency[topic] = _topicFrequency[topic]! + 1;
    } else {
      _topicFrequency[topic] = 1;
    }
  }
  
  // Check for symptoms in user input and track them
  void _checkForSymptoms(String input) {
    final commonSymptoms = {
      'chest pain', 'shortness of breath', 'dizziness', 'fatigue',
      'fainting', 'palpitations', 'racing heart', 'irregular heartbeat',
      'swelling', 'nausea', 'cold sweat', 'anxiety', 'weakness'
    };
    
    for (var symptom in commonSymptoms) {
      if (input.contains(symptom)) {
        _reportedSymptoms.add(symptom);
      }
    }
  }
  
  // Generate contextual suggestions based on conversation history
  String _generateContextualSuggestions(EcgReading? latestReading) {
    // If user has reported symptoms, prioritize health advice
    if (_reportedSymptoms.isNotEmpty) {
      return "I notice you've mentioned the following symptoms: ${_reportedSymptoms.join(', ')}. "
             "Would you like me to:\n"
             "• Assess these symptoms\n"
             "• Check your current health status\n"
             "• Provide emergency guidance";
    }
    
    // If sentiment is negative, provide reassurance
    if (_sentimentScore < -2) {
      return "I can see you might be concerned. I'm here to help you understand your heart health better and provide guidance. "
             "Would you like to:\n"
             "• Review your current health status\n"
             "• Learn about managing stress\n"
             "• Get personalized health recommendations";
    }
    
    // Check recent queries to customize suggestions
    if (_recentQueries.any((q) => q.contains('exercise') || q.contains('active'))) {
      return "I can help you with:\n\n"
             "1. Exercise recommendations for heart health\n"
             "2. Monitoring your heart rate during workouts\n"
             "3. Recovery strategies after exercise\n\n"
             "What would you like to know more about?";
    }
    
    // Default response
    String response = "I can help you with:\n\n"
           "1. Health status check\n"
           "2. Heart rate monitoring\n"
           "3. ECG analysis\n"
           "4. Lifestyle recommendations\n"
           "5. Emergency assistance\n\n";
           
    // Add a personalized touch if we have readings
    if (latestReading?.bpm != null) {
      int bpm = latestReading!.bpm!.toInt();
      if (bpm < minHeartRate) {
        response += "I notice your heart rate is currently low at $bpm BPM. Would you like advice about this?";
      } else if (bpm > maxHeartRate) {
        response += "I notice your heart rate is currently elevated at $bpm BPM. Would you like me to provide recommendations?";
      } else {
        response += "Your heart rate is currently $bpm BPM, which is within the normal range. What would you like to know about?";
      }
    } else {
      response += "What would you like to know about?";
    }
    
    return response;
  }

  bool _isFollowUpQuestion(String input) {
    // Simple phrases that indicate a follow-up question
    List<String> followUpPhrases = [
      'what about', 'why', 'how', 'tell me more', 'more info',
      'what does that mean', 'what should i do', 'can you explain',
      'and', 'what else', 'go on', 'continue', 'elaborate'
    ];
    
    return followUpPhrases.any((phrase) => input.contains(phrase)) || 
           input.trim().length < 15; // Short responses are often follow-ups
  }
  
  String _handleFollowUp(String input, String previousTopic, EcgReading? latestReading) {
    switch (previousTopic) {
      case 'heart_rate':
        if (input.contains('mean') || input.contains('normal')) {
          return "A normal resting heart rate for adults is typically between 60-100 beats per minute. "
                 "Athletes might have lower rates, often between 40-60 BPM. "
                 "Many factors can influence your heart rate including age, fitness level, stress, and medications.";
        } else if (input.contains('improve') || input.contains('lower') || input.contains('reduce')) {
          return "To improve heart rate health:\n"
                 "• Regular cardiovascular exercise\n"
                 "• Stress reduction techniques like meditation\n"
                 "• Adequate sleep (7-9 hours nightly)\n"
                 "• Staying hydrated\n"
                 "• Limiting caffeine and alcohol";
        }
        break;
        
      case 'ecg':
        if (input.contains('normal') || input.contains('mean')) {
          return "A normal ECG shows a consistent pattern with P waves, QRS complexes, and T waves in regular intervals. "
                 "This indicates your heart's electrical system is functioning properly. "
                 "Irregularities might suggest arrhythmias or other heart conditions, but many variations can be normal for individuals.";
        } else if (input.contains('abnormal') || input.contains('irregular')) {
          return "Irregular ECG patterns can indicate various conditions including:\n"
                 "• Arrhythmias (irregular heart rhythms)\n"
                 "• Conduction abnormalities\n"
                 "• Heart muscle damage\n"
                 "• Electrolyte imbalances\n\n"
                 "It's important to have these evaluated by a healthcare professional.";
        }
        break;
        
      case 'lifestyle':
        if (input.contains('exercise') || input.contains('activity')) {
          return _handleExerciseAdvice(latestReading);
        } else if (input.contains('diet') || input.contains('food') || input.contains('eat')) {
          return _handleDietAdvice(latestReading);
        } else if (input.contains('stress') || input.contains('relax')) {
          return _handleStressManagement(latestReading);
        } else if (input.contains('sleep')) {
          return _handleSleepAdvice(latestReading);
        }
        break;
        
      case 'health_status':
        if (input.contains('improve')) {
          return "To improve your overall heart health:\n"
                 "• Exercise regularly (aim for 150+ minutes/week)\n"
                 "• Maintain a heart-healthy diet rich in fruits, vegetables, and lean proteins\n"
                 "• Manage stress through mindfulness or relaxation techniques\n"
                 "• Ensure adequate sleep (7-9 hours nightly)\n"
                 "• Avoid smoking and limit alcohol consumption\n"
                 "• Stay hydrated throughout the day";
        }
        break;
    }
    
    // If we couldn't handle the follow-up specifically, try to provide general information
    return '''To learn more about ${previousTopic.replaceAll('_', ' ')}, I can provide information about:
• Interpretation of your readings
• Recommendations for improvement
• Warning signs to watch for
• When to consult a healthcare professional

Which of these would be most helpful?''';
  }

  bool _isGreeting(String input) {
    return input.contains('hello') || 
           input.contains('hi') || 
           input.contains('hey') ||
           input.contains('good morning') ||
           input.contains('good afternoon') ||
           input.contains('good evening') ||
           input.contains('greetings');
  }

  bool _isHealthStatusQuery(String input) {
    return input.contains('how am i') || 
           input.contains('how do i look') || 
           input.contains('my health') ||
           input.contains('my condition') ||
           input.contains('my status') ||
           input.contains('health status') ||
           input.contains('overall health') ||
           input.contains('heart health');
  }

  bool _isHeartRateQuery(String input) {
    return input.contains('heart rate') || 
           input.contains('bpm') || 
           input.contains('pulse') ||
           input.contains('heartbeat') ||
           input.contains('beats per minute') ||
           input.contains('tachycardia') ||
           input.contains('bradycardia');
  }

  bool _isEcgQuery(String input) {
    return input.contains('ecg') || 
           input.contains('electrocardiogram') || 
           input.contains('heart rhythm') ||
           input.contains('heart pattern') ||
           input.contains('ekg') ||
           input.contains('arrhythmia');
  }

  bool _isLifestyleQuery(String input) {
    return input.contains('recommend') || 
           input.contains('advice') || 
           input.contains('suggestion') ||
           input.contains('what should i do') ||
           input.contains('how can i improve') ||
           input.contains('lifestyle') ||
           input.contains('health tips');
  }
  
  bool _isStressQuery(String input) {
    return input.contains('stress') || 
           input.contains('anxious') || 
           input.contains('anxiety') ||
           input.contains('relax') ||
           input.contains('calm') ||
           input.contains('meditation') ||
           input.contains('breathing');
  }
  
  bool _isSleepQuery(String input) {
    return input.contains('sleep') || 
           input.contains('insomnia') || 
           input.contains('rest') ||
           input.contains('tired') ||
           input.contains('fatigue') ||
           input.contains('bed');
  }
  
  bool _isDietQuery(String input) {
    return input.contains('diet') || 
           input.contains('food') || 
           input.contains('eat') ||
           input.contains('meal') ||
           input.contains('nutrition') ||
           input.contains('weight');
  }
  
  bool _isExerciseQuery(String input) {
    return input.contains('exercise') || 
           input.contains('workout') || 
           input.contains('physical activity') ||
           input.contains('training') ||
           input.contains('fitness') ||
           input.contains('cardio');
  }

  bool _isEmergencyQuery(String input) {
    return input.contains('emergency') || 
           input.contains('help') || 
           input.contains('not feeling well') ||
           input.contains('feel sick') ||
           input.contains('feel dizzy') ||
           input.contains('chest pain') ||
           input.contains('short of breath') ||
           input.contains('911') ||
           input.contains('ambulance');
  }

  String _handleGreeting(EcgReading? reading) {
    if (reading == null || reading.bpm == null) {
      return "Hello! I'm your HeartGuard health assistant. I can help you monitor your heart health and provide personalized recommendations. "
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
           "I can provide lifestyle recommendations to help maintain your heart health. What would you like to know about?";
  }

  String _handleLifestyleRecommendations(EcgReading? reading) {
    // Even without readings, we can provide general recommendations
    String baseRecommendations = "Here are some heart-healthy lifestyle recommendations:\n\n"
        "1. Exercise Routine:\n"
        "   • Aim for 150 minutes of moderate exercise per week\n"
        "   • Include both cardio and strength training\n"
        "   • Start with walking 30 minutes daily\n\n"
        "2. Heart Health Diet:\n"
        "   • Focus on fruits, vegetables, and whole grains\n"
        "   • Choose lean proteins and healthy fats\n"
        "   • Limit sodium, sugar, and processed foods\n"
        "   • Stay hydrated with water\n\n"
        "3. Stress Management:\n"
        "   • Practice deep breathing or meditation\n"
        "   • Take regular breaks during work\n"
        "   • Engage in activities you enjoy\n"
        "   • Consider mindfulness practices\n\n";

    if (reading == null || reading.bpm == null) {
      return "${baseRecommendations}Would you like specific details about exercise, diet, or stress management?";
    }

    final bpm = reading.bpm!;
    String specificRecommendations = "";

    if (bpm < minHeartRate) {
      specificRecommendations = "\nBased on your heart rate ($bpm BPM), which is lower than typical, I also recommend:\n• Gradually increasing physical activity\n• Checking iron levels with your doctor\n• Having small, frequent meals\n• Staying well-hydrated\n• Avoiding sudden position changes\n";
    } else if (bpm > maxHeartRate) {
      specificRecommendations = "\nBased on your elevated heart rate ($bpm BPM), I also recommend:\n• Taking regular breaks to practice deep breathing\n• Limiting caffeine intake\n• Ensuring adequate rest periods\n• Practicing relaxation techniques\n• Monitoring stress levels\n";
    } else {
      specificRecommendations = "\nYour current heart rate ($bpm BPM) is within normal range. To maintain this:\n"
          "• Continue with regular moderate exercise\n"
          "• Maintain a consistent sleep schedule\n"
          "• Practice stress management techniques\n"
          "• Stay active throughout the day\n";
    }

    return "$baseRecommendations$specificRecommendations\nWould you like more details about exercise, diet, or stress management?";
  }
  
  String _handleExerciseAdvice(EcgReading? reading) {
    String baseAdvice = "Heart-healthy exercise recommendations:\n\n"
        "• Start with 5-10 minutes of light warm-up\n"
        "• Aim for 150 minutes of moderate aerobic activity weekly\n"
        "• Include 2-3 days of strength training\n"
        "• Add flexibility exercises 2-3 times weekly\n"
        "• Cool down for 5-10 minutes after exercise\n\n"
        "Moderate activities include:\n"
        "• Brisk walking\n"
        "• Swimming\n"
        "• Cycling\n"
        "• Dancing\n";
    
    if (reading == null || reading.bpm == null) {
      return baseAdvice;
    }
    
    final bpm = reading.bpm!;
    
    if (bpm < minHeartRate) {
      return "$baseAdvice\nWith your lower heart rate, start slowly with light walking and gradually increase intensity. Monitor how you feel and stop if you experience dizziness or unusual fatigue.";
    } else if (bpm > maxHeartRate) {
      return "$baseAdvice\nWith your elevated heart rate, focus on gentle activities like walking or light yoga until your heart rate stabilizes. Avoid high-intensity exercise until your resting heart rate returns to normal range.";
    }
    
    return "$baseAdvice\nYour heart rate is in the normal range, which is great! You can follow a balanced exercise routine with moderate intensity activities.";
  }
  
  String _handleDietAdvice(EcgReading? reading) {
    String baseDietAdvice = "Heart-healthy eating recommendations:\n\n"
        "• Include plenty of fruits and vegetables (aim for 5+ servings daily)\n"
        "• Choose whole grains (brown rice, whole wheat, oats)\n"
        "• Select lean proteins (fish, poultry, beans, nuts)\n"
        "• Incorporate healthy fats (olive oil, avocados, nuts)\n"
        "• Limit sodium to less than 2,300mg daily\n"
        "• Reduce added sugars and processed foods\n"
        "• Stay well hydrated with water\n\n";
    
    if (reading == null || reading.bpm == null) {
      return "$baseDietAdvice Would you like specific meal suggestions or foods to focus on?";
    }
    
    final bpm = reading.bpm!;
    
    if (bpm < minHeartRate) {
      return "$baseDietAdvice With your lower heart rate, consider:\n"
             "• Eating smaller, more frequent meals\n"
             "• Including iron-rich foods like leafy greens and lean red meat\n"
             "• Staying well-hydrated throughout the day\n"
             "• Including moderate amounts of heart-healthy fats";
    } else if (bpm > maxHeartRate) {
      return "$baseDietAdvice With your elevated heart rate, consider:\n"
             "• Limiting caffeine intake\n"
             "• Reducing alcohol consumption\n"
             "• Avoiding large, heavy meals\n"
             "• Ensuring adequate hydration\n"
             "• Including potassium-rich foods like bananas and avocados";
    }
    
    return "$baseDietAdvice Your heart rate is in the normal range, which is excellent! Focus on maintaining balanced nutrition with regular meals.";
  }
  
  String _handleStressManagement(EcgReading? reading) {
    String baseAdvice = "Stress management for heart health:\n\n"
        "• Practice deep breathing exercises (4-7-8 technique)\n"
        "• Try progressive muscle relaxation\n"
        "• Incorporate mindfulness meditation\n"
        "• Take regular breaks during work\n"
        "• Spend time in nature\n"
        "• Engage in activities you enjoy\n"
        "• Connect with friends and family\n"
        "• Consider limiting news and social media\n\n";
    
    if (reading == null || reading.bpm == null) {
      return "$baseAdvice Would you like to learn a specific relaxation technique?";
    }
    
    final bpm = reading.bpm!;
    
    if (bpm > maxHeartRate) {
      return "$baseAdvice With your elevated heart rate, I recommend trying this simple breathing exercise now:\n\n"
             "1. Find a comfortable position\n"
             "2. Breathe in slowly through your nose for 4 counts\n"
             "3. Hold your breath for 7 counts\n"
             "4. Exhale slowly through your mouth for 8 counts\n"
             "5. Repeat 4-5 times\n\n"
             "This can help activate your parasympathetic nervous system and lower your heart rate.";
    }
    
    return "$baseAdvice Would you like a guided meditation or breathing exercise to try?";
  }
  
  String _handleSleepAdvice(EcgReading? reading) {
    String baseAdvice = "Sleep recommendations for heart health:\n\n"
        "• Aim for 7-9 hours of quality sleep each night\n"
        "• Maintain a consistent sleep schedule\n"
        "• Create a restful environment (cool, dark, quiet)\n"
        "• Limit screen time 1-2 hours before bed\n"
        "• Avoid caffeine and large meals close to bedtime\n"
        "• Develop a relaxing bedtime routine\n"
        "• Consider light exercise during the day\n\n";
    
    if (reading == null || reading.bpm == null) {
      return baseAdvice;
    }
    
    final bpm = reading.bpm!;
    
    if (bpm > maxHeartRate) {
      return "$baseAdvice With your elevated heart rate, try these additional tips:\n"
             "• Practice a calming bedtime ritual like gentle stretching\n"
             "• Try a warm (not hot) bath before bedtime\n"
             "• Consider deep breathing exercises as you prepare for sleep\n"
             "• Avoid stimulating activities in the evening";
    }
    
    return "$baseAdvice Proper sleep is essential for heart health and can help maintain your healthy heart rate.";
  }

  String _handleHealthStatus(EcgReading? reading) {
    if (reading == null || reading.bpm == null) {
      return "I don't have your current health readings, but I can still provide general health advice and recommendations. "
             "Would you like to hear about heart-healthy lifestyle tips or specific advice for exercise, diet, or stress management?";
    }

    final bpm = reading.bpm!;
    final status = _getHeartRateStatus(bpm.toInt());
    final ecgStatus = _getEcgPatternStatus(reading);
    
    // Add information about reported symptoms if any
    String symptomInfo = "";
    if (_reportedSymptoms.isNotEmpty) {
      symptomInfo = "\n\nYou've mentioned experiencing: ${_reportedSymptoms.join(', ')}. "
                   "These symptoms ${_getSymptomsAdvice()}";
    }

    return "Here's your current heart health status:\n\n"
           "• Heart Rate: $bpm BPM ($status)\n"
           "• ECG Pattern: $ecgStatus\n"
           "$symptomInfo\n\n"
           "Based on these readings, here are my recommendations:\n"
           "${_getHealthRecommendations(bpm.toInt())}\n\n"
           "Would you like specific advice about exercise, diet, or stress management?";
  }
  
  String _getSymptomsAdvice() {
    // Check for critical symptoms that require immediate attention
    List<String> criticalSymptoms = ['chest pain', 'shortness of breath', 'fainting'];
    
    for (var symptom in criticalSymptoms) {
      if (_reportedSymptoms.contains(symptom)) {
        return "could indicate a serious condition and should be evaluated by a healthcare professional immediately.";
      }
    }
    
    // Check for concerning symptoms
    List<String> concerningSymptoms = ['dizziness', 'palpitations', 'irregular heartbeat'];
    
    for (var symptom in concerningSymptoms) {
      if (_reportedSymptoms.contains(symptom)) {
        return "should be monitored closely and discussed with your healthcare provider.";
      }
    }
    
    // General advice for less concerning symptoms
    return "may be related to stress, fatigue, or other factors. Monitor these symptoms and consult a healthcare provider if they persist or worsen.";
  }

  String _handleHeartRate(EcgReading? reading) {
    if (reading == null) {
      return "I don't currently have your heart rate readings. Please ensure your monitoring device is connected and active.";
    }

    final bpm = reading.bpm;
    if (bpm == null) {
      return "I don't have your current heart rate reading. Please ensure your monitoring device is connected and active.";
    }

    final status = _getHeartRateStatus(bpm.toInt());
    final trend = _getHeartRateTrend(reading);

    String response = "Your current heart rate is $bpm BPM, which is $status.\n\n"
           "Recent trend: $trend\n\n";
           
    // Add educational content based on heart rate
    if (bpm < minHeartRate) {
      response += "A heart rate below 60 BPM is called bradycardia. This can be normal for athletes and during sleep. "
                 "However, it can sometimes indicate issues with your heart's electrical system or other conditions.\n\n"
                 "If you're experiencing symptoms like dizziness, weakness, or fatigue along with low heart rate, consult a healthcare provider.";
    } else if (bpm > maxHeartRate) {
      response += "A heart rate above 100 BPM is called tachycardia. This is normal during exercise, stress, or anxiety. "
                 "However, persistent high heart rate at rest may indicate conditions like anxiety, dehydration, or heart problems.\n\n"
                 "If your elevated heart rate persists or is accompanied by chest pain or shortness of breath, seek medical attention.";
    } else {
      response += "Your heart rate is in the normal range of 60-100 BPM, which indicates efficient heart function at rest. "
                 "Heart rate naturally varies throughout the day based on activity, stress, and other factors.";
    }
    
    return "$response\n\nWould you like specific recommendations based on your heart rate?";
  }

  String _handleEcgStatus(EcgReading? reading) {
    if (reading == null) {
      return "I don't have any current ECG readings. Please ensure your monitoring device is connected and active.";
    }

    final patternStatus = _getEcgPatternStatus(reading);
    final bpm = reading.bpm;
    
    String interpretation = _getEcgInterpretation(reading);

    String response = "Your ECG pattern shows $patternStatus with a heart rate of ${bpm ?? 'unknown'} BPM.\n\n"
           "This suggests $interpretation.\n\n";
           
    // Add educational content about ECG patterns
    if (patternStatus.contains("irregularities")) {
      response += "ECG irregularities can result from various factors including:\n"
                 "• Normal variations unique to your heart\n"
                 "• Temporary changes due to stress or activity\n"
                 "• Electrical conduction variations\n"
                 "• Possible underlying heart conditions\n\n"
                 "It's important to discuss persistent irregularities with a healthcare provider.";
    } else if (patternStatus == "normal pattern") {
      response += "A normal ECG pattern indicates your heart's electrical system is functioning efficiently. "
                 "The ECG waveform consists of P waves (atrial contraction), QRS complex (ventricular contraction), "
                 "and T waves (ventricular relaxation) in a regular rhythm.";
    }
    
    return "$response\n\nWould you like to know more about ECG patterns or receive lifestyle recommendations?";
  }

  String _handleEmergencyResponse(EcgReading? reading) {
    String baseResponse = "⚠️ ATTENTION: Based on your message, you may need medical attention. Please seek immediate medical help or call emergency services.";
    
    // If there are reported critical symptoms, emphasize them
    if (_reportedSymptoms.intersection({"chest pain", "shortness of breath", "fainting"}).isNotEmpty) {
      String criticalSymptoms = _reportedSymptoms.intersection({"chest pain", "shortness of breath", "fainting"}).join(", ");
      baseResponse = "⚠️ URGENT: Your reported symptoms of $criticalSymptoms require immediate medical attention. Please call emergency services or go to the nearest emergency room.";
    }
    
    if (reading == null) {
      return baseResponse;
    }

    final bpm = reading.bpm;
    if (bpm == null) {
      return baseResponse;
    }

    if (bpm < 50 || bpm > 120) {
      return "⚠️ ATTENTION: Your heart rate of $bpm BPM is significantly outside the normal range. "
             "This could indicate a medical emergency. Please seek immediate medical attention. "
             "Would you like me to contact emergency services?";
    }

    return "I understand you're feeling unwell. Your current heart rate is $bpm BPM. "
           "If you're experiencing severe symptoms like chest pain, difficulty breathing, or severe dizziness, "
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
    
    if (bpm < minHeartRate) return "Your heart rate is below the typical resting range";
    if (bpm > maxHeartRate) return "Your heart rate is above the typical resting range";
    return "Your heart rate is within the normal resting range";
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
             "• Stay hydrated throughout the day\n"
             "• Monitor for symptoms of fatigue or dizziness\n"
             "• Ensure adequate nutrition with small, frequent meals";
    } else if (bpm > maxHeartRate) {
      return "• Practice deep breathing and relaxation techniques\n"
             "• Limit caffeine and stimulants\n"
             "• Take short rest breaks during activities\n"
             "• Monitor for symptoms like chest pain or shortness of breath";
    } else {
      return "• Maintain regular physical activity (150+ min/week)\n"
             "• Follow a heart-healthy diet rich in fruits and vegetables\n"
             "• Get 7-9 hours of quality sleep\n"
             "• Practice stress management techniques\n"
             "• Schedule regular check-ups with your healthcare provider";
    }
  }
  
  // Clear conversation context when needed
  void resetContext() {
    _lastTopic = null;
    _conversationContext.clear();
    _recentQueries.clear();
    _reportedSymptoms.clear();
    _sentimentScore = 0;
    _topicFrequency.clear();
  }
} 