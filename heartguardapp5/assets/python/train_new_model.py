#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HeartGuard ECG Classification Model Training Script
=================================================
هذا السكربت يستخرج البيانات من Firebase، يعالجها، ويدرب نموذج لتصنيف
إشارات ECG إلى فئات مختلفة (طبيعي، الرجفان الأذيني، نوبة قلبية، إلخ).
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import datetime
import firebase_admin
from firebase_admin import credentials, db
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import confusion_matrix, classification_report, roc_curve, auc
import pickle
import logging
import time
import random

# تكوين السجلات
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='ecg_model_training.log',
    filemode='w'
)
logger = logging.getLogger('ecg_model_training')

# اضافة معالج لعرض السجلات في وحدة التحكم
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

class ECGModelTrainer:
    """فئة لتدريب نموذج تصنيف ECG"""
    
    def __init__(self, firebase_creds_path='firebase-credentials.json'):
        """
        تهيئة المدرب مع إعدادات البيانات والنموذج.
        
        Parameters:
        -----------
        firebase_creds_path : str
            مسار ملف اعتماد Firebase JSON
        """
        self.firebase_creds_path = firebase_creds_path
        self.data = None
        self.features = None
        self.labels = None
        self.model = None
        self.scaler = None
        self.output_dir = 'model_output'
        
        # تأكد من وجود الدليل
        os.makedirs(self.output_dir, exist_ok=True)
        
        # فئات الإخراج المعروفة من model_metadata.json
        self.classes = ['normal', 'arrhythmia', 'afib', 'heart_attack']
        
        # ميزات الإدخال المعروفة من model_metadata.json
        self.input_features = [
            'heart_rate', 'hrv_sdnn', 'hrv_rmssd', 
            'qrs_duration', 'qrs_amplitude', 
            'st_elevation', 'st_slope'
        ]
        
        # تهيئة Firebase
        self._initialize_firebase()
        
    def _initialize_firebase(self):
        """تهيئة الاتصال بـ Firebase"""
        try:
            # تجنب إعادة التهيئة إذا كان Firebase مُهيأ بالفعل
            if not firebase_admin._apps:
                cred = credentials.Certificate(self.firebase_creds_path)
                firebase_admin.initialize_app(cred, {
                    'databaseURL': 'https://heart-guard-1c49e-default-rtdb.firebaseio.com/'
                })
                logger.info("Firebase initialized successfully.")
            else:
                logger.info("Firebase already initialized.")
        except Exception as e:
            logger.error(f"Firebase initialization failed: {e}")
            raise
    
    def extract_data_from_firebase(self):
        """استخراج بيانات ECG من Firebase Realtime Database"""
        logger.info("Extracting data from Firebase...")
        
        all_readings = []
        
        try:
            # الوصول إلى مرجع قاعدة البيانات
            ref = db.reference('users')
            users = ref.get()
            
            if not users:
                logger.error("No users found in Firebase database.")
                return
            
            # تكرار خلال المستخدمين
            for user_id, user_data in users.items():
                logger.info(f"Processing data for user: {user_id}")
                
                # الوصول إلى بيانات ECG من المسار الجديد
                if 'ecg_data' in user_data:
                    logger.info(f"Found ECG data for user {user_id}")
                    
                    # جلب البيانات الأحدث
                    if 'latest' in user_data['ecg_data']:
                        reading = user_data['ecg_data']['latest']
                        if reading:
                            all_readings.append(reading)
                    
                    # جلب البيانات التاريخية
                    if 'history' in user_data['ecg_data']:
                        history = user_data['ecg_data']['history']
                        if history:
                            for timestamp, reading in history.items():
                                all_readings.append(reading)
            
            logger.info(f"Extracted {len(all_readings)} ECG readings in total.")
            
            # تحويل البيانات إلى DataFrame
            self.data = pd.DataFrame(all_readings)
            
            # تخزين البيانات الخام
            self.data.to_csv(f"{self.output_dir}/raw_ecg_data.csv", index=False)
            logger.info(f"Raw data saved to {self.output_dir}/raw_ecg_data.csv")
            
            return self.data
            
        except Exception as e:
            logger.error(f"Data extraction failed: {e}")
            raise
    
    def process_data(self):
        """معالجة وتنظيف بيانات ECG الخام"""
        logger.info("Processing raw ECG data...")
        
        if self.data is None or len(self.data) == 0:
            logger.error("No data available for processing.")
            return
        
        try:
            # التعامل مع القيم المفقودة
            logger.info("Handling missing values...")
            self.data = self.data.dropna(subset=['bpm', 'raw_value'])
            
            # إنشاء ميزات إضافية
            logger.info("Creating additional features...")
            self._calculate_features()
            
            # قد تحتاج إلى تسمية البيانات الآن
            # يمكن استخدام data_labeler.py 
            # البدائل: استيراد تسميات موجودة أو استخدام نهج شبه متسلسل
            logger.info("Data processing completed.")
            
            # حفظ البيانات المعالجة
            self.data.to_csv(f"{self.output_dir}/processed_ecg_data.csv", index=False)
            logger.info(f"Processed data saved to {self.output_dir}/processed_ecg_data.csv")
            
            return self.data
            
        except Exception as e:
            logger.error(f"Data processing failed: {e}")
            raise
    
    def _calculate_features(self):
        """حساب الميزات من البيانات الخام لنموذج التعلم الآلي"""
        
        # بدلاً من هذا، ستحتاج إلى إنشاء جميع الميزات المطلوبة
        # بناءً على البيانات المتاحة
        
        # مثال (يجب تعديله حسب هيكل البيانات الفعلي):
        if 'raw_value' in self.data.columns:
            # تحويل raw_value إلى قيم متعددة إذا كانت سلسلة نصية بها أرقام مفصولة بفواصل
            if self.data['raw_value'].dtype == 'object' and isinstance(self.data.iloc[0]['raw_value'], str):
                self.data['raw_values'] = self.data['raw_value'].apply(
                    lambda x: [float(v) for v in x.split(',')]
                )
            elif self.data['raw_value'].dtype == 'float' or self.data['raw_value'].dtype == 'int':
                # إذا كانت raw_value قيمة واحدة فقط، سنحتاج إلى طريقة بديلة
                logger.warning("raw_value contains single values, not time series data.")
                self.data['raw_values'] = [[v] for v in self.data['raw_value']]
        
        # إنشاء ميزات إضافية من سلسلة البيانات
        self.data['hrv_sdnn'] = self.data.apply(
            lambda row: np.std(row['raw_values']) if 'raw_values' in row and row['raw_values'] else np.nan, 
            axis=1
        )
        
        # إنشاء المزيد من الميزات المطلوبة
        # الميزات المطلوبة: heart_rate, hrv_sdnn, hrv_rmssd, qrs_duration, qrs_amplitude, st_elevation, st_slope
        
        # استخدام BPM المتاح بالفعل
        self.data['heart_rate'] = self.data['bpm']
        
        # حساب ميزات بديلة إذا كانت بعض الميزات المطلوبة غير متوفرة
        self.data['hrv_rmssd'] = self.data.apply(
            lambda row: np.sqrt(np.mean(np.square(np.diff(row['raw_values'])))) if 'raw_values' in row and len(row['raw_values']) > 1 else np.nan,
            axis=1
        )
        
        # تقدير قيم للميزات المتبقية استنادًا إلى الخصائص الإحصائية
        self.data['qrs_duration'] = self.data.apply(
            lambda row: np.percentile(row['raw_values'], 90) - np.percentile(row['raw_values'], 10) if 'raw_values' in row and len(row['raw_values']) > 1 else np.nan,
            axis=1
        )
        
        self.data['qrs_amplitude'] = self.data.apply(
            lambda row: max(row['raw_values']) - min(row['raw_values']) if 'raw_values' in row and len(row['raw_values']) > 0 else np.nan,
            axis=1
        )
        
        # ميزات إضافية (قد تحتاج إلى تعديل هذه التقديرات)
        self.data['st_elevation'] = self.data.apply(
            lambda row: np.mean(row['raw_values']) if 'raw_values' in row and len(row['raw_values']) > 0 else np.nan,
            axis=1
        )
        
        self.data['st_slope'] = self.data.apply(
            lambda row: np.mean(np.diff(row['raw_values'])) if 'raw_values' in row and len(row['raw_values']) > 1 else np.nan,
            axis=1
        )
        
        logger.info("Feature calculation completed.")
    
    def prepare_training_data(self):
        """إعداد البيانات للتدريب (بعد التسمية)"""
        logger.info("Preparing training data...")
        
        if self.data is None or len(self.data) == 0:
            logger.error("No data available for training.")
            return
        
        try:
            # تأكد من وجود عمود التسمية 'condition'
            if 'condition' not in self.data.columns:
                logger.error("No 'condition' column found. Please label the data first.")
                logger.info("You can use the data_labeler.py script to label your data.")
                return
            
            # تنظيف وإعداد البيانات
            data_for_training = self.data.dropna(subset=['condition'] + self.input_features)
            
            # تقسيم الميزات والتسميات
            self.features = data_for_training[self.input_features].values
            self.labels = data_for_training['condition'].values
            
            # معالجة وتحويل التسمية إلى تمثيل رقمي
            label_to_idx = {label: i for i, label in enumerate(self.classes)}
            self.labels = np.array([label_to_idx.get(label, 0) for label in self.labels])
            
            # تطبيع البيانات
            self.scaler = StandardScaler()
            self.features = self.scaler.fit_transform(self.features)
            
            # حفظ Scaler
            with open(f"{self.output_dir}/scaler.pkl", 'wb') as f:
                pickle.dump(self.scaler, f)
            
            # تقسيم البيانات
            features_train, features_val, labels_train, labels_val = train_test_split(
                self.features, self.labels, test_size=0.2, random_state=42, stratify=self.labels
            )
            
            logger.info(f"Training data prepared: {len(features_train)} training samples, {len(features_val)} validation samples")
            
            return features_train, features_val, labels_train, labels_val
            
        except Exception as e:
            logger.error(f"Data preparation failed: {e}")
            raise
    
    def build_model(self):
        """إنشاء نموذج تصنيف ECG"""
        logger.info("Building the model...")
        
        try:
            # عدد الفئات
            num_classes = len(self.classes)
            
            # عدد الميزات الإدخالية
            input_dim = len(self.input_features)
            
            # إنشاء نموذج sequential
            model = tf.keras.Sequential([
                tf.keras.layers.Input(shape=(input_dim,)),
                tf.keras.layers.Dense(64, activation='relu'),
                tf.keras.layers.BatchNormalization(),
                tf.keras.layers.Dropout(0.3),
                tf.keras.layers.Dense(32, activation='relu'),
                tf.keras.layers.BatchNormalization(),
                tf.keras.layers.Dropout(0.2),
                tf.keras.layers.Dense(num_classes, activation='softmax')
            ])
            
            # تجميع النموذج
            model.compile(
                optimizer='adam',
                loss='sparse_categorical_crossentropy',
                metrics=['accuracy']
            )
            
            # طباعة ملخص النموذج
            model.summary()
            
            self.model = model
            logger.info("Model built successfully.")
            
            return self.model
        
        except Exception as e:
            logger.error(f"Model building failed: {e}")
            raise
    
    def train_model(self, features_train, labels_train, features_val, labels_val, epochs=50):
        """تدريب نموذج ECG"""
        logger.info(f"Training model for {epochs} epochs...")
        
        if self.model is None:
            logger.error("No model has been built. Call build_model() first.")
            return
        
        try:
            # تعريف Early stopping للحماية من overfitting
            early_stopping = tf.keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=10,
                restore_best_weights=True
            )
            
            # تعريف ModelCheckpoint لحفظ أفضل نموذج
            checkpoint = tf.keras.callbacks.ModelCheckpoint(
                f"{self.output_dir}/best_model.h5",
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1
            )
            
            # تدريب النموذج
            history = self.model.fit(
                features_train, labels_train,
                validation_data=(features_val, labels_val),
                epochs=epochs,
                batch_size=32,
                callbacks=[early_stopping, checkpoint],
                verbose=1
            )
            
            # حفظ تاريخ التدريب
            with open(f"{self.output_dir}/training_history.json", 'w') as f:
                json.dump({
                    'accuracy': [float(x) for x in history.history['accuracy']],
                    'val_accuracy': [float(x) for x in history.history['val_accuracy']],
                    'loss': [float(x) for x in history.history['loss']],
                    'val_loss': [float(x) for x in history.history['val_loss']]
                }, f)
            
            # رسم تاريخ التدريب
            self._plot_training_history(history)
            
            logger.info("Model training completed.")
            
            return history
        
        except Exception as e:
            logger.error(f"Model training failed: {e}")
            raise
    
    def _plot_training_history(self, history):
        """رسم منحنيات الدقة والخسارة"""
        plt.figure(figsize=(12, 4))
        
        # رسم منحنى الدقة
        plt.subplot(1, 2, 1)
        plt.plot(history.history['accuracy'])
        plt.plot(history.history['val_accuracy'])
        plt.title('Model Accuracy')
        plt.ylabel('Accuracy')
        plt.xlabel('Epoch')
        plt.legend(['Train', 'Validation'], loc='lower right')
        
        # رسم منحنى الخسارة
        plt.subplot(1, 2, 2)
        plt.plot(history.history['loss'])
        plt.plot(history.history['val_loss'])
        plt.title('Model Loss')
        plt.ylabel('Loss')
        plt.xlabel('Epoch')
        plt.legend(['Train', 'Validation'], loc='upper right')
        
        plt.tight_layout()
        plt.savefig(f"{self.output_dir}/training_history.png")
        plt.close()
    
    def evaluate_model(self, features_val, labels_val):
        """تقييم أداء النموذج"""
        logger.info("Evaluating the model...")
        
        if self.model is None:
            logger.error("No model has been trained. Train the model first.")
            return
        
        try:
            # تقييم على بيانات التحقق
            loss, accuracy = self.model.evaluate(features_val, labels_val, verbose=0)
            logger.info(f"Validation Loss: {loss:.4f}")
            logger.info(f"Validation Accuracy: {accuracy:.4f}")
            
            # التنبؤات للمقاييس المفصلة
            predictions = self.model.predict(features_val)
            predicted_classes = np.argmax(predictions, axis=1)
            
            # تقرير تصنيف
            class_names = self.classes
            report = classification_report(labels_val, predicted_classes, target_names=class_names)
            logger.info(f"Classification Report:\n{report}")
            
            # حفظ التقرير في ملف
            with open(f"{self.output_dir}/classification_report.txt", 'w') as f:
                f.write(report)
            
            # مصفوفة الارتباك
            cm = confusion_matrix(labels_val, predicted_classes)
            self._plot_confusion_matrix(cm, class_names)
            
            # منحنيات ROC
            self._plot_roc_curves(labels_val, predictions, class_names)
            
            # حفظ نتائج التقييم
            evaluation_results = {
                'accuracy': float(accuracy),
                'loss': float(loss),
                'confusion_matrix': cm.tolist(),
                'classification_report': report
            }
            
            with open(f"{self.output_dir}/model_evaluation.json", 'w') as f:
                json.dump(evaluation_results, f, indent=2)
            
            logger.info("Model evaluation completed and saved.")
            
            return evaluation_results
        
        except Exception as e:
            logger.error(f"Model evaluation failed: {e}")
            raise
    
    def _plot_confusion_matrix(self, cm, class_names):
        """رسم مصفوفة الارتباك"""
        plt.figure(figsize=(10, 8))
        plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
        plt.title('Confusion Matrix')
        plt.colorbar()
        
        tick_marks = np.arange(len(class_names))
        plt.xticks(tick_marks, class_names, rotation=45)
        plt.yticks(tick_marks, class_names)
        
        fmt = 'd'
        thresh = cm.max() / 2.
        for i in range(cm.shape[0]):
            for j in range(cm.shape[1]):
                plt.text(j, i, format(cm[i, j], fmt),
                        horizontalalignment="center",
                        color="white" if cm[i, j] > thresh else "black")
        
        plt.tight_layout()
        plt.ylabel('True label')
        plt.xlabel('Predicted label')
        plt.savefig(f"{self.output_dir}/confusion_matrix.png")
        plt.close()
    
    def _plot_roc_curves(self, y_true, y_pred, class_names):
        """رسم منحنيات ROC لكل فئة"""
        plt.figure(figsize=(10, 8))
        
        # تحويل y_true إلى one-hot encoding
        y_true_one_hot = tf.keras.utils.to_categorical(y_true, num_classes=len(class_names))
        
        # حساب ROC curve و AUC لكل فئة
        for i, class_name in enumerate(class_names):
            fpr, tpr, _ = roc_curve(y_true_one_hot[:, i], y_pred[:, i])
            roc_auc = auc(fpr, tpr)
            plt.plot(fpr, tpr, label=f'{class_name} (AUC = {roc_auc:.2f})')
        
        plt.plot([0, 1], [0, 1], 'k--')
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title('Receiver Operating Characteristic (ROC) Curves')
        plt.legend(loc='lower right')
        plt.savefig(f"{self.output_dir}/roc_curves.png")
        plt.close()
    
    def convert_to_tflite(self):
        """تحويل النموذج إلى صيغة TensorFlow Lite"""
        logger.info("Converting model to TensorFlow Lite format...")
        
        if self.model is None:
            logger.error("No model has been trained. Train the model first.")
            return
        
        try:
            # احفظ نموذج TensorFlow النهائي
            self.model.save(f"{self.output_dir}/ecg_model")
            
            # تحويل إلى TFLite
            converter = tf.lite.TFLiteConverter.from_saved_model(f"{self.output_dir}/ecg_model")
            tflite_model = converter.convert()
            
            # حفظ نموذج TFLite
            tflite_model_path = f"{self.output_dir}/ecg_model.tflite"
            with open(tflite_model_path, 'wb') as f:
                f.write(tflite_model)
            
            logger.info(f"TFLite model saved to {tflite_model_path}")
            
            # التحقق من حجم النموذج
            tflite_size = os.path.getsize(tflite_model_path) / 1024
            logger.info(f"TFLite model size: {tflite_size:.2f} KB")
            
            # إنشاء ملف metadata
            self._create_model_metadata()
            
            # نسخ النموذج ومعالج القياس إلى مسار التطبيق
            deployment_dir = '../models'
            os.makedirs(deployment_dir, exist_ok=True)
            
            # نسخ النموذج
            import shutil
            shutil.copy(tflite_model_path, f"{deployment_dir}/ecg_model.tflite")
            
            # نسخ معالج القياس
            shutil.copy(f"{self.output_dir}/scaler.pkl", f"{deployment_dir}/scaler.pkl")
            
            # نسخ معلومات النموذج
            shutil.copy(f"{self.output_dir}/model_metadata.json", f"{deployment_dir}/model_metadata.json")
            
            logger.info(f"Model, scaler, and metadata copied to {deployment_dir}")
            
            return tflite_model_path
        
        except Exception as e:
            logger.error(f"TFLite conversion failed: {e}")
            raise
    
    def _create_model_metadata(self):
        """إنشاء ملف metadata للنموذج"""
        try:
            # إنشاء هيكل metadata
            metadata = {
                "model_name": "ECG Classification Model",
                "version": "2.0.0",
                "created_at": datetime.datetime.now().strftime("%Y-%m-%d"),
                "description": "TFLite model for ECG classification",
                "input_features": self.input_features,
                "output_classes": self.classes,
                "normalization": {}
            }
            
            # إضافة معلومات التطبيع
            for i, feature in enumerate(self.input_features):
                metadata["normalization"][feature] = {
                    "mean": float(self.scaler.mean_[i]),
                    "std": float(self.scaler.scale_[i])
                }
            
            # حفظ ملف metadata
            with open(f"{self.output_dir}/model_metadata.json", 'w') as f:
                json.dump(metadata, f, indent=2)
            
            logger.info(f"Model metadata saved to {self.output_dir}/model_metadata.json")
            
        except Exception as e:
            logger.error(f"Error creating metadata: {e}")
            raise

    def generate_test_data(self, num_samples=100):
        """توليد بيانات اختبار افتراضية للتدريب"""
        logger.info(f"Generating {num_samples} synthetic test samples...")
        
        # إنشاء DataFrame فارغ
        data = []
        
        # تعريف المعلمات لكل فئة
        class_params = {
            'normal': {
                'heart_rate': (60, 100),  # (min, max)
                'hrv_sdnn': (30, 60),
                'hrv_rmssd': (20, 40),
                'qrs_duration': (80, 110),
                'qrs_amplitude': (0.8, 1.2),
                'st_elevation': (0.0, 0.1),
                'st_slope': (0.0, 0.05)
            },
            'arrhythmia': {
                'heart_rate': (40, 180),
                'hrv_sdnn': (60, 120),
                'hrv_rmssd': (40, 100),
                'qrs_duration': (110, 150),
                'qrs_amplitude': (0.5, 1.5),
                'st_elevation': (0.0, 0.2),
                'st_slope': (-0.1, 0.1)
            },
            'afib': {
                'heart_rate': (100, 160),
                'hrv_sdnn': (80, 150),
                'hrv_rmssd': (60, 120),
                'qrs_duration': (80, 120),
                'qrs_amplitude': (0.7, 1.3),
                'st_elevation': (0.0, 0.1),
                'st_slope': (-0.05, 0.05)
            },
            'heart_attack': {
                'heart_rate': (40, 180),
                'hrv_sdnn': (20, 80),
                'hrv_rmssd': (15, 60),
                'qrs_duration': (80, 130),
                'qrs_amplitude': (0.4, 1.0),
                'st_elevation': (0.2, 0.5),
                'st_slope': (0.1, 0.3)
            }
        }
        
        # توليد بيانات لكل فئة
        for condition in self.classes:
            num_condition_samples = num_samples // len(self.classes)
            params = class_params[condition]
            
            for i in range(num_condition_samples):
                # توليد قيم عشوائية ضمن النطاقات المحددة
                sample = {
                    'id': f"{condition}_{i}",
                    'heart_rate': random.uniform(*params['heart_rate']),
                    'hrv_sdnn': random.uniform(*params['hrv_sdnn']),
                    'hrv_rmssd': random.uniform(*params['hrv_rmssd']),
                    'qrs_duration': random.uniform(*params['qrs_duration']),
                    'qrs_amplitude': random.uniform(*params['qrs_amplitude']),
                    'st_elevation': random.uniform(*params['st_elevation']),
                    'st_slope': random.uniform(*params['st_slope']),
                    'condition': condition,
                    'timestamp': int(datetime.datetime.now().timestamp() * 1000)
                }
                
                # إنشاء سلسلة من القيم الخام
                raw_values = []
                for _ in range(250):  # 250 قيمة لكل قراءة
                    # إضافة ضوضاء عشوائية حول قيمة مرجعية
                    base_value = 0.5 + 0.5 * np.sin(np.pi * _ / 50)
                    
                    # إضافة شذوذ حسب الفئة
                    if condition == 'arrhythmia':
                        # إضافة اضطرابات عشوائية
                        if random.random() < 0.2:
                            base_value += random.uniform(-0.5, 0.5)
                    elif condition == 'afib':
                        # نمط غير منتظم
                        base_value += 0.2 * np.sin(np.pi * _ / (10 + 5 * np.sin(_ / 10)))
                    elif condition == 'heart_attack':
                        # ارتفاع ST
                        if 100 <= _ <= 150:
                            base_value += params['st_elevation'][0]
                    
                    # إضافة ضوضاء طبيعية
                    noise = random.uniform(-0.1, 0.1)
                    raw_values.append(base_value + noise)
                
                sample['raw_value'] = ','.join([str(v) for v in raw_values])
                sample['raw_values'] = raw_values  # قائمة القيم
                
                data.append(sample)
        
        # تحويل إلى DataFrame
        self.data = pd.DataFrame(data)
        
        # حفظ البيانات الاصطناعية
        self.data.to_csv(f"{self.output_dir}/synthetic_ecg_data.csv", index=False)
        logger.info(f"Synthetic data saved to {self.output_dir}/synthetic_ecg_data.csv")
        
        return self.data

def main():
    """الوظيفة الرئيسية لتشغيل عملية التدريب"""
    # إنشاء مجلد للنتائج بطابع زمني
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = f"model_output_{timestamp}"
    os.makedirs(output_dir, exist_ok=True)
    
    # سجل بداية العملية
    logger.info(f"===== Starting ECG Model Training Process at {timestamp} =====")
    
    try:
        # إنشاء مدرب النموذج
        trainer = ECGModelTrainer(firebase_creds_path='firebase-credentials.json')
        trainer.output_dir = output_dir
        
        # محاولة استخراج البيانات الحقيقية من Firebase أولاً
        logger.info("Attempting to extract real data from Firebase first...")
        trainer.extract_data_from_firebase()
        
        # فحص إذا كانت البيانات جاهزة للتدريب
        if trainer.data is None or len(trainer.data) == 0:
            logger.warning("No real data found in Firebase or data extraction failed.")
            
            # الخيار 1: توليد بيانات اصطناعية كبديل
            logger.info("Generating synthetic data as a fallback...")
            trainer.generate_test_data(num_samples=400)
        else:
            logger.info(f"Successfully extracted {len(trainer.data)} real data points from Firebase.")
            
            # معالجة البيانات الحقيقية
            logger.info("Processing real data...")
            trainer.process_data()
        
        # التحقق من وجود عمود التسمية
        if 'condition' not in trainer.data.columns:
            logger.warning("No 'condition' column found. Please label the data before training.")
            
            # حفظ البيانات لاستخدامها مع أداة تسمية البيانات
            processed_data_path = f"{output_dir}/processed_ecg_data.csv"
            trainer.data.to_csv(processed_data_path, index=False)
            
            # تنفيذ أداة تسمية البيانات
            logger.info(f"Please run: python data_labeler.py {processed_data_path}")
            logger.info("Exiting. Resume training after labeling your data.")
            return
        
        # إعداد بيانات التدريب
        features_train, features_val, labels_train, labels_val = trainer.prepare_training_data()
        
        # بناء النموذج
        trainer.build_model()
        
        # تدريب النموذج
        trainer.train_model(features_train, labels_train, features_val, labels_val, epochs=100)
        
        # تقييم النموذج
        trainer.evaluate_model(features_val, labels_val)
        
        # تحويل النموذج إلى TFLite
        trainer.convert_to_tflite()
        
        logger.info(f"===== ECG Model Training Process Completed =====")
        logger.info(f"Model and related files available in: {output_dir}")
        logger.info(f"Model has been deployed to: ../models")
        
    except Exception as e:
        logger.error(f"Training process failed: {e}", exc_info=True)
    
if __name__ == "__main__":
    main() 