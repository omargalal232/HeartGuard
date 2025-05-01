import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/tflite_service.dart';
import '../services/ecg_analysis_service.dart';

// This is a test utility for the HeartGuard ECG model integration
// Run this manually when needed to verify the model is working correctly

void main() async {
  // Initialize logger
  final logger = Logger();
  
  // Initialize services
  final tfliteService = TFLiteService();
  final ecgAnalysisService = ECGAnalysisService();
  
  // Wait for model to load
  WidgetsFlutterBinding.ensureInitialized();
  await tfliteService.initModel();
  
  // Log test header
  logger.i('=== HeartGuard ECG Model Integration Test ===');
  
  // Test 1: Normal ECG pattern
  await testECGPattern(
    'Normal Sinus Rhythm',
    generateNormalECGPattern(),
    tfliteService,
    ecgAnalysisService,
    expectedHighestClass: 'normal',
    logger: logger,
  );
  
  // Test 2: AFib pattern
  await testECGPattern(
    'Atrial Fibrillation',
    generateAFibPattern(),
    tfliteService,
    ecgAnalysisService,
    expectedHighestClass: 'afib',
    logger: logger,
  );
  
  // Test 3: Arrhythmia pattern
  await testECGPattern(
    'Arrhythmia',
    generateArrhythmiaPattern(),
    tfliteService,
    ecgAnalysisService,
    expectedHighestClass: 'arrhythmia',
    logger: logger,
  );
  
  // Test 4: Heart attack pattern
  await testECGPattern(
    'Heart Attack',
    generateHeartAttackPattern(),
    tfliteService,
    ecgAnalysisService,
    expectedHighestClass: 'heart_attack',
    logger: logger,
  );
  
  logger.i('=== All tests completed ===');
}

Future<void> testECGPattern(
  String patternName,
  List<double> ecgData,
  TFLiteService tfliteService,
  ECGAnalysisService ecgAnalysisService,
  {required String expectedHighestClass, 
   required Logger logger}
) async {
  logger.i('\nTesting $patternName pattern:');
  logger.i('- ECG data length: ${ecgData.length} samples');
  
  try {
    // Extract features from the ECG data
    final features = await ecgAnalysisService.extractFeatures(ecgData);
    logger.i('- Features extracted: ${features.keys.join(', ')}');
    
    // Run model inference
    final results = await tfliteService.runInference(features);
    logger.i('- Model results: ${results.toString()}');
    
    // Find highest probability class
    String highestClass = 'normal';
    double highestProb = results['normal'] ?? 0.0;
    
    for (final entry in results.entries) {
      if ((entry.value as double) > highestProb) {
        highestProb = entry.value;
        highestClass = entry.key;
      }
    }
    
    logger.i('- Highest probability class: $highestClass (${(highestProb * 100).toStringAsFixed(2)}%)');
    logger.i('- Expected class: $expectedHighestClass');
    
    // Check if prediction matches expected class
    if (highestClass == expectedHighestClass) {
      logger.i('✅ Test PASSED: Prediction matches expected class');
    } else {
      logger.e('❌ Test FAILED: Prediction does not match expected class');
    }
  } catch (e) {
    logger.e('❌ Test ERROR: $e');
  }
}

// Generate a normal ECG pattern
List<double> generateNormalECGPattern() {
  final random = Random();
  final List<double> ecgData = [];
  
  // Create a normal ECG pattern
  final normalPattern = [
    // P-wave
    0.0, 0.05, 0.1, 0.2, 0.25, 0.2, 0.1, 0.05, 0.0,
    // PR segment
    0.0, 0.0, 0.0,
    // QRS complex
    -0.1, -0.2, 1.8, 2.0, 0.5, 0.0,
    // ST segment
    0.0, 0.0, 0.0, 0.0,
    // T-wave
    0.05, 0.2, 0.4, 0.3, 0.1, 0.0,
    // TP segment
    0.0, 0.0, 0.0, 0.0, 0.0
  ];
  
  // Generate multiple cycles to achieve required length
  for (int cycle = 0; cycle < 10; cycle++) {
    for (int i = 0; i < normalPattern.length; i++) {
      // Add some realistic variability
      final noise = random.nextDouble() * 0.05 - 0.025;
      ecgData.add(normalPattern[i] + noise);
    }
  }
  
  return ecgData;
}

// Generate an atrial fibrillation pattern
List<double> generateAFibPattern() {
  final random = Random();
  final List<double> ecgData = [];
  
  // AFib characteristics: Absence of P waves, irregular RR intervals
  for (int i = 0; i < 500; i++) {
    double value = 0.0;
    
    // Create fibrillatory baseline (replacing P waves)
    if (i % 30 < 10) {
      // Fibrillatory waves - small, rapid, chaotic oscillations
      value = (random.nextDouble() * 0.2 - 0.1);
    } 
    // QRS complex - still present in AFib but at irregular intervals
    else if (i % 30 == 11 && random.nextDouble() > 0.2) {
      value = -0.2;
    }
    else if (i % 30 == 12 && random.nextDouble() > 0.2) {
      value = -0.3;
    }
    else if (i % 30 == 13 && random.nextDouble() > 0.2) {
      value = 1.5;
    }
    else if (i % 30 == 14 && random.nextDouble() > 0.2) {
      value = 0.3;
    }
    // T wave
    else if (i % 30 == 18 && random.nextDouble() > 0.3) {
      value = 0.2;
    }
    else if (i % 30 == 19 && random.nextDouble() > 0.3) {
      value = 0.3;
    }
    else if (i % 30 == 20 && random.nextDouble() > 0.3) {
      value = 0.1;
    }
    else {
      value = random.nextDouble() * 0.05 - 0.025;
    }
    
    // Occasionally skip some points to create irregular rhythm
    if (random.nextDouble() > 0.95) {
      i += random.nextInt(3) + 1;
    }
    
    ecgData.add(value);
  }
  
  return ecgData;
}

// Generate an arrhythmia pattern (premature ventricular contractions)
List<double> generateArrhythmiaPattern() {
  final random = Random();
  final List<double> ecgData = [];
  
  // Normal pattern
  final normalPattern = [
    // P-wave
    0.0, 0.05, 0.1, 0.2, 0.25, 0.2, 0.1, 0.05, 0.0,
    // PR segment
    0.0, 0.0, 0.0,
    // QRS complex
    -0.1, -0.2, 1.8, 2.0, 0.5, 0.0,
    // ST segment
    0.0, 0.0, 0.0, 0.0,
    // T-wave
    0.05, 0.2, 0.4, 0.3, 0.1, 0.0,
    // TP segment
    0.0, 0.0, 0.0, 0.0, 0.0
  ];
  
  // PVC pattern (premature ventricular contraction)
  final pvcPattern = [
    // No P-wave in PVCs
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    // No PR segment
    0.0, 0.0, 0.0,
    // Wide QRS complex (characteristic of PVC)
    -0.3, -0.5, -1.0, 2.5, 2.0, 1.5, 1.0, 0.5, 0.0,
    // ST segment
    0.0, 0.0, 0.0, 0.0,
    // T-wave (often in opposite direction)
    -0.1, -0.3, -0.5, -0.3, -0.1, 0.0,
    // Compensatory pause
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
  ];
  
  // Generate rhythm with occasional PVCs
  for (int cycle = 0; cycle < 10; cycle++) {
    // Choose pattern based on probability
    final isPVC = random.nextDouble() < 0.3; // 30% chance of PVC
    final pattern = isPVC ? pvcPattern : normalPattern;
    
    for (int i = 0; i < pattern.length; i++) {
      final noise = random.nextDouble() * 0.05 - 0.025;
      ecgData.add(pattern[i] + noise);
    }
  }
  
  return ecgData;
}

// Generate a heart attack pattern (ST elevation myocardial infarction)
List<double> generateHeartAttackPattern() {
  final random = Random();
  final List<double> ecgData = [];
  
  // STEMI characteristics: ST elevation, abnormal Q waves
  final stemiPattern = [
    // P-wave (may be normal)
    0.0, 0.05, 0.1, 0.2, 0.25, 0.2, 0.1, 0.05, 0.0,
    // PR segment
    0.0, 0.0, 0.0,
    // QRS with pathological Q wave
    -0.4, -0.6, -0.4, 1.6, 1.8, 0.4, 0.0,
    // Elevated ST segment - key STEMI feature
    0.3, 0.4, 0.5, 0.5,
    // T-wave changes
    0.5, 0.3, 0.2, 0.1, 0.0,
    // TP segment
    0.0, 0.0, 0.0, 0.0
  ];
  
  // Generate multiple cycles
  for (int cycle = 0; cycle < 10; cycle++) {
    for (int i = 0; i < stemiPattern.length; i++) {
      final noise = random.nextDouble() * 0.05 - 0.025;
      ecgData.add(stemiPattern[i] + noise);
    }
  }
  
  return ecgData;
} 