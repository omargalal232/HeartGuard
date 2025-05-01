import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
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
    _firebaseInitialized = true; // Set flag on success
    return app;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // If it's a duplicate app error, retrieve the existing instance
      _logger.w("Caught duplicate-app error, retrieving existing [DEFAULT] app.");
       _firebaseInitialized = true; // Also set flag here, as it *is* initialized
      return Firebase.app(); // Get the default instance
    } else {
      // Re-throw other Firebase exceptions
      _logger.e("Caught other FirebaseException during initialization.", error: e);
      rethrow;
    }
  } catch (e, stackTrace) {
    // Re-throw non-Firebase exceptions
     _logger.e("Caught generic exception during initialization.", error: e, stackTrace: stackTrace);
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only proceed if Firebase hasn't been initialized yet
  if (!_firebaseInitialized) {
    try {
      _logger.i("Attempting Firebase initialization sequence (flag check)...");
      await _initializeFirebase(); // Call the refined helper
      _logger.i("Firebase initialization sequence completed successfully.");
    } catch (e, stackTrace) {
      _logger.e(
        "!!!!!!!! FIREBASE INITIALIZATION FAILED (in main) !!!!!!!!",
        error: e,
        stackTrace: stackTrace,
      );
      // Stop execution if Firebase fails to initialize
      // Optionally, show an error screen
      // runApp(ErrorApp(errorMessage: e.toString())); 
      return; // Exit main if initialization fails critically
    }
  } else {
     _logger.i("Firebase initialization skipped (already initialized).");
  }
  
  // Always run the app after the initialization block
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
