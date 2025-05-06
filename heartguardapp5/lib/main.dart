import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:heartguardapp05/providers/theme_provider.dart';
import 'package:heartguardapp05/navigation/app_router.dart';
import 'package:heartguardapp05/constants/app_constants.dart';
import 'package:heartguardapp05/services/logger_service.dart';
import 'firebase_options.dart';

// Initialize logger
final _logger = LoggerService();

// Static flag to track Firebase initialization status
bool _firebaseInitialized = false;

// Refined helper function for Firebase initialization
Future<FirebaseApp> _initializeFirebase() async {
  // Check the flag first
  if (_firebaseInitialized) {
    _logger.i("Firebase already initialized (checked by flag), returning existing app.");
    return Firebase.app();
  }
  
  try {
    // Try initializing normally
    _logger.i("Attempting Firebase.initializeApp...");
    FirebaseApp app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize AppCheck after Firebase
    _logger.i("Initializing Firebase AppCheck...");
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('6LfXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    _firebaseInitialized = true; // Set flag on success
    _logger.i("Firebase initialized successfully");
    return app;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // If it's a duplicate app error, retrieve the existing instance
      _logger.w("Caught duplicate-app error, retrieving existing [DEFAULT] app.");
      _firebaseInitialized = true; // Also set flag here, as it *is* initialized
      return Firebase.app(); // Get the default instance
    } else {
      // Re-throw other Firebase exceptions
      _logger.e("Caught other FirebaseException during initialization: ${e.toString()}");
      rethrow;
    }
  } catch (e, stackTrace) {
    // Re-throw non-Firebase exceptions
    _logger.e("Caught generic exception during initialization: ${e.toString()}\nStack trace: ${stackTrace.toString()}");
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    _logger.i("Starting Firebase initialization sequence...");
    await _initializeFirebase();
    _logger.i("Firebase initialization completed successfully");
  } catch (e, stackTrace) {
    _logger.e(
      "!!!!!!!! FIREBASE INITIALIZATION FAILED !!!!!!!!\nError: ${e.toString()}\nStack trace: ${stackTrace.toString()}"
    );
    // Don't exit, but show an error screen
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Firebase initialization failed: ${e.toString()}'),
        ),
      ),
    ));
    return;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConstants.appTitle,
            theme: themeProvider.currentTheme,
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: AppConstants.loginRoute,
          );
        },
      ),
    );
  }
}
