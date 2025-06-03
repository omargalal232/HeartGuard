import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart' as logger;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

// Helper class for passing parameters to the isolate
class _IsolateInferenceParams {
  final Map<String, dynamic> features;
  final String modelAssetPath;
  final Map<String, dynamic>? modelMetadata;

  _IsolateInferenceParams({
    required this.features,
    required this.modelAssetPath,
    this.modelMetadata,
  });
}

class TFLiteService {
  static const String modelAssetPath = 'assets/models/ecg_model.tflite';
  static const String metadataAssetPath = 'assets/models/model_metadata.json';
  
  static final _logger = logger.Logger();
  bool _modelLoaded = false;
  bool _initAttempted = false;
  Interpreter? _mainInterpreter;
  Map<String, dynamic>? _modelMetadata;
  
  // دالة تهيئة النموذج
  Future<void> initModel() async {
    if (_modelLoaded) {
      _logger.i('النموذج محمل بالفعل');
      return;
    }
    
    try {
      if (_initAttempted) {
        _logger.w('سبق وأن حاولنا تحميل النموذج ولم ينجح. جاري المحاولة مرة أخرى...');
      }
      
      _initAttempted = true;
      
      // Use compute to run heavy operations in a separate isolate
      final result = await compute(_loadModelInBackground, {
        'modelAssetPath': modelAssetPath,
        'metadataAssetPath': metadataAssetPath,
      });
      
      if (result['success']) {
        _modelLoaded = true;
        _logger.i('تم تحميل النموذج بنجاح ✅');
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      _logger.e('خطأ في تحميل النموذج: $e');
      throw Exception('فشل في تحميل النموذج: $e');
    }
  }
  
  // التحقق من وجود ملف في الأصول
  // Future<bool> _checkAssetExists(String assetPath) async {
  //   try {
  //     await rootBundle.load(assetPath);
  //     return true;
  //   } catch (e) {
  //     _logger.w('الملف غير موجود في الأصول: $assetPath');
  //     return false;
  //   }
  // }
  
  // الحصول على ملف النموذج من الأصول
  // Future<File> _getModelFileForMainInterpreter() async {
  //   try {
  //     // قراءة النموذج من الأصول
  //     final byteData = await rootBundle.load(modelAssetPath);
  //     _logger.d('تم تحميل النموذج من الأصول بحجم: ${byteData.lengthInBytes} بايت');
  //     
  //     // إنشاء ملف مؤقت وكتابة البيانات إليه
  //     final tempDir = await getTemporaryDirectory();
  //     final tempPath = tempDir.path;
  //     final filePath = '$tempPath/main_ecg_model.tflite';
  //     
  //     // حذف الملف القديم إذا كان موجودًا
  //     final file = File(filePath);
  //     if (await file.exists()) {
  //       await file.delete();
  //       _logger.d('تم حذف الملف القديم');
  //     }
  //     
  //     // كتابة البيانات الجديدة
  //     await file.writeAsBytes(byteData.buffer.asUint8List());
  //     _logger.d('تم كتابة الملف الجديد، حجم الملف: ${await file.length()} بايت');
  //     
  //     return file;
  //   } catch (e, stackTrace) {
  //     _logger.e('خطأ في استخراج ملف النموذج: $e', error: e, stackTrace: stackTrace);
  //     rethrow;
  //   }
  // }
  
  // تحميل البيانات الوصفية للنموذج للحصول على معلمات التطبيع وتسميات الفئات
  // Future<void> _loadModelMetadata() async {
  //   try {
  //     // محاولة تحميل ملف البيانات الوصفية
  //     final String metadataJson = await rootBundle.loadString(metadataAssetPath);
  //     _logger.d('تم تحميل ملف البيانات الوصفية بحجم: ${metadataJson.length} بايت');
  //     
  //     _modelMetadata = jsonDecode(metadataJson) as Map<String, dynamic>;
  //     _logger.d('نموذج JSON: $_modelMetadata');
  //     
  //     if (_modelMetadata != null && _modelMetadata!.containsKey('normalization')) {
  //       _logger.i('تم تحميل البيانات الوصفية للنموذج بنجاح مع معلمات التطبيع');
  //     } else {
  //       _logger.w('البيانات الوصفية للنموذج لا تحتوي على معلمات التطبيع');
  //     }
  //   } catch (e, stackTrace) {
  //     _logger.w('تعذر تحميل البيانات الوصفية للنموذج: $e', error: e, stackTrace: stackTrace);
  //     
  //     // استخدام معلمات التطبيع الافتراضية
  //     _logger.i('استخدام معلمات التطبيع الافتراضية');
  //   }
  // }
  
  // تشغيل الاستدلال على ميزات ECG
  Future<Map<String, dynamic>> runInference(Map<String, dynamic> features) async {
    _logger.i('runInference called. Checking if model is loaded...');
    if (!_modelLoaded) {
      _logger.i('النموذج غير محمل، محاولة تحميله الآن');
      try {
        _logger.d('Calling initModel() from runInference...');
        await initModel(); // Ensures _modelMetadata is loaded if successful
        _logger.d('initModel() completed. Model loaded: $_modelLoaded');
        if (!_modelLoaded) {
          _logger.e('لم يتم تحميل النموذج بشكل صحيح بعد initModel()');
          return _getDefaultResults('فشل في تحميل النموذج للتحليل');
        }
      } catch (e, stackTrace) {
        _logger.e('لا يمكن تحميل النموذج للاستدلال (exception in initModel): $e', error: e, stackTrace: stackTrace);
        return _getDefaultResults('فشل في تحميل النموذج للتحليل');
      }
    } else {
      _logger.i('Model already loaded.');
    }

    try {
      _logger.d('Preparing parameters for isolate inference...');
      final params = _IsolateInferenceParams(
        features: features,
        modelAssetPath: TFLiteService.modelAssetPath, // Access static const
        modelMetadata: _modelMetadata, // Pass instance metadata
      );

      _logger.d('Calling compute for TFLite inference...');
      // Note: _runInferenceIsolateWork must be a top-level or static method.
      final results = await compute(_runInferenceIsolateWork, params);
      _logger.i('Isolate inference complete, results: $results');
      return results;

    } catch (e, stackTrace) {
      _logger.e('Error calling compute for TFLite inference: $e', error: e, stackTrace: stackTrace);
      return _getDefaultResults('خطأ في بدء التحليل المنفصل: $e');
    }
  }

  // Static method to run inference in an isolate
  static Future<Map<String, dynamic>> _runInferenceIsolateWork(
      _IsolateInferenceParams params) async {
    Interpreter? isolateInterpreter;
    try {
      // 1. Load model bytes from asset path
      final byteData = await rootBundle.load(params.modelAssetPath);
      debugPrint('Isolate: Model bytes loaded from asset path.');

      // 2. Write to a temporary file (necessary for Interpreter.fromFile)
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/isolate_ecg_model_${DateTime.now().millisecondsSinceEpoch}.tflite';
      final modelFile = File(tempPath);
      // if (await modelFile.exists()) { // Avoid potential race conditions if multiple isolates run near-simultaneously
      //   await modelFile.delete();
      // }
      await modelFile.writeAsBytes(byteData.buffer.asUint8List());
      debugPrint('Isolate: Model written to temporary file: ${modelFile.path}');

      // 3. Create Interpreter
      final options = InterpreterOptions()
        ..threads = Platform.numberOfProcessors // Use available processors
        ..useNnApiForAndroid = true; // Consider platform specific logic if needed for iOS
      
      isolateInterpreter = Interpreter.fromFile(modelFile, options: options);
      debugPrint('Isolate: Interpreter created.');

      // 4. Prepare input tensor
      final inputTensor = _prepareInputTensorForIsolate(params.features, params.modelMetadata);
      debugPrint('Isolate: Input tensor prepared: $inputTensor');

      // 5. Create output buffer
      // Ensure this shape matches your model's output tensor shape
      final outputTensorShape = isolateInterpreter.getOutputTensor(0).shape;
      final outputBufferSize = outputTensorShape.isNotEmpty ? outputTensorShape.last : 0; // Assuming 1D or 2D output [1, N]
      
      if (outputBufferSize == 0) {
          debugPrint('Isolate: Error determining output buffer size from model.');
          return _getDefaultResultsForIsolate('خطأ في تحديد حجم مخزن الإخراج للنموذج (isolate)');
      }

      final outputBuffer = List<List<double>>.generate(
          1, (_) => List<double>.filled(outputBufferSize, 0.0));


      // 6. Run inference
      debugPrint('Isolate: Running inference...');
      isolateInterpreter.run(inputTensor, outputBuffer);
      debugPrint('Isolate: Inference run complete.');
      
      // Delete the temporary model file after use
      try {
        if (await modelFile.exists()) {
          await modelFile.delete();
          debugPrint('Isolate: Temporary model file deleted: ${modelFile.path}');
        }
      } catch (e) {
        debugPrint('Isolate: Error deleting temporary model file: $e');
      }


      // 7. Check for NaN in outputBuffer
      bool outputIsNaN = false;
      if (outputBuffer[0].isNotEmpty) {
        for (double val in outputBuffer[0]) {
          if (val.isNaN || val.isInfinite) {
            outputIsNaN = true;
            break;
          }
        }
      } else {
        debugPrint('Isolate: Output buffer is empty or invalid.');
        return _getDefaultResultsForIsolate('مخزن الإخراج فارغ أو غير صالح بعد التحليل (isolate)');
      }


      if (outputIsNaN) {
        debugPrint('Isolate: TFLite inference resulted in NaN/infinite values in outputBuffer.');
        return _getDefaultResultsForIsolate(
            'فشل تحليل النموذج بسبب قيم غير صالحة (NaN/Infinite) في المخرجات (isolate)');
      }
      // --- End NaN Check ---

      // 8. Process results - adjust keys based on your model's output meaning
      // Assuming model output order is: normal, arrhythmia, afib, heart_attack
      if (outputBuffer[0].length < 4) {
          debugPrint('Isolate: Output buffer has fewer than 4 elements. Cannot map to known conditions.');
          return _getDefaultResultsForIsolate('مخرجات النموذج غير كافية لتعيين الحالات (isolate)');
      }
      final results = {
        'normal': outputBuffer[0][0],
        'arrhythmia': outputBuffer[0][1],
        'afib': outputBuffer[0][2],
        'heart_attack': outputBuffer[0][3],
        'error': null,
      };
      
      debugPrint('Isolate: Inference complete, results: $results');
      return results;
    } catch (e, stackTrace) {
      debugPrint('Error in isolate inference: $e\n$stackTrace');
      return _getDefaultResultsForIsolate('خطأ في تنفيذ التحليل (isolate): $e');
    } finally {
      isolateInterpreter?.close();
      debugPrint('Isolate: Interpreter closed.');
    }
  }
  
  // Static version of _getDefaultResults for isolate
  static Map<String, dynamic> _getDefaultResultsForIsolate(String errorMessage) {
    debugPrint('Isolate: Returning default results: $errorMessage');
    return {
      'normal': 0.95, // Default healthy state
      'arrhythmia': 0.03,
      'afib': 0.01,
      'heart_attack': 0.01,
      'error': errorMessage,
    };
  }

  // Static version of _prepareInputTensor for isolate
  static List<List<double>> _prepareInputTensorForIsolate(
      Map<String, dynamic> features, Map<String, dynamic>? modelMetadata) {
    try {
      Map<String, dynamic> currentNormalizationParams;
      bool usingMetadata = false;
      if (modelMetadata != null && modelMetadata['normalization'] is Map && (modelMetadata['normalization'] as Map).isNotEmpty) {
        currentNormalizationParams = modelMetadata['normalization'] as Map<String, dynamic>;
        debugPrint("Isolate: Using normalization parameters from metadata.");
        usingMetadata = true;
      } else {
        debugPrint("Isolate: Using hardcoded normalization parameters (metadata issue or not found: $modelMetadata).");
        currentNormalizationParams = {
          'heartRate': {'mean': 75.0, 'std': 15.0},
          'hrv_sdnn': {'mean': 50.0, 'std': 20.0},
          'hrv_rmssd': {'mean': 30.0, 'std': 15.0},
          'qrsDuration': {'mean': 100.0, 'std': 20.0},
          'qrsAmplitude': {'mean': 1.0, 'std': 0.5},
          'stElevation': {'mean': 0.05, 'std': 0.1},
          'stSlope': {'mean': 0.02, 'std': 0.05},
        };
      }

      double normalize(double value, String featureKey, Map<String, dynamic> normParamsSource) {
        if (value.isNaN || value.isInfinite) {
          debugPrint("Isolate: NaN/Infinite value for '$featureKey' before normalization. Using 0.0.");
          return 0.0;
        }
        final params = normParamsSource[featureKey];
        if (params is Map<String, dynamic>) {
          final mean = (params['mean'] as num?)?.toDouble() ?? 0.0;
          final std = (params['std'] as num?)?.toDouble() ?? 1.0;
          if (std == 0) {
            debugPrint("Isolate: Std dev for '$featureKey' is 0. Using 0.0 to avoid division by zero.");
            return 0.0;
          }
          return (value - mean) / std;
        }
        debugPrint("Isolate: Normalization params for '$featureKey' not found or invalid ($params). Returning unnormalized value.");
        return value; // Return original value if params are missing/invalid
      }
      
      double getSanitizedDefault(String featureKey, double hardcodedDefault, Map<String, dynamic> normParamsSource, bool metaUsed) {
        if (metaUsed) {
            final params = normParamsSource[featureKey];
            if (params is Map<String, dynamic>) {
                 // Use mean from metadata as a sensible default if available
                 return (params['mean'] as num?)?.toDouble() ?? hardcodedDefault;
            }
        }
        return hardcodedDefault;
      }

      double sanitizeAndGet(dynamic rawValue, String featureKey, double defaultValueFromContext) {
        if (rawValue is double) {
          if (rawValue.isNaN || rawValue.isInfinite) {
            debugPrint("Isolate: Feature '$featureKey' is NaN/Infinite. Using default: $defaultValueFromContext");
            return defaultValueFromContext;
          }
          return rawValue;
        } else if (rawValue is int) {
          return rawValue.toDouble();
        }
        debugPrint("Isolate: Feature '$featureKey' type (${rawValue?.runtimeType}) incorrect or null. Using default: $defaultValueFromContext");
        return defaultValueFromContext;
      }
      
      final List<double> normalizedFeatures = [
        normalize(sanitizeAndGet(features['heartRate'], 'heartRate', getSanitizedDefault('heartRate', 75.0, currentNormalizationParams, usingMetadata)), 'heartRate', currentNormalizationParams),
        normalize(sanitizeAndGet((features['hrv'] as Map<String, dynamic>? ?? {})['sdnn'], 'hrv_sdnn', getSanitizedDefault('hrv_sdnn', 50.0, currentNormalizationParams, usingMetadata)), 'hrv_sdnn', currentNormalizationParams),
        normalize(sanitizeAndGet((features['hrv'] as Map<String, dynamic>? ?? {})['rmssd'], 'hrv_rmssd', getSanitizedDefault('hrv_rmssd', 30.0, currentNormalizationParams, usingMetadata)), 'hrv_rmssd', currentNormalizationParams),
        normalize(sanitizeAndGet(features['qrsDuration'], 'qrsDuration', getSanitizedDefault('qrsDuration', 100.0, currentNormalizationParams, usingMetadata)), 'qrsDuration', currentNormalizationParams),
        normalize(sanitizeAndGet(features['qrsAmplitude'], 'qrsAmplitude', getSanitizedDefault('qrsAmplitude', 1.0, currentNormalizationParams, usingMetadata)), 'qrsAmplitude', currentNormalizationParams),
        normalize(sanitizeAndGet(features['stElevation'], 'stElevation', getSanitizedDefault('stElevation', 0.05, currentNormalizationParams, usingMetadata)), 'stElevation', currentNormalizationParams),
        normalize(sanitizeAndGet(features['stSlope'], 'stSlope', getSanitizedDefault('stSlope', 0.02, currentNormalizationParams, usingMetadata)), 'stSlope', currentNormalizationParams),
      ];
      
      debugPrint('Isolate: Normalized features: $normalizedFeatures');
      // This check should align with your model's expected input tensor shape [1, num_features]
      if (normalizedFeatures.length != 7) { 
          debugPrint("Isolate: Incorrect feature count: ${normalizedFeatures.length}. Expected 7 based on current implementation. Returning zeros.");
          return [List<double>.filled(7, 0.0)]; // Adjust size if model expects different
      }
      return [normalizedFeatures];

    } catch (e, stackTrace) {
      debugPrint('Isolate: Error preparing input tensor: $e\n$stackTrace');
      // Return a tensor of zeros or default normalized values if preparation fails
      // to prevent crashes, matching the expected input shape.
      // Assuming model expects 7 features. Adjust if different.
      return [List<double>.filled(7, 0.0)]; 
    }
  }

  // الحصول على نتائج افتراضية في حالة الخطأ
  Map<String, dynamic> _getDefaultResults(String errorMessage) {
    return {
      'normal': 0.95,
      'arrhythmia': 0.03,
      'afib': 0.01,
      'heart_attack': 0.01,
      'error': errorMessage,
    };
  }
  
  // التخلص من الموارد
  void dispose() {
    try {
      if (_mainInterpreter != null) {
        _mainInterpreter!.close();
        _mainInterpreter = null;
        _logger.i('تم إغلاق المترجم الرئيسي وتحرير الموارد');
      }
      _modelLoaded = false;
      _initAttempted = false;
    } catch (e) {
      _logger.e('خطأ عند التخلص من موارد المترجم الرئيسي: $e');
    }
  }
  
  // إعادة تحميل النموذج بشكل صريح
  Future<bool> reloadModel() async {
    _logger.i('إعادة تحميل نموذج TFLite...');
    
    // التخلص من الموارد الحالية
    dispose();
    
    try {
      // محاولة تهيئة النموذج من جديد
      await initModel();
      
      if (_modelLoaded) {
        _logger.i('تم إعادة تحميل النموذج بنجاح ✓');
      } else {
        _logger.w('فشل في إعادة تحميل النموذج ✗');
      }
      
      return _modelLoaded;
    } catch (e) {
      _logger.e('استثناء أثناء إعادة تحميل النموذج: $e');
      return false;
    }
  }
  
  // التحقق من حالة النموذج
  bool isModelLoaded() {
    return _modelLoaded && _mainInterpreter != null;
  }

  // Add these static helper functions with unique names
  static Future<bool> _staticCheckAssetExists(String path) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      return manifestMap.containsKey(path);
    } catch (e) {
      return false;
    }
  }

  static Future<File> _staticGetModelFile(String modelPath) async {
    final tempDir = await getTemporaryDirectory();
    final modelFile = File('${tempDir.path}/model.tflite');
    if (!await modelFile.exists()) {
      final modelBytes = await rootBundle.load(modelPath);
      await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
    }
    return modelFile;
  }

  // Add this function to load model in background
  static Future<Map<String, dynamic>> _loadModelInBackground(Map<String, dynamic> params) async {
    try {
      final modelAssetPath = params['modelAssetPath'] as String;
      // final metadataAssetPath = params['metadataAssetPath'] as String; // Metadata isn't strictly needed for basic loading
      
      // Check if files exist - REMOVING THIS CHECK
      // bool modelExists = await _staticCheckAssetExists(modelAssetPath);
      // await _staticCheckAssetExists(metadataAssetPath); 

      // if (!modelExists) {
      //   return {
      //     'success': false,
      //     'error': 'ملف النموذج غير موجود في الأصول: $modelAssetPath'
      //   };
      // }
      
      // Get temporary directory
      // await getTemporaryDirectory(); // _staticGetModelFile will call this
      
      // Load model file
      final modelFile = await _staticGetModelFile(modelAssetPath); // This will attempt rootBundle.load
      
      // Configure interpreter options
      final options = InterpreterOptions()
        ..threads = 2 // Default to 2 threads for background tasks
        ..useNnApiForAndroid = true; // Example option
      
      // Create interpreter
      final interpreter = Interpreter.fromFile(modelFile, options: options);
      // _logger.i('Interpreter created successfully in background isolate.'); // Cannot use instance logger in static method

      // Optionally, load metadata here if needed by the interpreter setup itself,
      // but often metadata is for pre/post processing, not Interpreter.fromFile.
      // For now, we assume the interpreter can be created without instance metadata.
      
      return {
        'success': true,
        'interpreter': interpreter // Return the interpreter instance
        // If metadata were loaded here: 'metadata': loadedMetadata
      };
    } catch (e) {
      // _logger.e('Error in _loadModelInBackground: $e'); // Cannot use instance logger
      debugPrint('Error in _loadModelInBackground: $e');
      return {
        'success': false,
        'error': 'Failed to load model in background: ${e.toString()}'
      };
    }
  }
} 