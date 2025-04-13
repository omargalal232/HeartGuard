# HeartGuard ECG Analysis Tools

هذا المجلد يحتوي على أدوات معالجة بيانات ECG وتدريب نماذج التعلم الآلي للكشف عن حالات القلب غير الطبيعية.

## الإعداد

1. قم بتثبيت حزم Python المطلوبة:

```bash
pip install firebase-admin pandas numpy matplotlib scikit-learn tensorflow
```

2. قم بإنشاء مفتاح حساب خدمة في لوحة تحكم Firebase واحفظه باسم `firebase-credentials.json` في هذا المجلد.

## نظرة عامة على السكربتات

### 1. استخراج البيانات ومعالجتها

- **firebase_data_extractor.py**: يستخرج قراءات ECG من Firebase Realtime Database ويحولها إلى تنسيق مناسب للتدريب.
  ```bash
  python firebase_data_extractor.py --creds firebase-credentials.json --output data_output
  ```

### 2. تسمية البيانات

- **data_labeler.py**: أداة تفاعلية لتسمية بيانات ECG للتعلم الخاضع للإشراف.
  ```bash
  python data_labeler.py data_output/ecg_data_for_labeling.csv
  ```

### 3. تدريب النموذج

- **train_new_model.py**: يقوم بتدريب نموذج شبكة عصبية لتحليل ECG وتحويله إلى تنسيق TensorFlow Lite.
  ```bash
  python train_new_model.py
  ```

## سير العمل

اتبع هذه الخطوات للانتقال من بيانات ECG الخام إلى نموذج منشور:

1. **استخراج البيانات** من Firebase Realtime Database:
   ```bash
   python firebase_data_extractor.py
   ```

2. **تسمية البيانات** للتعلم الخاضع للإشراف:
   ```bash
   python data_labeler.py data_output/ecg_data_for_labeling.csv
   ```

3. **تدريب النموذج** باستخدام البيانات المسماة:
   ```bash
   python train_new_model.py
   ```

## خصائص النموذج

يستخدم نموذج تحليل ECG الخصائص التالية:

- معدل ضربات القلب (bpm)
- تغير معدل ضربات القلب (SDNN و RMSSD)
- مدة مجمع QRS وسعته
- ارتفاع وميل جزء ST

## تغييرات على النموذج الجديد

النموذج الجديد يعمل مع هيكل بيانات EcgReading الجديد:

```dart
class EcgReading {
  final String? id;
  final double? bpm;
  final double? rawValue;
  final double? average;
  final int? maxInPeriod;
  final Object? timestamp;
  final String? userEmail;
  
  // ...
}
```

مسار Firebase الجديد هو `/ecg_data` بدلاً من المسارات القديمة.

## ملفات الإخراج

- **ecg_data_for_labeling.csv**: بيانات ECG المعالجة للتدريب
- **ecg_model**: مجلد نموذج TensorFlow المحفوظ
- **ecg_model.tflite**: نموذج TensorFlow Lite للنشر
- **scaler.pkl**: StandardScaler لتطبيع الخصائص
- **training_history.png**: رسم لمقاييس التدريب والتحقق

## التكامل مع تطبيق Flutter

يتم استخدام نموذج TensorFlow Lite بواسطة فئة `TFLiteService` في تطبيق Flutter لإجراء استدلال على الجهاز لتحليل ECG. يتوقع النموذج المدخلات على شكل خريطة من الخصائص، حيث يتم استخلاص هذه الخصائص من بيانات ECG الخام.

## خطة الدمج الجديدة

نماذج الخدمة الجديدة تتبع هيكل البيانات التالي:

1. **EcgDataService**: يقرأ بيانات ECG من مسار `/ecg_data` ويعرضها كتدفق من كائنات `EcgReading`.
2. **OptimizedECGService**: يحلل بيانات ECG باستخدام نموذج TensorFlow Lite ويعرض نتائج التحليل.
3. **ECGService**: واجهة بسيطة تستخدم الخدمتين السابقتين.

الدفق المنطقي:
1. يقوم `EcgDataService` بقراءة أحدث البيانات من `/ecg_data/latest`
2. يتلقى `OptimizedECGService` البيانات، ويستخلص الخصائص، ويقوم بالتحليل
3. تستخدم الشاشات تدفق البيانات من `ECGService` للعرض التفاعلي 