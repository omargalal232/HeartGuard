import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import '../models/profile_model.dart';
import '../models/ecg_reading.dart';

/// Service for predicting heart disease risk using the ML model
class HeartDiseasePredictionService {
  static final HeartDiseasePredictionService _instance = HeartDiseasePredictionService._internal();
  
  // Singleton pattern
  factory HeartDiseasePredictionService() => _instance;
  
  HeartDiseasePredictionService._internal() {
    _initialize();
  }
  
  final _logger = Logger();
  bool _modelLoaded = false;
  Interpreter? _interpreter;
  Map<String, dynamic>? _modelMetadata;
  Map<String, dynamic>? _normalizationParams;
  
  // Initialize the service
  Future<void> _initialize() async {
    try {
      // Load model metadata
      await _loadModelMetadata();
      // Load the TFLite model
      await _loadModel();
    } catch (e) {
      _logger.e('Failed to initialize heart disease prediction service: $e');
    }
  }
  
  Future<void> _loadModelMetadata() async {
    try {
      final metadataFile = await rootBundle.loadString('assets/models/model_metadata.json');
      _modelMetadata = json.decode(metadataFile);
      _normalizationParams = _modelMetadata?['normalization'];
      _logger.i('Model metadata loaded successfully');
    } catch (e) {
      _logger.e('Failed to load model metadata: $e');
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    try {
      // Load the TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/ecg_model.tflite');
      _modelLoaded = true;
      _logger.i('Heart disease prediction model loaded successfully');
    } catch (e) {
      _logger.e('Failed to load heart disease prediction model: $e');
      _modelLoaded = false;
    }
  }
  
  /// Generate heart disease risk prediction based on patient profile and ECG reading
  Future<Map<String, dynamic>> predictHeartDiseaseRisk(
    ProfileModel profile, 
    EcgReading ecgReading
  ) async {
    try {
      // If model is not loaded, try loading it
      if (!_modelLoaded) {
        await _loadModel();
        // If still not loaded, return default values
        if (!_modelLoaded) {
          return _getDefaultResults('Model not loaded');
        }
      }
      
      // Extract features from profile and ECG reading
      final features = await _extractFeatures(profile, ecgReading);
      
      // Prepare input tensor for the model
      final inputTensor = _prepareInputTensor(features);
      
      // Prepare output tensor
      var outputBuffer = List<List<double>>.filled(
        1, 
        List<double>.filled(4, 0.0)
      );
      
      // Run inference
      try {
        _interpreter!.run(inputTensor, outputBuffer);
        
        // Process results
        final results = {
          'normal': outputBuffer[0][0],
          'arrhythmia': outputBuffer[0][1],
          'afib': outputBuffer[0][2],
          'heart_attack': outputBuffer[0][3],
          'timestamp': DateTime.now().millisecondsSinceEpoch
        };
        
        // Calculate overall risk score (0-100)
        final riskScore = _calculateRiskScore(results);
        results['risk_score'] = riskScore;
        
        return results;
      } catch (e) {
        _logger.e('Error running model inference: $e');
        return _getDefaultResults('Inference error');
      }
    } catch (e) {
      _logger.e('Error in heart disease prediction: $e');
      return _getDefaultResults('Prediction error');
    }
  }
  
  Future<Map<String, dynamic>> _extractFeatures(ProfileModel profile, EcgReading ecgReading) async {
    final features = <String, dynamic>{};
    
    // Add heart rate from ECG reading
    features['heartRate'] = ecgReading.bpm ?? 75.0;
    
    // Calculate HRV (Heart Rate Variability) from ECG data if available
    if (ecgReading.hasValidData && ecgReading.values != null && ecgReading.values!.isNotEmpty) {
      features['hrv'] = _calculateHRV(ecgReading.values!);
    } else {
      // Default HRV values
      features['hrv'] = {'sdnn': 50.0, 'rmssd': 30.0};
    }
    
    // Extract QRS complex features if ECG data is available
    if (ecgReading.hasValidData && ecgReading.values != null && ecgReading.values!.isNotEmpty) {
      final qrsFeatures = _analyzeQRSComplex(ecgReading.values!);
      features['qrsDuration'] = qrsFeatures['duration'];
      features['qrsAmplitude'] = qrsFeatures['amplitude'];
    } else {
      features['qrsDuration'] = 100.0; // Default 100ms
      features['qrsAmplitude'] = 1.0; // Default 1mv
    }
    
    // Get ST segment features if ECG data is available
    if (ecgReading.hasValidData && ecgReading.values != null && ecgReading.values!.isNotEmpty) {
      final stFeatures = _analyzeSTSegment(ecgReading.values!);
      features['stElevation'] = stFeatures['elevation'];
      features['stSlope'] = stFeatures['slope'];
    } else {
      features['stElevation'] = 0.0;
      features['stSlope'] = 0.0;
    }
    
    return features;
  }
  
  Map<String, double> _calculateHRV(List<double> ecgValues) {
    // Simple HRV calculation - in real app, this would be more sophisticated
    double sdnn = 50.0; // Default value
    double rmssd = 30.0; // Default value
    
    try {
      // Find R-peaks for analysis
      final rPeaks = _findRPeaks(ecgValues);
      
      if (rPeaks.length > 3) {
        // Calculate RR intervals in milliseconds
        List<double> rrIntervals = [];
        for (int i = 1; i < rPeaks.length; i++) {
          // Assuming 250Hz sampling rate
          double rrMs = (rPeaks[i] - rPeaks[i-1]) * (1000 / 250);
          rrIntervals.add(rrMs);
        }
        
        // Calculate SDNN (Standard deviation of NN intervals)
        double mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
        double sumSquared = rrIntervals.fold(0.0, (sum, item) => sum + (item - mean) * (item - mean));
        sdnn = (sumSquared / rrIntervals.length).abs();
        
        // Calculate RMSSD (Root Mean Square of Successive Differences)
        double sumSquaredDiff = 0;
        for (int i = 1; i < rrIntervals.length; i++) {
          sumSquaredDiff += (rrIntervals[i] - rrIntervals[i-1]) * (rrIntervals[i] - rrIntervals[i-1]);
        }
        rmssd = (sumSquaredDiff / (rrIntervals.length - 1)).abs();
      }
    } catch (e) {
      _logger.e('Error calculating HRV: $e');
    }
    
    return {'sdnn': sdnn, 'rmssd': rmssd};
  }
  
  Map<String, double> _analyzeQRSComplex(List<double> ecgSignal) {
    // Default values if analysis fails
    double qrsDuration = 100.0; // in ms (assuming 250 Hz)
    double qrsAmplitude = 1.0; // in mV
    
    try {
      // Find R peaks for analysis
      List<int> rPeaks = _findRPeaks(ecgSignal);
      
      if (rPeaks.isNotEmpty) {
        // For simplicity, analyze QRS around first R peak
        int peakIndex = rPeaks[0];
        
        // Make sure we have enough signal around the peak
        if (peakIndex >= 10 && peakIndex < ecgSignal.length - 10) {
          // Find Q point - look for local minimum before R
          int qPoint = peakIndex;
          for (int i = peakIndex - 1; i >= peakIndex - 10; i--) {
            if (ecgSignal[i] < ecgSignal[qPoint]) {
              qPoint = i;
            }
          }
          
          // Find S point - local minimum after R
          int sPoint = peakIndex;
          for (int i = peakIndex + 1; i < peakIndex + 10; i++) {
            if (ecgSignal[i] < ecgSignal[sPoint]) {
              sPoint = i;
            }
          }
          
          // Calculate QRS duration in milliseconds (assuming 250Hz sampling)
          qrsDuration = (sPoint - qPoint) * (1000 / 250);
          
          // Calculate QRS amplitude (R wave height)
          qrsAmplitude = ecgSignal[peakIndex];
        }
      }
    } catch (e) {
      _logger.e('Error analyzing QRS complex: $e');
    }
    
    return {'duration': qrsDuration, 'amplitude': qrsAmplitude};
  }
  
  Map<String, double> _analyzeSTSegment(List<double> ecgSignal) {
    // Default values
    double stElevation = 0.0; // in mV
    double stSlope = 0.0; // in mV/sample
    
    try {
      // Find R peaks for analysis
      List<int> rPeaks = _findRPeaks(ecgSignal);
      
      if (rPeaks.isNotEmpty) {
        // For simplicity, analyze ST around first R peak
        int peakIndex = rPeaks[0];
        
        // Make sure we have enough signal after the peak
        if (peakIndex < ecgSignal.length - 30) {
          // Find S point (local minimum after R)
          int sPoint = peakIndex;
          for (int i = peakIndex + 1; i < peakIndex + 10; i++) {
            if (i < ecgSignal.length && ecgSignal[i] < ecgSignal[sPoint]) {
              sPoint = i;
            }
          }
          
          // ST segment starts after S point
          int stStart = sPoint + 2;
          int stEnd = stStart + 10; // Approximate end of ST segment
          
          if (stEnd < ecgSignal.length) {
            // Calculate ST elevation relative to baseline
            // For simplicity, using a point before P wave as baseline
            double baseline = 0.0;
            if (peakIndex > 30) {
              baseline = ecgSignal[peakIndex - 30];
            }
            
            stElevation = ecgSignal[stStart] - baseline;
            
            // Calculate ST slope
            stSlope = (ecgSignal[stEnd] - ecgSignal[stStart]) / (stEnd - stStart);
          }
        }
      }
    } catch (e) {
      _logger.e('Error analyzing ST segment: $e');
    }
    
    return {'elevation': stElevation, 'slope': stSlope};
  }
  
  List<int> _findRPeaks(List<double> ecgSignal) {
    List<int> rPeaks = [];
    
    try {
      // Simple R-peak detection algorithm
      double threshold = 0.7; // Adjust as needed
      
      // Find the maximum value for threshold calculation
      double maxVal = ecgSignal.reduce((curr, next) => curr > next ? curr : next);
      threshold *= maxVal;
      
      // Find peaks above threshold
      for (int i = 1; i < ecgSignal.length - 1; i++) {
        if (ecgSignal[i] > threshold && 
            ecgSignal[i] > ecgSignal[i-1] && 
            ecgSignal[i] > ecgSignal[i+1]) {
          rPeaks.add(i);
        }
      }
    } catch (e) {
      _logger.e('Error finding R-peaks: $e');
    }
    
    return rPeaks;
  }

  List<List<double>> _prepareInputTensor(Map<String, dynamic> features) {
    // Convert features to flattened tensor format
    final inputFeatures = <double>[];
    
    try {
      // Function to normalize a value using mean and standard deviation
      double normalize(double value, String featureName) {
        if (_normalizationParams != null && _normalizationParams!.containsKey(featureName)) {
          final mean = _normalizationParams![featureName]['mean'] as double;
          final std = _normalizationParams![featureName]['std'] as double;
          return (value - mean) / std;
        } else {
          // Default normalization
          return value / 100.0;
        }
      }
      
      // Add heart rate (normalized)
      final heartRate = features['heartRate'] ?? 70.0;
      inputFeatures.add(normalize(
        heartRate is int ? heartRate.toDouble() : heartRate, 
        'heart_rate'
      ));
      
      // Add HRV features (normalized)
      final hrv = features['hrv'] as Map<String, dynamic>? ?? {'sdnn': 50.0, 'rmssd': 30.0};
      final sdnn = hrv['sdnn'] ?? 50.0;
      final rmssd = hrv['rmssd'] ?? 30.0;
      inputFeatures.add(normalize(
        sdnn is int ? sdnn.toDouble() : sdnn, 
        'hrv_sdnn'
      ));
      inputFeatures.add(normalize(
        rmssd is int ? rmssd.toDouble() : rmssd,
        'hrv_rmssd'
      ));
      
      // Add QRS features (normalized)
      final qrsDuration = features['qrsDuration'] ?? 100.0;
      final qrsAmplitude = features['qrsAmplitude'] ?? 1.0;
      inputFeatures.add(normalize(
        qrsDuration is int ? qrsDuration.toDouble() : qrsDuration,
        'qrs_duration'
      ));
      inputFeatures.add(normalize(
        qrsAmplitude is int ? qrsAmplitude.toDouble() : qrsAmplitude,
        'qrs_amplitude'
      ));
      
      // Add ST segment features (normalized)
      final stElevation = features['stElevation'] ?? 0.0;
      final stSlope = features['stSlope'] ?? 0.0;
      inputFeatures.add(normalize(
        stElevation is int ? stElevation.toDouble() : stElevation,
        'st_elevation'
      ));
      inputFeatures.add(normalize(
        stSlope is int ? stSlope.toDouble() : stSlope,
        'st_slope'
      ));
    } catch (e) {
      _logger.e('Error preparing input tensor: $e');
      // If there's an error, use default values
      inputFeatures.clear();
      inputFeatures.addAll([0.35, 0.5, 0.3, 0.5, 0.5, 0.0, 0.0]); // Default normalized values
    }
    
    // Ensure we have exactly 7 features
    while (inputFeatures.length < 7) {
      inputFeatures.add(0.0);
    }
    
    // Trim the list if it's longer than expected
    if (inputFeatures.length > 7) {
      inputFeatures.length = 7;
    }
    
    // Return in the format expected by TFLite (batch size 1)
    return [inputFeatures];
  }
  
  double _calculateRiskScore(Map<String, dynamic> results) {
    // Calculate risk score from model outputs
    // Higher weights for serious conditions
    double score = 
      (results['arrhythmia'] ?? 0) * 30 + 
      (results['afib'] ?? 0) * 70 + 
      (results['heart_attack'] ?? 0) * 100;
    
    // Ensure score is between 0-100
    return score.clamp(0, 100);
  }
  
  Map<String, dynamic> _getDefaultResults(String errorMessage) {
    return {
      'normal': 0.95,
      'arrhythmia': 0.03,
      'afib': 0.01,
      'heart_attack': 0.01,
      'risk_score': 5.0,
      'error': errorMessage,
    };
  }
  
  /// Returns true if the model is loaded and ready for predictions
  bool isModelLoaded() => _modelLoaded;
  
  /// Reload the model if needed
  Future<bool> reloadModel() async {
    await _loadModel();
    return _modelLoaded;
  }
  
  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _modelLoaded = false;
  }
} 