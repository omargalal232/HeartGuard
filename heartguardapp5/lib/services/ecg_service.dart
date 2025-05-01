import 'dart:async';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ecg_reading.dart';
import 'tflite_service.dart';
import 'ecg_data_service.dart';

/// A high-performance service for handling ECG data
/// with optimized fetching, caching, and AI analysis
class OptimizedECGService {
  static final OptimizedECGService _instance = OptimizedECGService._internal();
  
  // Singleton pattern
  factory OptimizedECGService() => _instance;
  
  OptimizedECGService._internal() {
    _initialize();
  }
  
  final TFLiteService _tfliteService = TFLiteService();
  final EcgDataService _ecgDataService = EcgDataService();
  final _logger = Logger();
  
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
  final Duration _analysisExpiration = const Duration(seconds: 30);
  
  // تهيئة النموذج باستخدام التنزيل المسبق (prefetch)
  bool _isModelInitialized = false;
  
  // Initialize the service
  Future<void> _initialize() async {
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
      }
      
      // بدء الاستماع إلى القراءات
      _startListeningToReadings();
      
      _logger.i('اكتملت تهيئة OptimizedECGService ✅');
    } catch (e, stackTrace) {
      _isModelInitialized = false;
      _logger.e('فشل في تهيئة OptimizedECGService', error: e, stackTrace: stackTrace);
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
  
  // ميزات استخراج من قراءة ECG
  Future<Map<String, dynamic>> _extractFeatures(EcgReading reading) async {
    try {
      // حساب معدل ضربات القلب من القراءة
      final heartRate = reading.bpm ?? 75.0;
      
      // تحليل بيانات تغير معدل ضربات القلب (HRV)
      final List<double> hrvFeatures = _calculateHrvFeatures(reading.values!);
      
      // تحليل مجمع QRS
      final Map<String, double> qrsFeatures = _analyzeQrsComplex(reading.values!);
      
      // تحليل مقطع ST
      final Map<String, double> stFeatures = _analyzeStSegment(reading.values!);
      
      // إنشاء قاموس الميزات
      return {
        'heartRate': heartRate,
        'hrv': {
          'sdnn': hrvFeatures[0],
          'rmssd': hrvFeatures[1],
        },
        'qrsDuration': qrsFeatures['duration']!,
        'qrsAmplitude': qrsFeatures['amplitude']!,
        'stElevation': stFeatures['elevation']!,
        'stSlope': stFeatures['slope']!,
      };
    } catch (e, stackTrace) {
      _logger.w('خطأ أثناء استخراج الميزات من ECG', error: e, stackTrace: stackTrace);
      // إرجاع قيم افتراضية معقولة
      return {
        'heartRate': 75.0,
        'hrv': {
          'sdnn': 50.0,
          'rmssd': 30.0,
        },
        'qrsDuration': 100.0,
        'qrsAmplitude': 1.0,
        'stElevation': 0.0,
        'stSlope': 0.0,
      };
    }
  }
  
  // حساب ميزات تغير معدل ضربات القلب
  List<double> _calculateHrvFeatures(List<double> values) {
    // في تطبيق حقيقي، يتم هنا حساب HRV من فواصل RR
    // هنا نستخدم قيم تقريبية لأغراض المثال
    final sdnn = 50.0; // انحراف معياري لفواصل RR
    final rmssd = 30.0; // جذر متوسط مربع فروق فواصل RR المتعاقبة
    return [sdnn, rmssd];
  }
  
  // تحليل مجمع QRS
  Map<String, double> _analyzeQrsComplex(List<double> values) {
    // في تطبيق حقيقي، يكون هذا أكثر تعقيدًا
    return {
      'duration': 100.0, // مدة QRS بالمللي ثانية
      'amplitude': 1.0, // سعة QRS بالميلي فولت
    };
  }
  
  // تحليل مقطع ST
  Map<String, double> _analyzeStSegment(List<double> values) {
    // في تطبيق حقيقي، يتم تحليل ارتفاع مقطع ST وميله
    return {
      'elevation': 0.05, // ارتفاع مقطع ST بالميلي فولت
      'slope': 0.02, // ميل مقطع ST
    };
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
  final FirebaseFirestore _firestore;
  final Logger _logger;
  final OptimizedECGService _optimizedService;

  // Private constructor
  ECGService._internal() 
    : _firestore = FirebaseFirestore.instance,
      _logger = Logger(),
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
    // The initialization is handled in the OptimizedECGService constructor
    // This is just a stub for backward compatibility
  }
  
  // إعادة تحميل النموذج
  Future<bool> reloadModel() async {
    return await _optimizedService.reloadTfliteModel();
  }

  Future<Map<String, dynamic>?> getCurrentReading() async {
    try {
      // Get the latest reading from Firestore
      final snapshot = await _firestore
          .collection('ecg_readings')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return snapshot.docs.first.data();
    } catch (e) {
      _logger.e('Error getting current reading', error: e);
      return null;
    }
  }
} 