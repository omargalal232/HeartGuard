import 'dart:async';
import 'package:logger/logger.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; // Added for compute

import '../models/ecg_reading.dart';
import 'tflite_service.dart';
import 'ecg_data_service.dart';

/// A high-performance service for handling ECG data
/// with optimized fetching, caching, and AI analysis
class OptimizedECGService {
  static final OptimizedECGService _instance = OptimizedECGService._internal();
  
  // Singleton pattern
  factory OptimizedECGService() => _instance;
  
  OptimizedECGService._internal();
  
  final TFLiteService _tfliteService = TFLiteService();
  final EcgDataService _ecgDataService = EcgDataService();
  static final _logger = Logger();
  
  // Stream controller for broadcasting analysis results
  final _analysisResultController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get analysisResultsStream => _analysisResultController.stream;
  
  // Stream controller for broadcasting the latest reading itself
  final _latestReadingController = StreamController<EcgReading?>.broadcast();
  Stream<EcgReading?> get latestReadingStream => _latestReadingController.stream;
  
  StreamSubscription<EcgReading?>? _readingSubscription;
  
  // Analysis cache to prevent frequent reanalysis
  final Map<String, Map<String, dynamic>> _analysisCache = {};
  final Map<String, DateTime> _analysisTimes = {};
  static const _analysisExpiration = Duration(seconds: 30);
  
  // تهيئة النموذج باستخدام التنزيل المسبق (prefetch)
  bool _isModelInitialized = false;
  
  // Initialize the service
  Future<void> init() async {
    try {
      _logger.i('بدء تهيئة OptimizedECGService...');
      
      // تحميل النموذج
      await _tfliteService.initModel();
      
      // التحقق من حالة النموذج
      _isModelInitialized = _tfliteService.isModelLoaded();
      if (_isModelInitialized) {
        _logger.i('تم تحميل نموذج TensorFlow Lite بنجاح ✅');
      } else {
        _logger.w('فشل في تحميل نموذج TensorFlow Lite ❌ - سيتم إعادة المحاولة عند طلب التحليل');
        throw Exception('Failed to load TFLite model during OptimizedECGService initialization.');
      }
      
      // بدء الاستماع إلى القراءات
      _startListeningToReadings();
      
      _logger.i('اكتملت تهيئة OptimizedECGService ✅');
    } catch (e, stackTrace) {
      _isModelInitialized = false;
      _logger.e('فشل في تهيئة OptimizedECGService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  // Listen to the data service and trigger analysis
  void _startListeningToReadings() {
    _readingSubscription?.cancel();
    _readingSubscription = _ecgDataService.latestEcgReadingStream.listen(
      (EcgReading? reading) {
        if (reading != null) {
          _logger.d('تم استلام قراءة ECG جديدة: ${reading.id}');
          _latestReadingController.add(reading); // Broadcast the latest reading
          // Trigger analysis when a new reading arrives
          _runAnalysisAndBroadcast(reading);
        } else {
           _latestReadingController.add(null); // Broadcast null if reading is null
        }
      },
      onError: (error, stackTrace) {
        _logger.e('خطأ في تدفق القراءة من EcgDataService', error: error, stackTrace: stackTrace);
        _latestReadingController.addError(error, stackTrace); // Broadcast the error
        _analysisResultController.addError(error, stackTrace); // Broadcast error for analysis too
      }
    );
    _logger.i('بدأ الاستماع إلى EcgDataService للقراءات');
  }
  
  // Run analysis (potentially cached) and broadcast results
  Future<void> _runAnalysisAndBroadcast(EcgReading reading) async {
    try {
      final result = await analyzeECGReading(reading);
      if (result != null) {
        _analysisResultController.add(result);
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to analyze ECG reading', error: e, stackTrace: stackTrace);
      _analysisResultController.addError(e, stackTrace);
    }
  }
  
  // Analyze an ECG reading and return the results
  Future<Map<String, dynamic>?> analyzeECGReading(EcgReading reading) async {
    try {
      // Check if we have valid data for analysis
      if (!reading.hasValidData) {
        _logger.w('No valid ECG values available for analysis');
        return null;
      }
      
      // Check if we have a cached analysis
      final cacheKey = _getAnalysisCacheKey(reading);
      final cachedAnalysis = _getCachedAnalysis(cacheKey);
      if (cachedAnalysis != null) {
        _logger.d('Using cached analysis for ${reading.id}');
        return cachedAnalysis;
      }
      
      // Ensure model is initialized
      if (!_isModelInitialized) {
        _logger.i('Model not initialized, attempting reload...');
        await _tfliteService.reloadModel();
        _isModelInitialized = _tfliteService.isModelLoaded();
        
        if (!_isModelInitialized) {
          _logger.w('Failed to reload model - using default analysis values');
          return _getDefaultResults();
        }
      }
      
      // Extract features from ECG reading
      final features = await _extractFeatures(reading);
      _logger.d('Extracted features: $features');
      
      // Run model inference
      final results = await _tfliteService.runInference(features);
      
      // Check results for analysis success
      if (results.containsKey('error') && results['error'] != null) {
        _logger.w('Error during analysis execution: ${results['error']}');
        return _getDefaultResults();
      }
      
      // Format results
      final analysis = {
        'normal': results['normal'] ?? 0.0,
        'arrhythmia': results['arrhythmia'] ?? 0.0,
        'afib': results['afib'] ?? 0.0,
        'heart_attack': results['heart_attack'] ?? 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'reading_id': reading.id,
      };
      
      // Cache the analysis
      _cacheAnalysis(cacheKey, analysis);
      _logger.i('ECG analysis complete: ${analysis['normal']}, ${analysis['arrhythmia']}, ${analysis['afib']}, ${analysis['heart_attack']}');
      
      return analysis;
    } catch (e, stackTrace) {
      _logger.e('Exception in analyzeECGReading', error: e, stackTrace: stackTrace);
      return _getDefaultResults();
    }
  }
  
  // إرجاع نتائج افتراضية في حالة الفشل
  Map<String, dynamic> _getDefaultResults() {
    return {
      'normal': 0.95,
      'arrhythmia': 0.03,
      'afib': 0.01,
      'heart_attack': 0.01,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_default': true,
    };
  }
  
  // New static method for isolate work
  static Future<Map<String, dynamic>> _extractFeaturesIsolateWork(List<double> values) async {
    // Use debugPrint for logging within isolates as _logger might not be accessible
    // or could lead to issues if not handled carefully (e.g., making it static).
    debugPrint('[ISOLATE _extractFeaturesIsolateWork] Starting feature extraction.');

    final Map<String, dynamic> defaultFeaturesForIsolate = {
        'hrv': {'sdnn': 50.0, 'rmssd': 30.0},
        'qrsDuration': 100.0,
        'qrsAmplitude': 1.0,
        'stElevation': 0.05,
        'stSlope': 0.02,
    };

    try {
      // Calculate HRV features with validation
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] Calculating HRV features...');
      List<double> hrvFeatures = await _calculateHrvFeatures(values); // static call, make it await if it's async
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] HRV features calculated: SDNN=${hrvFeatures.isNotEmpty ? hrvFeatures[0] : 'N/A'}, RMSSD=${hrvFeatures.length > 1 ? hrvFeatures[1] : 'N/A'}');

      if (hrvFeatures.length < 2 ||
          hrvFeatures[0].isNaN || hrvFeatures[0].isInfinite || hrvFeatures[0] < 0 ||
          (hrvFeatures.length > 1 && (hrvFeatures[1].isNaN || hrvFeatures[1].isInfinite || hrvFeatures[1] < 0))) {
          // _logger.w('Isolate: Invalid or NaN HRV features detected: SDNN=${hrvFeatures.isNotEmpty ? hrvFeatures[0] : 'N/A'}, RMSSD=${hrvFeatures.length > 1 ? hrvFeatures[1] : 'N/A'}. Using default HRV values.');
          debugPrint('[ISOLATE _extractFeaturesIsolateWork] Invalid or NaN HRV features detected. SDNN=${hrvFeatures.isNotEmpty ? hrvFeatures[0] : 'N/A'}, RMSSD=${hrvFeatures.length > 1 ? hrvFeatures[1] : 'N/A'}. Using default HRV values.');
          final defaultHrv = defaultFeaturesForIsolate['hrv'] as Map<String, double>;
          // Ensure hrvFeatures has at least two elements before assigning
          hrvFeatures = [defaultHrv['sdnn']!, defaultHrv['rmssd']!];
      }


      // Analyze QRS complex
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] Analyzing QRS complex...');
      Map<String, double> qrsFeatures = await _analyzeQrsComplex(values); // static call, make it await if it's async
      // Original debugPrint logged potentially null values from qrsFeatures directly.
      // Assuming _analyzeQrsComplex might not always return valid keys, or for general safety:
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] QRS complex analyzed: Duration=${qrsFeatures['duration']?.toString() ?? "N/A"}, Amplitude=${qrsFeatures['amplitude']?.toString() ?? "N/A"}');

      final double? qrsDuration = qrsFeatures['duration'];
      final double? qrsAmplitude = qrsFeatures['amplitude'];
      bool setDefaultQrs = false;

      if (qrsDuration == null || qrsAmplitude == null) {
          setDefaultQrs = true;
          debugPrint('[ISOLATE _extractFeaturesIsolateWork] QRS duration or amplitude is null. Using default QRS values.');
      } else {
          // qrsDuration and qrsAmplitude are now non-nullable `double` here due to type promotion
          if (qrsDuration < 0 || qrsAmplitude < 0 ||
              qrsDuration.isNaN || qrsDuration.isInfinite ||
              qrsAmplitude.isNaN || qrsAmplitude.isInfinite) {
              setDefaultQrs = true;
              debugPrint('[ISOLATE _extractFeaturesIsolateWork] Invalid QRS values (negative, NaN, or infinite). Using default QRS values.');
          }
      }

      if (setDefaultQrs) {
          // _logger.w('Isolate: Invalid QRS features detected. Using default QRS values.');
          qrsFeatures = {
              'duration': defaultFeaturesForIsolate['qrsDuration'] as double,
              'amplitude': defaultFeaturesForIsolate['qrsAmplitude'] as double,
          };
      }

      // Analyze ST segment
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] Analyzing ST segment...');
      Map<String, double> stFeatures = await _analyzeStSegment(values); // static call, make it await if it's async
      // Similar safety for debugPrint:
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] ST segment analyzed: Elevation=${stFeatures['elevation']?.toString() ?? "N/A"}, Slope=${stFeatures['slope']?.toString() ?? "N/A"}');

      final double? stElevation = stFeatures['elevation'];
      final double? stSlope = stFeatures['slope'];
      bool setDefaultSt = false;

      if (stElevation == null || stSlope == null) {
          setDefaultSt = true;
          debugPrint('[ISOLATE _extractFeaturesIsolateWork] ST elevation or slope is null. Using default ST values.');
      } else {
          // stElevation and stSlope are now non-nullable `double`
          if (stElevation.isNaN || stElevation.isInfinite ||
              stSlope.isNaN || stSlope.isInfinite) {
              setDefaultSt = true;
              debugPrint('[ISOLATE _extractFeaturesIsolateWork] Invalid ST values (NaN or infinite). Using default ST values.');
          }
      }

      if (setDefaultSt) {
        // _logger.w('Isolate: Invalid ST segment features. Using default ST values.');
        stFeatures = {
            'elevation': defaultFeaturesForIsolate['stElevation'] as double,
            'slope': defaultFeaturesForIsolate['stSlope'] as double,
        };
      } else {
        // This block executes if stFeatures were not replaced by defaults,
        // meaning stElevation and stSlope are valid (non-null, not NaN/Infinite).
        // Type promotion ensures stElevation and stSlope are non-nullable here.
        if (stElevation!.abs() > 0.5 || stSlope!.abs() > 0.5) { // Use ! as they are now confirmed non-null after the 'else' path
        // _logger.w('Isolate: Abnormal ST segment features detected: Elevation=${stFeatures['elevation']}, Slope=${stFeatures['slope']}');
          debugPrint('[ISOLATE _extractFeaturesIsolateWork] Abnormal ST segment features detected: Elevation=$stElevation, Slope=$stSlope');
        }
      }
      
      final result = {
          'hrv': {'sdnn': hrvFeatures[0], 'rmssd': hrvFeatures.length > 1 ? hrvFeatures[1] : (defaultFeaturesForIsolate['hrv'] as Map<String,double>)['rmssd']!},
          'qrsDuration': qrsFeatures['duration']!,
          'qrsAmplitude': qrsFeatures['amplitude']!,
          'stElevation': stFeatures['elevation']!,
          'stSlope': stFeatures['slope']!,
      };
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] Feature extraction complete. Result: $result');
      return result;
    } catch (e, stackTrace) {
      // _logger.e('Error in _extractFeaturesIsolateWork', error: e, stackTrace: stackTrace);
      debugPrint('[ISOLATE _extractFeaturesIsolateWork] Error in _extractFeaturesIsolateWork: $e\\n$stackTrace');
      return defaultFeaturesForIsolate; // Return full default structure on error
    }
  }

  // Placeholder static methods for feature extraction logic
  static Future<List<double>> _calculateHrvFeatures(List<double> values) async {
    // Implement HRV calculation logic here
    debugPrint('[ISOLATE _calculateHrvFeatures] Placeholder for HRV calculation.');
    // Return default or calculated values
    return [50.0, 30.0]; // Example: SDNN, RMSSD
  }

  static Future<Map<String, double>> _analyzeQrsComplex(List<double> values) async {
    // Implement QRS complex analysis logic here
    debugPrint('[ISOLATE _analyzeQrsComplex] Placeholder for QRS complex analysis.');
    // Return default or calculated values
    return {'duration': 100.0, 'amplitude': 1.0};
  }

  static Future<Map<String, double>> _analyzeStSegment(List<double> values) async {
    // Implement ST segment analysis logic here
    debugPrint('[ISOLATE _analyzeStSegment] Placeholder for ST segment analysis.');
    // Return default or calculated values
    return {'elevation': 0.05, 'slope': 0.02};
  }

  // ميزات استخراج من قراءة ECG - Modified to use compute
  Future<Map<String, dynamic>> _extractFeatures(EcgReading reading) async {
    _logger.d('Attempting to extract features for reading ID: ${reading.id}');
    if (reading.values == null || reading.values!.isEmpty) {
      _logger.w('No ECG values found in reading ID: ${reading.id}. Returning default features.');
      // Provide a default structure matching what the isolate would return on success
      return {
        'hrv': {'sdnn': 50.0, 'rmssd': 30.0}, // Default HRV
        'qrsDuration': 100.0,               // Default QRS duration
        'qrsAmplitude': 1.0,                // Default QRS amplitude
        'stElevation': 0.05,                // Default ST elevation
        'stSlope': 0.02,                    // Default ST slope
      };
    }

    try {
      _logger.d('Calling compute for _extractFeaturesIsolateWork with ${reading.values!.length} values.');
      // Run feature extraction in a separate isolate
      final features = await compute(_extractFeaturesIsolateWork, reading.values!);
      _logger.d('Feature extraction via compute completed. Features: $features');
      return features;
    } catch (e, stackTrace) {
      _logger.e('Error calling compute for feature extraction in _extractFeatures', error: e, stackTrace: stackTrace);
      // Return default features in case of compute error
      return {
        'hrv': {'sdnn': 50.0, 'rmssd': 30.0},
        'qrsDuration': 100.0,
        'qrsAmplitude': 1.0,
        'stElevation': 0.05,
        'stSlope': 0.02,
         'error_in_compute': e.toString(), // Optionally include error information
      };
    }
  }
  
  String _getAnalysisCacheKey(EcgReading reading) {
    // Use reading ID (Firebase push key) as cache key
    return reading.id ?? reading.timestamp?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  Map<String, dynamic>? _getCachedAnalysis(String key) {
    final cachedTime = _analysisTimes[key];
    if (cachedTime == null) return null;
    
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
  
  // Clean up resources
  void dispose() {
    _logger.i('Disposing OptimizedECGService resources.');
    _readingSubscription?.cancel();
    _analysisResultController.close();
    _latestReadingController.close();
    _tfliteService.dispose(); // Ensure TFLite resources are released
    _analysisCache.clear();
    _analysisTimes.clear();
  }
  
  // إعادة تحميل النموذج
  Future<bool> reloadTfliteModel() async {
    _logger.i('إعادة تحميل نموذج TFLite...');
    final result = await _tfliteService.reloadModel();
    _isModelInitialized = result;
    _logger.i('نتيجة إعادة تحميل النموذج: $_isModelInitialized');
    return result;
  }
}

/// Redirects to OptimizedECGService to provide the same functionality
class ECGService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Logger _logger;
  final OptimizedECGService _optimizedService;

  // Private constructor
  ECGService._internal() 
    : _logger = Logger(),
      _optimizedService = OptimizedECGService();

  // Singleton instance
  static final ECGService _instance = ECGService._internal();

  // Factory constructor
  factory ECGService() {
    return _instance;
  }
  
  // Provide access to the streams from the optimized service
  Stream<Map<String, dynamic>> get analysisResultsStream => _optimizedService.analysisResultsStream;
  Stream<EcgReading?> get latestReadingStream => _optimizedService.latestReadingStream;
  
  // Forward the analysis method (or specific methods needed)
  Future<Map<String, dynamic>?> analyzeECGReading(EcgReading reading) {
    return _optimizedService.analyzeECGReading(reading);
  }
  
  // Dispose method if needed
   void dispose() {
     _optimizedService.dispose();
   }

  // Add initialization method for compatibility with MonitoringScreen
  Future<void> init() async {
    // The initialization is now handled by awaiting the OptimizedECGService.init()
    await _optimizedService.init(); 
    _logger.i('ECGService initialized by calling OptimizedECGService.init()');
  }
  
  // إعادة تحميل النموذج
  Future<bool> reloadModel() async {
    return await _optimizedService.reloadTfliteModel();
  }

  /// Fetches ECG readings for a specific user from Realtime Database
  /// 
  /// @param userEmail The email of the user to fetch readings for
  /// @param limit Optional limit on the number of readings to fetch
  /// @return List of EcgReading objects sorted by timestamp (newest first)
  Future<List<EcgReading>> getEcgReadingsForUser(String userEmail, {int limit = 50}) async {
    try {
      _logger.i('Fetching ECG readings for user: $userEmail, limit: $limit');
      
      // Clean the email to use as a key if needed 
      // Firebase doesn't allow '.' in keys, so emails are often stored with '.' replaced by ','
      final cleanEmail = userEmail.replaceAll('.', ',');
      _logger.d('Using clean email for query: $cleanEmail');
      
      List<EcgReading> readings = [];
      
      // First, try to fetch all ecg_data and filter by user_email
      _logger.d('Attempting to query ecg_data node...');
      try {
        final reference = _database.ref('ecg_data');
        final snapshot = await reference.get();
        _logger.d('ecg_data query result - Has data: ${snapshot.exists}, Value type: ${snapshot.value.runtimeType}');
        
        if (snapshot.exists && snapshot.value != null && snapshot.value is Map) {
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
          
          // Process each entry and add it to readings if it matches the user email
          data.forEach((key, value) {
            try {
              if (value is Map) {
                final Map<String, dynamic> readingMap = Map<String, dynamic>.from(value);
                
                // Add the key as the ID
                readingMap['id'] = key;
                
                // Check if this reading belongs to the requested user
                final readingEmail = readingMap['user_email'] as String?;
                
                // Match either exact email or cleaned email format
                if (readingEmail == userEmail || readingEmail == cleanEmail) {
                  readings.add(EcgReading.fromMap(readingMap));
                }
              }
            } catch (e) {
              _logger.w('Error processing reading $key: $e');
            }
          });
          
          _logger.i('Found ${readings.length} readings in ecg_data for user: $userEmail');
        }
      } catch (e) {
        _logger.w('Error querying ecg_data node: $e');
      }
      
      // If no readings found, try the other approaches as fallback
      if (readings.isEmpty) {
        _logger.d('No readings found in ecg_data, trying alternative queries...');
        
        // Try querying by user_email field in ecg_readings node
        try {
          final reference = _database.ref('ecg_data');
          final query = reference
              .orderByChild('user_email')
              .equalTo(userEmail)
              .limitToLast(limit);
          
          final snapshot = await query.get();
          
          if (snapshot.exists && snapshot.value != null) {
            _logger.i('Found readings in ecg_data node');
            readings = _processSnapshot(snapshot);
          }
        } catch (e) {
          _logger.w('Error querying ecg_data node: $e');
        }
      }
      
      // If we found readings, sort them
      if (readings.isNotEmpty) {
        // Sort by timestamp descending (newest first)
        readings.sort((a, b) {
          final aTime = a.timestamp is int ? a.timestamp as int : 0;
          final bTime = b.timestamp is int ? b.timestamp as int : 0;
          return bTime.compareTo(aTime);
        });
        
        // Limit to the requested number if needed
        if (readings.length > limit) {
          readings = readings.sublist(0, limit);
        }
      }
      
      _logger.i('Retrieved ${readings.length} ECG readings for user: $userEmail');
      return readings;
    } catch (e, stackTrace) {
      _logger.e('Error fetching ECG readings', error: e, stackTrace: stackTrace);
      throw Exception('Failed to load ECG readings: $e');
    }
  }
  
  /// Process a Firebase DataSnapshot into a list of EcgReading objects
  List<EcgReading> _processSnapshot(DataSnapshot snapshot) {
    final List<EcgReading> readings = [];
    
    try {
      if (snapshot.value is Map) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((key, value) {
          try {
            if (value is Map) {
              final Map<String, dynamic> readingMap = Map<String, dynamic>.from(value);
              // Add the key as the ID if not present
              readingMap['id'] ??= key;
              readings.add(EcgReading.fromMap(readingMap));
            } else {
              _logger.w('Invalid data format for reading $key: $value');
            }
          } catch (e) {
            _logger.w('Error parsing reading $key: $e');
          }
        });
      } else if (snapshot.value is List) {
        // Handle array data (rare, but possible)
        final List<dynamic> dataList = snapshot.value as List<dynamic>;
        
        for (int i = 0; i < dataList.length; i++) {
          final value = dataList[i];
          if (value != null && value is Map) {
            try {
              final Map<String, dynamic> readingMap = Map<String, dynamic>.from(value);
              // Use index as ID if not present
              readingMap['id'] ??= i.toString();
              readings.add(EcgReading.fromMap(readingMap));
            } catch (e) {
              _logger.w('Error parsing reading at index $i: $e');
            }
          }
        }
      }
    } catch (e) {
      _logger.e('Error processing snapshot: $e');
    }
    
    return readings;
  }

  Future<Map<String, dynamic>?> getCurrentReading() async {
    try {
      // Get the latest reading from Realtime Database
      final snapshot = await _database.ref('ecg_data').orderByChild('timestamp').limitToLast(1).get();

      if (snapshot.value == null) {
        _logger.i('No current ECG reading available');
        return null;
      }

      // Handle different data structures
      if (snapshot.value is Map) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        
        // Handle empty data
        if (data.isEmpty) {
          _logger.i('Empty data returned for current reading');
          return null;
        }
        
        try {
          // Get the first (and only) entry
          final firstKey = data.keys.first;
          final value = data[firstKey];
          
          if (value is Map) {
            final readingData = value;
            // Convert to the expected Map<String, dynamic> format
            return Map<String, dynamic>.from(readingData);
          } else {
            _logger.w('Invalid data format for current reading: $value');
            return null;
          }
        } catch (e) {
          _logger.w('Error parsing current reading: $e');
          return null;
        }
      } else {
        _logger.w('Unexpected data format received: ${snapshot.value.runtimeType}');
        return null;
      }
    } catch (e) {
      _logger.e('Error getting current reading', error: e);
      return null;
    }
  }
} 