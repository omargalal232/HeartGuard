import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/logger_service.dart';

final Logger _logger = Logger();
const String _tag = 'AppInitializer';

class AppInitializer {
  static Future<void> initialize() async {
    try {
      // Initialize Flutter bindings
      WidgetsFlutterBinding.ensureInitialized();
      
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Set system overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      
      // Initialize Firebase
      await _initializeFirebase();
      
      _logger.logI(_tag, 'App initialized successfully');
    } catch (e, stackTrace) {
      _logger.logE(_tag, 'Error initializing app', e, stackTrace);
      rethrow;
    }
  }

  static Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _logger.logI(_tag, 'Firebase initialized successfully');
      } else {
        _logger.logI(_tag, 'Firebase already initialized');
      }
    } catch (e, stackTrace) {
      _logger.logE(_tag, 'Error initializing Firebase', e, stackTrace);
      rethrow;
    }
  }
} 