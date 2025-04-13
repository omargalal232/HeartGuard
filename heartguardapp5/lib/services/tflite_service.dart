import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart' as logger;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class TFLiteService {
  static const String modelAssetPath = 'assets/models/ecg_model.tflite';
  static const String metadataAssetPath = 'assets/models/model_metadata.json';
  
  final _logger = logger.Logger();
  bool _modelLoaded = false;
  bool _initAttempted = false;
  Interpreter? _interpreter;
  Map<String, dynamic>? _modelMetadata;
  Map<String, dynamic>? _normalizationParams;
  
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
      
      // التأكد من وجود ملفات النموذج
      bool modelExists = await _checkAssetExists(modelAssetPath);
      bool metadataExists = await _checkAssetExists(metadataAssetPath);
      
      _logger.d('التحقق من الملفات: النموذج موجود: $modelExists، البيانات الوصفية موجودة: $metadataExists');
      
      if (!modelExists) {
        throw Exception('ملف النموذج غير موجود في الأصول: $modelAssetPath');
      }
      
      // طباعة مسار الملفات المؤقتة للتأكد
      final tempDir = await getTemporaryDirectory();
      _logger.d('المسار المؤقت: ${tempDir.path}');
      
      // تحميل ملف النموذج
      final modelFile = await _getModelFile();
      _logger.d('تم تحميل ملف النموذج في: ${modelFile.path}, الحجم: ${await modelFile.length()} بايت');
      
      // إعدادات المترجم للحصول على أداء أفضل
      final options = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = true;
      
      try {
        // تحميل المترجم من الملف
        _interpreter = Interpreter.fromFile(modelFile, options: options);
        _logger.i('تم إنشاء المترجم بنجاح ✅');
      } catch (e) {
        _logger.e('خطأ في إنشاء المترجم: $e');
        throw Exception('فشل في إنشاء المترجم: $e');
      }
      
      // تحميل بيانات وصفية للنموذج
      await _loadModelMetadata();
      
      // طباعة معلومات حول المترجم
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      _logger.i('تم تحميل نموذج TensorFlow Lite بنجاح ✅');
      _logger.d('شكل الإدخال: ${inputTensor.shape}, النوع: ${inputTensor.type}');
      _logger.d('شكل الإخراج: ${outputTensor.shape}, النوع: ${outputTensor.type}');
      
      _modelLoaded = true;
      _logger.i('اكتملت تهيئة النموذج ✅');
    } catch (e, stackTrace) {
      _logger.e('فشل في تحميل نموذج TensorFlow Lite: $e', error: e, stackTrace: stackTrace);
      debugPrint('خطأ TFLite: $e');
      _modelLoaded = false;
      // لا نعيد رمي الخطأ - سنتعامل مع الفشل بسلاسة
    }
  }
  
  // التحقق من وجود ملف في الأصول
  Future<bool> _checkAssetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      _logger.w('الملف غير موجود في الأصول: $assetPath');
      return false;
    }
  }
  
  // الحصول على ملف النموذج من الأصول
  Future<File> _getModelFile() async {
    try {
      // قراءة النموذج من الأصول
      final byteData = await rootBundle.load(modelAssetPath);
      _logger.d('تم تحميل النموذج من الأصول بحجم: ${byteData.lengthInBytes} بايت');
      
      // إنشاء ملف مؤقت وكتابة البيانات إليه
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;
      final filePath = '$tempPath/ecg_model.tflite';
      
      // حذف الملف القديم إذا كان موجودًا
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _logger.d('تم حذف الملف القديم');
      }
      
      // كتابة البيانات الجديدة
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _logger.d('تم كتابة الملف الجديد، حجم الملف: ${await file.length()} بايت');
      
      return file;
    } catch (e, stackTrace) {
      _logger.e('خطأ في استخراج ملف النموذج: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  // تحميل البيانات الوصفية للنموذج للحصول على معلمات التطبيع وتسميات الفئات
  Future<void> _loadModelMetadata() async {
    try {
      // محاولة تحميل ملف البيانات الوصفية
      final String metadataJson = await rootBundle.loadString(metadataAssetPath);
      _logger.d('تم تحميل ملف البيانات الوصفية بحجم: ${metadataJson.length} بايت');
      
      _modelMetadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      _logger.d('نموذج JSON: $_modelMetadata');
      
      if (_modelMetadata != null && _modelMetadata!.containsKey('normalization')) {
        _normalizationParams = _modelMetadata!['normalization'] as Map<String, dynamic>;
        _logger.i('تم تحميل البيانات الوصفية للنموذج بنجاح مع معلمات التطبيع');
      } else {
        _logger.w('البيانات الوصفية للنموذج لا تحتوي على معلمات التطبيع');
      }
    } catch (e, stackTrace) {
      _logger.w('تعذر تحميل البيانات الوصفية للنموذج: $e', error: e, stackTrace: stackTrace);
      
      // استخدام معلمات التطبيع الافتراضية
      _logger.i('استخدام معلمات التطبيع الافتراضية');
      _normalizationParams = {
        'heart_rate': {'mean': 80.0, 'std': 20.0},
        'hrv_sdnn': {'mean': 50.0, 'std': 15.0},
        'hrv_rmssd': {'mean': 35.0, 'std': 15.0},
        'qrs_duration': {'mean': 100.0, 'std': 20.0},
        'qrs_amplitude': {'mean': 1.0, 'std': 0.3},
        'st_elevation': {'mean': 0.0, 'std': 0.1},
        'st_slope': {'mean': 0.0, 'std': 0.1}
      };
    }
  }
  
  // تشغيل الاستدلال على ميزات ECG
  Future<Map<String, dynamic>> runInference(Map<String, dynamic> features) async {
    if (!_modelLoaded) {
      _logger.i('النموذج غير محمل، محاولة تحميله الآن');
      try {
        await initModel();
        if (!_modelLoaded) {
          throw Exception('لم يتم تحميل النموذج بشكل صحيح');
        }
      } catch (e) {
        _logger.e('لا يمكن تحميل النموذج للاستدلال: $e');
        return _getDefaultResults('فشل في تحميل النموذج للتحليل');
      }
    }
    
    try {
      if (_interpreter == null) {
        _logger.e('المترجم غير متاح للاستدلال');
        return _getDefaultResults('المترجم غير متاح');
      }
      
      // إعداد تنسور الإدخال
      final inputTensor = _prepareInputTensor(features);
      _logger.d('تم تجهيز تنسور الإدخال: $inputTensor');
      
      // إنشاء تنسور الإخراج
      final outputBuffer = List<List<double>>.generate(
        1,
        (_) => List<double>.filled(4, 0.0)
      );
      
      // تشغيل الاستدلال
      _logger.d('جاري تنفيذ الاستدلال...');
      _interpreter!.run(inputTensor, outputBuffer);
      
      // معالجة النتائج
      final results = {
        'normal': outputBuffer[0][0],
        'arrhythmia': outputBuffer[0][1],
        'afib': outputBuffer[0][2],
        'heart_attack': outputBuffer[0][3],
        'error': null,
      };
      
      _logger.i('اكتمل استدلال TFLite: $results');
      return results;
    } catch (e, stackTrace) {
      _logger.e('خطأ في تشغيل استدلال TFLite: $e', error: e, stackTrace: stackTrace);
      return _getDefaultResults('خطأ في تنفيذ التحليل: $e');
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
  
  // إعداد تنسور الإدخال من الميزات
  List<List<double>> _prepareInputTensor(Map<String, dynamic> features) {
    // تحويل الميزات إلى تنسيق تنسور مسطح
    final inputFeatures = <double>[];
    
    try {
      // دالة لتطبيع قيمة باستخدام المتوسط والانحراف المعياري
      double normalize(double value, String featureName) {
        if (_normalizationParams != null && _normalizationParams!.containsKey(featureName)) {
          final mean = _normalizationParams![featureName]['mean'] as double;
          final std = _normalizationParams![featureName]['std'] as double;
          return (value - mean) / std;
        } else {
          // تطبيع افتراضي
          return value / 100.0;
        }
      }
      
      // إضافة معدل ضربات القلب (مطبّع)
      final heartRate = features['heartRate'] ?? 70.0;
      _logger.d('معدل ضربات القلب المدخل: $heartRate');
      inputFeatures.add(normalize(
        heartRate is int ? heartRate.toDouble() : heartRate, 
        'heart_rate'
      ));
      
      // إضافة ميزات HRV (مطبّعة)
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
      
      // إضافة ميزات QRS (مطبّعة)
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
      
      // إضافة ميزات مقطع ST (مطبّعة)
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
      
      _logger.d('الميزات المطبّعة: $inputFeatures');
    } catch (e, stackTrace) {
      _logger.e('خطأ في إعداد تنسور الإدخال: $e', error: e, stackTrace: stackTrace);
      // إذا كان هناك خطأ، استخدام القيم الافتراضية
      inputFeatures.clear();
      inputFeatures.addAll([0.35, 0.5, 0.3, 0.5, 0.5, 0.0, 0.0]); // قيم مطبّعة افتراضية
    }
    
    // التأكد من أن لدينا بالضبط 7 ميزات
    while (inputFeatures.length < 7) {
      inputFeatures.add(0.0);
    }
    
    // تقليم القائمة إذا كانت أطول من المتوقع
    if (inputFeatures.length > 7) {
      inputFeatures.length = 7;
    }
    
    // إعادة بالتنسيق المتوقع من قبل TFLite (حجم الدفعة 1)
    return [inputFeatures];
  }
  
  // التخلص من الموارد
  void dispose() {
    try {
      if (_interpreter != null) {
        _interpreter!.close();
        _interpreter = null;
        _logger.i('تم إغلاق المترجم وتحرير الموارد');
      }
      _modelLoaded = false;
      _initAttempted = false;
    } catch (e) {
      _logger.e('خطأ عند التخلص من موارد المترجم: $e');
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
    return _modelLoaded && _interpreter != null;
  }
} 