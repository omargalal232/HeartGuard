#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
سكريبت اختبار نموذج HeartGuard ECG
===================================
هذا السكريبت يقوم باختبار نموذج تصنيف ECG الذي تم تدريبه مسبقاً
باستخدام بيانات اختبار لمختلف فئات أمراض القلب
"""

import os
import json
import numpy as np
import pickle
import tensorflow as tf
import random

# تحديد المسارات
MODEL_PATH = '../models/ecg_model.tflite'
SCALER_PATH = '../models/scaler.pkl'
METADATA_PATH = '../models/model_metadata.json'

class ECGModelTester:
    """فئة لاختبار نموذج ECG"""
    
    def __init__(self):
        """تهيئة المختبر بتحميل النموذج والبيانات الضرورية"""
        self.model = None
        self.scaler = None
        self.metadata = None
        self.input_features = None
        self.output_classes = None
        
        # تحميل البيانات اللازمة
        self._load_resources()
    
    def _load_resources(self):
        """تحميل النموذج والبيانات الوصفية ومعالج التطبيع"""
        print("جاري تحميل موارد النموذج...")
        
        # تحميل معالج التطبيع
        try:
            with open(SCALER_PATH, 'rb') as f:
                self.scaler = pickle.load(f)
            print("✓ تم تحميل معالج التطبيع")
        except Exception as e:
            print(f"❌ خطأ في تحميل معالج التطبيع: {e}")
            raise
        
        # تحميل البيانات الوصفية
        try:
            with open(METADATA_PATH, 'r') as f:
                self.metadata = json.load(f)
            self.input_features = self.metadata['input_features']
            self.output_classes = self.metadata['output_classes']
            print(f"✓ تم تحميل البيانات الوصفية")
            print(f"  - ميزات الإدخال: {self.input_features}")
            print(f"  - فئات الإخراج: {self.output_classes}")
        except Exception as e:
            print(f"❌ خطأ في تحميل البيانات الوصفية: {e}")
            raise
        
        # تحميل نموذج TFLite
        try:
            self.interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
            self.interpreter.allocate_tensors()
            
            # الحصول على تفاصيل الإدخال والإخراج
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            print("✓ تم تحميل نموذج TFLite")
            print(f"  - تفاصيل الإدخال: {self.input_details}")
            print(f"  - تفاصيل الإخراج: {self.output_details}")
        except Exception as e:
            print(f"❌ خطأ في تحميل نموذج TFLite: {e}")
            raise
    
    def _prepare_sample(self, condition):
        """إعداد عينة بيانات اختبار لفئة معينة"""
        # تعريف المعلمات لكل فئة (نفس القيم من سكريبت التدريب)
        class_params = {
            'normal': {
                'heart_rate': (60, 100),
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
        
        # الحصول على معلمات الفئة
        params = class_params[condition]
        
        # إنشاء قيم عشوائية ضمن النطاقات المحددة
        sample = {
            feature: random.uniform(*params[feature]) for feature in self.input_features
        }
        
        return sample
    
    def predict(self, sample):
        """التنبؤ بفئة عينة ECG"""
        # تحويل العينة إلى مصفوفة بترتيب الميزات المطلوب
        feature_values = np.array([[sample[feature] for feature in self.input_features]])
        
        # تطبيع البيانات
        normalized_features = self.scaler.transform(feature_values)
        
        # تحويل البيانات إلى النوع المطلوب (عادة float32)
        input_data = normalized_features.astype(np.float32)
        
        # تعيين بيانات الإدخال
        self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
        
        # تنفيذ الاستدلال
        self.interpreter.invoke()
        
        # الحصول على نتائج التنبؤ
        output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
        
        # الحصول على الفئة المتنبأ بها
        predicted_class_idx = np.argmax(output_data[0])
        predicted_class = self.output_classes[predicted_class_idx]
        
        # الحصول على الاحتمالات
        probabilities = output_data[0]
        
        return {
            'class': predicted_class,
            'probabilities': {cls: float(prob) for cls, prob in zip(self.output_classes, probabilities)}
        }
    
    def test_model(self):
        """اختبار النموذج بعينات من جميع الفئات"""
        print("\nاختبار النموذج بعينات من جميع الفئات:")
        print("======================================")
        
        for condition in self.output_classes:
            print(f"\nاختبار فئة: {condition}")
            print("-" * 20)
            
            # إعداد 3 عينات من كل فئة
            for i in range(3):
                # إعداد عينة
                sample = self._prepare_sample(condition)
                
                # عرض قيم الميزات
                print(f"\nعينة اختبار #{i+1}:")
                for feature, value in sample.items():
                    print(f"  {feature}: {value:.2f}")
                
                # تنفيذ التنبؤ
                result = self.predict(sample)
                
                # عرض النتائج
                print("\nنتيجة التنبؤ:")
                print(f"  الفئة المتنبأ بها: {result['class']}")
                print("  الاحتمالات:")
                for cls, prob in result['probabilities'].items():
                    print(f"    {cls}: {prob:.4f}")
                
                # التحقق من صحة التنبؤ
                is_correct = result['class'] == condition
                print(f"  صحة التنبؤ: {'✓' if is_correct else '❌'}")
                
                print()
        
        print("\nاكتمل اختبار النموذج!")

def main():
    """الدالة الرئيسية"""
    print("بدء اختبار نموذج ECG...")
    
    try:
        # إنشاء مختبر النموذج
        tester = ECGModelTester()
        
        # اختبار النموذج
        tester.test_model()
        
    except Exception as e:
        print(f"حدث خطأ أثناء اختبار النموذج: {e}")

if __name__ == "__main__":
    main() 