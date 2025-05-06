class AppConstants {
  // Route definitions
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String homeRoute = '/home';
  static const String medicationsRoute = '/medications';
  static const String monitoringRoute = '/monitoring';
  static const String emergencyContactsRoute = '/emergency-contacts';
  static const String chatbotRoute = '/chatbot';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';

  // Firebase collections
  static const String usersCollection = 'users';
  static const String ecgReadingsCollection = 'ecg_readings';
  static const String emergencyContactsCollection = 'emergency_contacts';

  // Shared preferences keys
  static const String userIdKey = 'userId';
  static const String userEmailKey = 'userEmail';
  static const String isLoggedInKey = 'isLoggedIn';

  // App settings
  static const int ecgDataPointLimit = 100;
  static const Duration refreshInterval = Duration(seconds: 1);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // ECG Analysis Constants
  static const double normalEcgLowerBound = -0.5;
  static const double normalEcgUpperBound = 0.5;
  static const int minHeartRate = 60;
  static const int maxHeartRate = 100;
  static const Duration analysisInterval = Duration(minutes: 5);

  // Error messages
  static const String genericErrorMessage = 'An error occurred. Please try again.';
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String authErrorMessage = 'Authentication error. Please login again.';
  static const String loadingErrorMessage = 'Error loading data. Please try again.';
  static const String savingErrorMessage = 'Error saving data. Please try again.';

  // App configuration
  static const String appTitle = 'HeartGuard';
  static const String logoPath = 'assets/img/logo.png';
  static const String baseUrl = 'https://heart-guard-1c49e-default-rtdb.firebaseio.com';
  static const String firebaseServerKey = 'YOUR_FIREBASE_SERVER_KEY'; // Replace with actual key

  // Settings keys
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String locationEnabledKey = 'location_enabled';
  static const String languageKey = 'language';
  static const String smsEnabledKey = 'sms_enabled';

  // Additional routes
  static const String aboutRoute = '/about';
}