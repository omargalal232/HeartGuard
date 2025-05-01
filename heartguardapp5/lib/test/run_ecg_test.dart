import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'ecg_model_test.dart' as ecg_test;

// A simple command-line runner for the ECG model tests
void main() async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  final logger = Logger();
  
  logger.i('Starting HeartGuard ECG model test suite...');
  logger.i('This will test the model with various ECG patterns.');
  logger.i('=============================================');
  
  // Run the tests - calling directly since main() doesn't return a value
  ecg_test.main();
  
  logger.i('=============================================');
  logger.i('Tests complete. Check the output for results.');
} 