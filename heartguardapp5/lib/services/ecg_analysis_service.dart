import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import 'package:logger/logger.dart' as logger;
import 'package:flutter/foundation.dart';

class ECGAnalysisService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = logger.Logger();

  // Extract features from ECG signal with error handling
  Future<Map<String, dynamic>> extractFeatures(List<double> ecgSignal) async {
    try {
      _logger.i('Extracting features from ECG signal of length ${ecgSignal.length}');

      // Get heart rate from RR intervals
      final rPeaks = _detectRPeaks(ecgSignal);
      final rrIntervals = _calculateRRIntervals(rPeaks);
      final heartRate = _calculateHeartRate(rrIntervals);
      
      // Calculate heart rate variability metrics
      final hrv = _calculateHRV(rrIntervals);
      
      // Extract QRS complex features
      final qrsFeatures = _analyzeQRSComplex(ecgSignal, rPeaks);
      
      // Extract ST segment features
      final stFeatures = _analyzeSTSegment(ecgSignal, rPeaks);
      
      // Return all features
      return {
        'heartRate': heartRate,
        'hrv': hrv,
        'qrsDuration': qrsFeatures['duration'],
        'qrsAmplitude': qrsFeatures['amplitude'],
        'stElevation': stFeatures['elevation'],
        'stSlope': stFeatures['slope'],
        'rrIntervals': rrIntervals,
        'rPeaks': rPeaks,
      };
    } catch (e) {
      _logger.e('Error extracting ECG features: $e');
      debugPrint('Error in ECG feature extraction: $e');
      
      // Return default values instead of null to prevent crashes
      return {
        'heartRate': 70.0,
        'hrv': {'sdnn': 50.0, 'rmssd': 30.0},
        'qrsDuration': 100.0,
        'qrsAmplitude': 1.0,
        'stElevation': 0.0,
        'stSlope': 0.0,
        'rrIntervals': <double>[],
        'rPeaks': <int>[],
      };
    }
  }

  // Detect R-peaks in ECG signal
  List<int> _detectRPeaks(List<double> ecgSignal) {
    try {
      if (ecgSignal.isEmpty) return [];
      
      // Simple peak detection algorithm
      final List<int> peaks = [];
      final windowSize = 25; // Window size to detect local maxima
      
      // Need at least 2*windowSize points for peak detection
      if (ecgSignal.length < 2 * windowSize) {
        // If signal is too short, just find the global maximum
        int maxIndex = 0;
        double maxValue = ecgSignal[0];
        
        for (int i = 1; i < ecgSignal.length; i++) {
          if (ecgSignal[i] > maxValue) {
            maxValue = ecgSignal[i];
            maxIndex = i;
          }
        }
        
        if (maxValue > 0.5) { // Simple threshold
          peaks.add(maxIndex);
        }
        
        return peaks;
      }
      
      // Moving average filter to remove noise
      final filtered = _applyMovingAverage(ecgSignal, 5);
      
      // Find local maxima (potential R peaks)
      for (int i = windowSize; i < filtered.length - windowSize; i++) {
        bool isPeak = true;
        
        // Check if this is a local maximum
        for (int j = i - windowSize; j < i; j++) {
          if (filtered[j] > filtered[i]) {
            isPeak = false;
            break;
          }
        }
        
        for (int j = i + 1; j < i + windowSize; j++) {
          if (filtered[j] > filtered[i]) {
            isPeak = false;
            break;
          }
        }
        
        // Amplitude threshold to filter out smaller peaks
        if (isPeak && filtered[i] > 0.5) {
          peaks.add(i);
          i += windowSize ~/ 2; // Skip forward to avoid detecting same peak
        }
      }
      
      return peaks;
    } catch (e) {
      _logger.e('Error detecting R peaks: $e');
      return [];
    }
  }
  
  // Apply moving average filter to smooth signal
  List<double> _applyMovingAverage(List<double> signal, int windowSize) {
    final filtered = List<double>.from(signal);
    
    for (int i = windowSize; i < signal.length - windowSize; i++) {
      double sum = 0;
      for (int j = i - windowSize; j <= i + windowSize; j++) {
        sum += signal[j];
      }
      filtered[i] = sum / (2 * windowSize + 1);
    }
    
    return filtered;
  }
  
  // Calculate RR intervals from R peaks
  List<double> _calculateRRIntervals(List<int> rPeaks) {
    final List<double> rrIntervals = [];
    
    // Need at least 2 peaks to calculate intervals
    if (rPeaks.length < 2) return rrIntervals;
    
    for (int i = 1; i < rPeaks.length; i++) {
      rrIntervals.add((rPeaks[i] - rPeaks[i-1]).toDouble());
    }
    
    return rrIntervals;
  }
  
  // Calculate heart rate from RR intervals
  double _calculateHeartRate(List<double> rrIntervals) {
    // If no RR intervals, return a default value
    if (rrIntervals.isEmpty) return 70.0;
    
    // Calculate average RR interval in samples
    double avgRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    
    // Convert to BPM (assuming 250 Hz sampling rate)
    return (60 * 250) / avgRR;
  }
  
  // Calculate heart rate variability metrics
  Map<String, double> _calculateHRV(List<double> rrIntervals) {
    if (rrIntervals.length < 2) {
      return {'sdnn': 50.0, 'rmssd': 30.0};
    }
    
    // SDNN - Standard deviation of NN intervals
    double mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    double sumSquaredDiff = 0;
    
    for (final interval in rrIntervals) {
      sumSquaredDiff += pow(interval - mean, 2);
    }
    
    double sdnn = sqrt(sumSquaredDiff / rrIntervals.length);
    
    // RMSSD - Root mean square of successive differences
    double sumSquaredSuccDiff = 0;
    for (int i = 1; i < rrIntervals.length; i++) {
      sumSquaredSuccDiff += pow(rrIntervals[i] - rrIntervals[i-1], 2);
    }
    
    double rmssd = sqrt(sumSquaredSuccDiff / (rrIntervals.length - 1));
    
    return {'sdnn': sdnn, 'rmssd': rmssd};
  }
  
  // Analyze QRS complex
  Map<String, double> _analyzeQRSComplex(List<double> ecgSignal, List<int> rPeaks) {
    // Default values if analysis fails
    double qrsDuration = 100.0; // in ms (assuming 250 Hz)
    double qrsAmplitude = 1.0; // in mV
    
    // Need ECG signal and R peaks
    if (ecgSignal.isEmpty || rPeaks.isEmpty) {
      return {'duration': qrsDuration, 'amplitude': qrsAmplitude};
    }
    
    try {
      // For simplicity, analyze QRS around first R peak
      int peakIndex = rPeaks[0];
      
      // Make sure we have enough signal around the peak
      if (peakIndex < 10 || peakIndex >= ecgSignal.length - 10) {
        return {'duration': qrsDuration, 'amplitude': qrsAmplitude};
      }
      
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
      
      return {'duration': qrsDuration, 'amplitude': qrsAmplitude};
    } catch (e) {
      _logger.e('Error analyzing QRS complex: $e');
      return {'duration': qrsDuration, 'amplitude': qrsAmplitude};
    }
  }
  
  // Analyze ST segment
  Map<String, double> _analyzeSTSegment(List<double> ecgSignal, List<int> rPeaks) {
    // Default values
    double stElevation = 0.0; // in mV
    double stSlope = 0.0; // in mV/sample
    
    // Need ECG signal and R peaks
    if (ecgSignal.isEmpty || rPeaks.isEmpty) {
      return {'elevation': stElevation, 'slope': stSlope};
    }
    
    try {
      // For simplicity, analyze ST around first R peak
      int peakIndex = rPeaks[0];
      
      // Make sure we have enough signal after the peak
      if (peakIndex >= ecgSignal.length - 30) {
        return {'elevation': stElevation, 'slope': stSlope};
      }
      
      // Find S point (local minimum after R)
      int sPoint = peakIndex;
      for (int i = peakIndex + 1; i < peakIndex + 10; i++) {
        if (ecgSignal[i] < ecgSignal[sPoint]) {
          sPoint = i;
        }
      }
      
      // ST segment starts after S point
      int stStart = sPoint + 2;
      int stEnd = stStart + 10; // Approximate end of ST segment
      
      // Calculate ST elevation relative to baseline
      // For simplicity, using a point before P wave as baseline
      double baseline = 0.0;
      if (peakIndex > 30) {
        baseline = ecgSignal[peakIndex - 30];
      }
      
      stElevation = ecgSignal[stStart] - baseline;
      
      // Calculate ST slope
      stSlope = (ecgSignal[stEnd] - ecgSignal[stStart]) / (stEnd - stStart);
      
      return {'elevation': stElevation, 'slope': stSlope};
    } catch (e) {
      _logger.e('Error analyzing ST segment: $e');
      return {'elevation': stElevation, 'slope': stSlope};
    }
  }

  // Send ECG data to AI model for analysis
  Future<Map<String, dynamic>> analyzeECG(List<double> ecgSignal) async {
    try {
      // Extract features
      final features = await extractFeatures(ecgSignal);
      
      // Prepare data for AI model
      final analysisData = {
        'features': features,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Call AI analysis API
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/ecg-analysis'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.firebaseServerKey}',
        },
        body: analysisData,
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to analyze ECG: ${response.body}');
      }
      
      final analysis = response.body;
      
      // Save analysis results
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .collection('ecg_analysis')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'analysis': analysis,
          'features': features,
          'rawSignal': ecgSignal,
        });
      }
      
      return {
        'analysis': analysis,
        'features': features,
        'isCritical': _isCriticalCondition(analysis),
      };
    } catch (e) {
      _logger.e('Error in ECG analysis: $e');
      rethrow;
    }
  }

  bool _isCriticalCondition(String analysis) {
    // Implement critical condition detection based on AI analysis
    return analysis.toLowerCase().contains('critical') ||
           analysis.toLowerCase().contains('emergency') ||
           analysis.toLowerCase().contains('urgent');
  }

  // Get ECG analysis history
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection('ecg_analysis')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('Error getting ECG analysis history: $e');
      return [];
    }
  }
} 