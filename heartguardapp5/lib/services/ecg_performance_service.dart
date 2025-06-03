import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as logger;

import '../models/ecg_data_model.dart';
import 'tflite_service.dart';

/// High-performance service for ECG data fetching, caching, and analysis.
class ECGPerformanceService {
  static final ECGPerformanceService _instance = ECGPerformanceService._internal();
  
  // Singleton pattern
  factory ECGPerformanceService() => _instance;
  
  ECGPerformanceService._internal() {
    _initialize();
  }
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final _logger = logger.Logger();
  final TFLiteService _tfliteService = TFLiteService();
  
  // Performance tracking
  DateTime? _lastFetchTime;
  int _hitCount = 0;
  int _missCount = 0;
  
  // Add a stream controller to broadcast analysis results
  final _analysisResultController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get analysisResults => _analysisResultController.stream;
  
  // Data cache with expiration
  final Map<String, ECGDataModel> _cache = {};
  final Map<String, DateTime> _cacheTimes = {};
  final Duration _cacheExpiration = const Duration(minutes: 10);
  
  // Analysis cache to prevent frequent reanalysis
  final Map<String, Map<String, dynamic>> _analysisCache = {};
  final Map<String, DateTime> _analysisTimes = {};
  final Duration _analysisExpiration = const Duration(minutes: 5);
  
  // Subscriptions management
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Initialize the service
  Future<void> _initialize() async {
    try {
      await _tfliteService.initModel();
      _logger.i('ECGPerformanceService initialized with TFLite model');
    } catch (e) {
      _logger.e('Failed to initialize ECGPerformanceService: $e');
    }
  }
  
  /// Get ECG data for a specific user, with efficient caching
  Future<ECGDataModel?> getECGData({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user');
      return null;
    }
    
    final userId = user.uid;
    
    // Check cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedData = _getCachedData(userId);
      if (cachedData != null) {
        _hitCount++;
        _logger.d('Cache hit! Hit rate: ${(_hitCount / (_hitCount + _missCount) * 100).toStringAsFixed(1)}%');
        return cachedData;
      }
      _missCount++;
    }
    
    _lastFetchTime = DateTime.now();
    
    try {
      // Try realtime_ecg path first (device data)
      final realtimeRef = _database.ref()
          .child('users')
          .child(userId)
          .child('realtime_ecg');
          
      final realtimeSnapshot = await realtimeRef.get();
      
      if (realtimeSnapshot.exists && realtimeSnapshot.value != null) {
        final data = _parseECGSnapshot(realtimeSnapshot);
        if (data != null) {
          _cacheData(userId, data);
          return data;
        }
      }
      
      // Try standard ecg_data path next
      final standardRef = _database.ref()
          .child('users')
          .child(userId)
          .child('ecg_data')
          .child('latest');
          
      final standardSnapshot = await standardRef.get();
      
      if (standardSnapshot.exists && standardSnapshot.value != null) {
        final data = _parseECGSnapshot(standardSnapshot);
        if (data != null) {
          _cacheData(userId, data);
          return data;
        }
      }
      
      _logger.w('No ECG data found for user $userId');
      return null;
    } catch (e) {
      _logger.e('Error fetching ECG data: $e');
      return null;
    } finally {
      if (_lastFetchTime != null) {
        final fetchDuration = DateTime.now().difference(_lastFetchTime!);
        _logger.d('ECG data fetch took ${fetchDuration.inMilliseconds}ms');
      }
    }
  }
  
  /// Set up real-time listener for ECG updates with throttling
  StreamSubscription? listenToECGUpdates(
    Function(ECGDataModel?) onDataUpdate,
    {Duration throttle = const Duration(milliseconds: 500)}
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user for ECG updates');
      return null;
    }
    
    final userId = user.uid;
    
    // Cancel existing subscription if any
    _subscriptions[userId]?.cancel();
    
    try {
      // Setup throttling variables
      DateTime lastUpdate = DateTime.now();
      ECGDataModel? lastData;
      bool hasPendingUpdate = false;
      
      // Create reference to the data
      final ecgRef = _database.ref()
          .child('users')
          .child(userId)
          .child('ecg_data')
          .child('latest');
      
      // Set up the listener with throttling
      final subscription = ecgRef.onValue.listen((event) {
        final now = DateTime.now();
        final data = _parseECGSnapshot(event.snapshot);
        
        // Store for potential throttled update
        lastData = data;
        
        // Check if we should throttle
        if (now.difference(lastUpdate) < throttle) {
          if (!hasPendingUpdate) {
            hasPendingUpdate = true;
            
            // Schedule an update after throttle duration
            Future.delayed(throttle, () {
              onDataUpdate(lastData);
              lastUpdate = DateTime.now();
              hasPendingUpdate = false;
            });
          }
          return;
        }
        
        // No throttling needed, update immediately
        onDataUpdate(data);
        lastUpdate = now;
      }, onError: (error) {
        _logger.e('Error in ECG data listener: $error');
        onDataUpdate(null);
      });
      
      _subscriptions[userId] = subscription;
      return subscription;
    } catch (e) {
      _logger.e('Error setting up ECG listener: $e');
      return null;
    }
  }
  
  /// Analyze ECG data using TensorFlow Lite model in background
  Future<Map<String, dynamic>?> analyzeECGData(
    List<double> ecgValues, 
    {int oxygenLevel = 98}
  ) async {
    // Create a cache key based on data signature
    final cacheKey = _getAnalysisCacheKey(ecgValues);
    
    // Check if we have cached analysis
    final cachedAnalysis = _getCachedAnalysis(cacheKey);
    if (cachedAnalysis != null) {
      return cachedAnalysis;
    }
    
    try {
      // Ensure we have enough data
      if (ecgValues.length < 100) {
        _logger.w('Not enough ECG data for analysis (${ecgValues.length} points)');
        return null;
      }
      
      // Extract features in background using compute
      final features = await compute(_extractFeatures, ecgValues);
      
      // Run inference on TFLite model
      final results = await _tfliteService.runInference(features);
      
      // Format the results
      final analysis = {
        'normal_probability': results['normal'] ?? 0.0,
        'arrhythmia_probability': results['arrhythmia'] ?? 0.0,
        'afib_probability': results['afib'] ?? 0.0,
        'heart_attack_probability': results['heart_attack'] ?? 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Broadcast the results
      _analysisResultController.add(analysis);
      
      // Cache the results
      _cacheAnalysis(cacheKey, analysis);
      
      return analysis;
    } catch (e) {
      _logger.e('Error analyzing ECG data: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> _extractFeatures(List<double> ecgData) async {
    try {
      // Calculate basic statistics
      final mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
      final variance = ecgData.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / ecgData.length;
      final stdDev = sqrt(variance);
      
      // Calculate min and max
      final minValue = ecgData.reduce(min);
      final maxValue = ecgData.reduce(max);
      
      // Calculate range
      final range = maxValue - minValue;
      
      // Calculate skewness
      final skewness = ecgData.map((x) => pow((x - mean) / stdDev, 3)).reduce((a, b) => a + b) / ecgData.length;
      
      // Calculate kurtosis
      final kurtosis = ecgData.map((x) => pow((x - mean) / stdDev, 4)).reduce((a, b) => a + b) / ecgData.length;
      
      // Return features as a map
      return {
        'mean': mean,
        'stdDev': stdDev,
        'min': minValue,
        'max': maxValue,
        'range': range,
        'skewness': skewness,
        'kurtosis': kurtosis,
      };
    } catch (e) {
      _logger.e('Error extracting features: $e');
      rethrow;
    }
  }
  
  // Parse ECG data from Firebase snapshot
  ECGDataModel? _parseECGSnapshot(DataSnapshot snapshot) {
    try {
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      List<double> values = [];
      
      // Handle different data formats
      if (data.containsKey('values') && data['values'] is List) {
        values = List<double>.from((data['values'] as List).map((v) => (v as num).toDouble()));
      } else if (data.containsKey('readings') && data['readings'] is List) {
        values = List<double>.from((data['readings'] as List).map((v) => (v as num).toDouble()));
      } else {
        // Try to extract time series data
        final entries = data.entries.where((e) => e.value is Map && (e.value as Map).containsKey('value'));
        if (entries.isNotEmpty) {
          final sortedEntries = entries.toList()
            ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
          
          for (final entry in sortedEntries) {
            final value = (entry.value as Map)['value'];
            if (value is num) {
              values.add(value.toDouble());
            }
          }
        }
      }
      
      if (values.isEmpty) {
        return null;
      }
      
      return ECGDataModel(
        id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        rawData: values,
        features: {}, // Empty features as they will be computed on demand
        hasAnomaly: false, // Set to false initially
      );
    } catch (e) {
      _logger.e('Error parsing ECG snapshot: $e');
      return null;
    }
  }
  
  // Cache management methods
  ECGDataModel? _getCachedData(String userId) {
    final cachedTime = _cacheTimes[userId];
    if (cachedTime == null) return null;
    
    // Check if cache is expired
    if (DateTime.now().difference(cachedTime) > _cacheExpiration) {
      _cache.remove(userId);
      _cacheTimes.remove(userId);
      return null;
    }
    
    return _cache[userId];
  }
  
  void _cacheData(String userId, ECGDataModel data) {
    _cache[userId] = data;
    _cacheTimes[userId] = DateTime.now();
  }
  
  String _getAnalysisCacheKey(List<double> values) {
    // Simple hash of the data for caching
    final hash = values.take(50).map((v) => v.toStringAsFixed(2)).join('');
    return '${DateTime.now().day}_$hash';
  }
  
  Map<String, dynamic>? _getCachedAnalysis(String key) {
    final cachedTime = _analysisTimes[key];
    if (cachedTime == null) return null;
    
    // Check if cache is expired
    if (DateTime.now().difference(cachedTime) > _analysisExpiration) {
      _analysisCache.remove(key);
      _analysisTimes.remove(key);
      return null;
    }
    
    return _analysisCache[key];
  }
  
  void _cacheAnalysis(String key, Map<String, dynamic> analysis) {
    _analysisCache[key] = analysis;
    _analysisTimes[key] = DateTime.now();
  }
  
  // Optimize data for display by downsampling and processing
  List<List<double>> optimizeForDisplay(List<double> values, int targetPoints) {
    if (values.isEmpty) return [[], []];
    
    // Downsample data for display if needed
    final displayData = values.length > targetPoints 
        ? _resampleECG(values, targetPoints)
        : values;
    
    // Generate X-axis points
    final xValues = List<double>.generate(
      displayData.length, 
      (i) => i.toDouble()
    );
    
    return [xValues, displayData];
  }
  
  // Helper method to resample ECG data to a fixed length
  static List<double> _resampleECG(List<double> values, int targetLength) {
    final result = List<double>.filled(targetLength, 0.0);
    final ratio = values.length / targetLength;
    
    for (int i = 0; i < targetLength; i++) {
      final srcIndex = (i * ratio).floor();
      result[i] = values[srcIndex];
    }
    
    return result;
  }
  
  // Clean up resources
  void dispose() {
    _analysisResultController.close();
    _subscriptions.forEach((_, subscription) => subscription.cancel());
    _subscriptions.clear();
    _cache.clear();
    _cacheTimes.clear();
    _analysisCache.clear();
    _analysisTimes.clear();
  }
} 