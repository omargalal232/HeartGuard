#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HeartGuard Firebase ECG Data Extractor
======================================
هذا السكريبت يستخرج بيانات ECG من قاعدة بيانات Firebase Realtime Database
ويحفظها في ملف CSV للاستخدام في تدريب النموذج.
"""

import os
import json
import pandas as pd
import firebase_admin
from firebase_admin import credentials, db
import datetime
import logging
import argparse

# تكوين السجلات
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='firebase_data_extraction.log',
    filemode='w'
)
logger = logging.getLogger('firebase_data_extractor')

# اضافة معالج لعرض السجلات في وحدة التحكم
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

class FirebaseDataExtractor:
    """فئة لاستخراج بيانات ECG من Firebase وتحويلها إلى تنسيق مناسب للتدريب"""
    
    def __init__(self, firebase_creds_path='firebase-credentials.json', output_dir='data_output'):
        """
        تهيئة المستخرج مع إعدادات الاتصال.
        
        Parameters:
        -----------
        firebase_creds_path : str
            مسار ملف اعتماد Firebase JSON
        output_dir : str
            المجلد الذي سيتم حفظ البيانات المستخرجة فيه
        """
        self.firebase_creds_path = firebase_creds_path
        self.output_dir = output_dir
        
        # تأكد من وجود المجلد
        os.makedirs(self.output_dir, exist_ok=True)
        
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
    
    def debug_firebase_structure(self):
        """طباعة هيكل قاعدة بيانات Firebase للتصحيح"""
        logger.info("Debugging Firebase database structure...")
        
        try:
            # الحصول على بيانات الجذر
            root_ref = db.reference('/')
            root_data = root_ref.get()
            
            if not root_data:
                logger.error("Firebase database is empty or cannot be accessed.")
                return
            
            # عرض المفاتيح الرئيسية
            logger.info("Firebase root paths:")
            for key in root_data.keys():
                logger.info(f"- {key}")
            
            # فحص مسار المستخدمين
            if 'users' in root_data:
                users_ref = db.reference('/users')
                users_data = users_ref.get()
                
                if users_data:
                    user_count = len(users_data)
                    logger.info(f"Found {user_count} users in Firebase.")
                    
                    # عرض معرفات المستخدمين
                    logger.info("User IDs:")
                    for user_id in users_data.keys():
                        logger.info(f"- {user_id}")
                        
                    # فحص البيانات لمستخدم واحد كعينة
                    sample_user_id = list(users_data.keys())[0]
                    logger.info(f"Sample user data structure for user {sample_user_id}:")
                    
                    sample_user = users_data[sample_user_id]
                    for top_level_key in sample_user.keys():
                        logger.info(f"  - {top_level_key}")
                else:
                    logger.error("No users found in Firebase database.")
            
            # البحث عن بيانات ECG في أي موقع
            self._search_for_ecg_data(root_data)
            
            return root_data
        
        except Exception as e:
            logger.error(f"Error debugging Firebase structure: {e}")
            raise

    def _search_for_ecg_data(self, data, path="", depth=0, max_depth=3):
        """البحث عن بيانات ECG في جميع أنحاء قاعدة البيانات"""
        if depth > max_depth or not isinstance(data, dict):
            return
        
        # البحث عن مفاتيح ذات صلة بـ ECG
        ecg_related_keys = [
            'ecg_data', 'ecg', 'ecgData', 'ecg_readings', 'readings', 
            'heartrate', 'heart_rate', 'bpm', 'realtime_ecg'
        ]
        
        for key, value in data.items():
            current_path = f"{path}/{key}" if path else key
            
            # فحص المفتاح الحالي
            if any(ecg_key in key.lower() for ecg_key in ecg_related_keys):
                logger.info(f"Potential ECG data found at path: {current_path}")
                
                # إذا كانت القيمة قاموسًا، طباعة المفاتيح الفرعية
                if isinstance(value, dict):
                    logger.info(f"  Subkeys: {list(value.keys())}")
                # إذا كانت القيمة قائمة، طباعة الحجم
                elif isinstance(value, list):
                    logger.info(f"  Array of size: {len(value)}")
            
            # الاستمرار في البحث بعمق
            if isinstance(value, dict):
                self._search_for_ecg_data(value, current_path, depth + 1, max_depth)

    def extract_ecg_data(self):
        """استخراج بيانات ECG من Firebase Realtime Database"""
        logger.info("Extracting ECG data from Firebase...")
        
        # أولاً، قم بتصحيح هيكل قاعدة البيانات
        self.debug_firebase_structure()
        
        all_readings = []
        
        try:
            # 1. محاولة الوصول إلى مسار المستخدمين الجديد
            ref = db.reference('/users')
            users = ref.get()
            
            if not users:
                logger.warning("No users found in Firebase database at /users path.")
                
                # 2. محاولة الوصول إلى مسار بديل
                ref = db.reference('/ecg_data')
                ecg_data = ref.get()
                
                if ecg_data:
                    logger.info("Found ECG data at /ecg_data path.")
                    
                    # معالجة البيانات بناءً على هيكلها
                    if isinstance(ecg_data, dict):
                        for key, value in ecg_data.items():
                            if isinstance(value, dict):
                                value['id'] = key
                                all_readings.append(value)
                            else:
                                # إذا كانت القيمة ليست قاموسًا، قم بإنشاء واحد
                                reading = {'id': key, 'raw_value': value}
                                all_readings.append(reading)
                else:
                    logger.warning("No ECG data found at /ecg_data path.")
                    
                    # 3. محاولة الوصول إلى مسار آخر بديل
                    ref = db.reference('/readings')
                    readings = ref.get()
                    
                    if readings:
                        logger.info("Found ECG data at /readings path.")
                        
                        # معالجة البيانات بناءً على هيكلها
                        if isinstance(readings, dict):
                            for key, value in readings.items():
                                if isinstance(value, dict):
                                    value['id'] = key
                                    all_readings.append(value)
                                else:
                                    reading = {'id': key, 'raw_value': value}
                                    all_readings.append(reading)
                    else:
                        logger.warning("No ECG data found at /readings path.")
                        logger.error("Could not find ECG data in any expected location.")
                
            else:
                logger.info(f"Found {len(users)} users in Firebase database.")
                
                # استخراج البيانات من مسار المستخدمين
                for user_id, user_data in users.items():
                    logger.info(f"Processing data for user: {user_id}")
                    
                    # 1. المسار الجديد: /users/{user_id}/ecg_data
                    if 'ecg_data' in user_data:
                        logger.info(f"Found ECG data for user {user_id} at ecg_data path")
                        
                        # جلب البيانات الأحدث
                        if 'latest' in user_data['ecg_data']:
                            reading = user_data['ecg_data']['latest']
                            if reading:
                                # إضافة معرف المستخدم وتسجيل القراءة
                                reading['user_id'] = user_id
                                all_readings.append(reading)
                        
                        # جلب البيانات التاريخية
                        if 'history' in user_data['ecg_data']:
                            history = user_data['ecg_data']['history']
                            if history:
                                for timestamp, reading in history.items():
                                    # إضافة معرف المستخدم وتسجيل القراءة
                                    if isinstance(reading, dict):  # تأكد من أن القراءة هي قاموس
                                        reading['user_id'] = user_id
                                        reading['history_timestamp'] = timestamp
                                        all_readings.append(reading)
                    
                    # 2. مسار بديل: /users/{user_id}/realtime_ecg
                    if 'realtime_ecg' in user_data:
                        logger.info(f"Found ECG data for user {user_id} at realtime_ecg path")
                        realtime_data = user_data['realtime_ecg']
                        
                        if isinstance(realtime_data, dict):
                            realtime_data['user_id'] = user_id
                            all_readings.append(realtime_data)
                        elif isinstance(realtime_data, list):
                            for reading in realtime_data:
                                if isinstance(reading, dict):
                                    reading['user_id'] = user_id
                                    all_readings.append(reading)
                    
                    # 3. مسار بديل: /users/{user_id}/readings
                    if 'readings' in user_data:
                        logger.info(f"Found ECG data for user {user_id} at readings path")
                        readings_data = user_data['readings']
                        
                        if isinstance(readings_data, dict):
                            for key, reading in readings_data.items():
                                if isinstance(reading, dict):
                                    reading['id'] = key
                                    reading['user_id'] = user_id
                                    all_readings.append(reading)
            
            logger.info(f"Extracted {len(all_readings)} ECG readings in total.")
            
            if all_readings:
                # تحويل البيانات إلى DataFrame
                self.data = pd.DataFrame(all_readings)
                
                # تخزين البيانات الخام
                self.data.to_csv(f"{self.output_dir}/raw_ecg_data.csv", index=False)
                logger.info(f"Raw data saved to {self.output_dir}/raw_ecg_data.csv")
                
                return self.data
            else:
                logger.error("No ECG readings were extracted.")
                return None
            
        except Exception as e:
            logger.error(f"Data extraction failed: {e}")
            raise
    
    def process_and_save_data(self, readings):
        """معالجة القراءات المستخرجة وحفظها في ملف CSV"""
        if readings is None or len(readings) == 0:
            logger.error("No ECG readings were extracted.")
            return None
        
        logger.info("Processing extracted readings...")
        
        try:
            # تحويل البيانات إلى DataFrame
            df = pd.DataFrame(readings)
            
            # إضافة عمود الوقت المعالج إذا كان موجودًا في شكل متسلسل
            if 'timestamp' in df.columns:
                # تحويل طوابع الوقت إلى تنسيق datetime
                df['processed_timestamp'] = df['timestamp'].apply(
                    lambda x: datetime.datetime.fromtimestamp(int(x)/1000) if isinstance(x, (int, float)) else x
                )
            
            # حفظ البيانات الخام
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            raw_data_path = f"{self.output_dir}/ecg_data_{timestamp}.csv"
            df.to_csv(raw_data_path, index=False)
            logger.info(f"Raw ECG data saved to {raw_data_path}")
            
            # ملف التسمية المستخدم لأداة التسمية
            labeling_path = f"{self.output_dir}/ecg_data_for_labeling.csv"
            
            # التأكد من وجود العمود 'id' لاستخدامه في أداة التسمية
            if 'id' not in df.columns:
                df['id'] = df.index.astype(str)
            
            df.to_csv(labeling_path, index=False)
            logger.info(f"Data for labeling saved to {labeling_path}")
            
            return df
            
        except Exception as e:
            logger.error(f"Processing and saving data failed: {e}")
            raise
    
    def load_existing_ecg_data(self, file_path):
        """تحميل بيانات ECG من ملف CSV موجود"""
        try:
            if not os.path.exists(file_path):
                logger.error(f"File {file_path} not found.")
                return None
                
            df = pd.read_csv(file_path)
            logger.info(f"Loaded {len(df)} rows from {file_path}")
            return df
            
        except Exception as e:
            logger.error(f"Error loading data from {file_path}: {e}")
            return None
    
    def merge_with_existing_data(self, new_data, existing_data_path):
        """دمج البيانات الجديدة مع البيانات الموجودة"""
        existing_data = self.load_existing_ecg_data(existing_data_path)
        
        if existing_data is None:
            logger.warning(f"No existing data found at {existing_data_path}. Using only new data.")
            return new_data
            
        if new_data is None:
            logger.warning("No new data to merge. Using only existing data.")
            return existing_data
            
        logger.info(f"Merging {len(new_data)} new records with {len(existing_data)} existing records.")
        
        try:
            # معالجة الدمج
            # إذا كان هناك عمود 'id' أو 'timestamp'، يمكن استخدامه للتحقق من التكرار
            
            # إنشاء نسخة من البيانات الموجودة
            merged_data = existing_data.copy()
            
            # تحديد مفتاح التكرار (id أو timestamp + user_id)
            if 'id' in new_data.columns and 'id' in existing_data.columns:
                # تجاهل السجلات الموجودة بالفعل
                existing_ids = set(existing_data['id'].astype(str))
                new_data_unique = new_data[~new_data['id'].astype(str).isin(existing_ids)]
                
                # إضافة البيانات الجديدة
                merged_data = pd.concat([merged_data, new_data_unique], ignore_index=True)
                logger.info(f"Added {len(new_data_unique)} unique records based on 'id'.")
                
            else:
                # إذا لم يكن هناك 'id' مناسب، فقط دمج البيانات وتحذير بشأن التكرار المحتمل
                merged_data = pd.concat([merged_data, new_data], ignore_index=True)
                logger.warning("No unique identifier found. Merged all records, potential duplicates may exist.")
            
            # حفظ البيانات المدمجة
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            merged_path = f"{self.output_dir}/ecg_data_merged_{timestamp}.csv"
            merged_data.to_csv(merged_path, index=False)
            logger.info(f"Merged data saved to {merged_path}")
            
            # تحديث ملف التسمية
            labeling_path = f"{self.output_dir}/ecg_data_for_labeling.csv"
            merged_data.to_csv(labeling_path, index=False)
            logger.info(f"Updated data for labeling saved to {labeling_path}")
            
            return merged_data
            
        except Exception as e:
            logger.error(f"Error merging data: {e}")
            return existing_data  # اعادة البيانات الموجودة في حالة الفشل
    
    def analyze_data_quality(self, data):
        """تحليل جودة البيانات وإنشاء تقرير"""
        if data is None or len(data) == 0:
            logger.error("No data to analyze.")
            return
            
        logger.info("Analyzing data quality...")
        
        try:
            # عدد السجلات
            record_count = len(data)
            
            # عدد القيم المفقودة لكل عمود
            missing_values = data.isnull().sum()
            
            # عدد القيم الفريدة لكل عمود
            unique_values = {col: data[col].nunique() for col in data.columns}
            
            # التحقق من القيم السالبة في raw_value (إذا كانت موجودة)
            negative_values = {}
            for col in ['raw_value', 'bpm', 'average']:
                if col in data.columns:
                    negative_values[col] = (data[col] < 0).sum()
            
            # إنشاء تقرير
            report = {
                "record_count": record_count,
                "missing_values": missing_values.to_dict(),
                "unique_values": unique_values,
                "negative_values": negative_values,
                "columns": list(data.columns)
            }
            
            # حفظ التقرير
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            report_path = f"{self.output_dir}/data_quality_report_{timestamp}.json"
            with open(report_path, 'w') as f:
                json.dump(report, f, indent=2)
                
            logger.info(f"Data quality report saved to {report_path}")
            
            # طباعة ملخص
            logger.info(f"Data summary - Records: {record_count}")
            for col, missing in missing_values.items():
                if missing > 0:
                    missing_percent = (missing / record_count) * 100
                    logger.info(f"Column '{col}' has {missing} missing values ({missing_percent:.2f}%)")
            
            return report
            
        except Exception as e:
            logger.error(f"Error analyzing data quality: {e}")
            raise

def main():
    """الوظيفة الرئيسية لاستخراج بيانات ECG من Firebase"""
    # إعداد متغيرات سطر الأوامر
    parser = argparse.ArgumentParser(description='Extract ECG data from Firebase.')
    parser.add_argument('--creds', type=str, default='firebase-credentials.json',
                        help='Path to Firebase credentials JSON file.')
    parser.add_argument('--output', type=str, default='data_output',
                        help='Directory to save output files.')
    parser.add_argument('--merge', type=str, default=None,
                        help='Path to existing CSV file to merge with new data.')
    args = parser.parse_args()
    
    try:
        # إنشاء مستخرج البيانات
        extractor = FirebaseDataExtractor(
            firebase_creds_path=args.creds,
            output_dir=args.output
        )
        
        # استخراج البيانات
        readings = extractor.extract_ecg_data()
        
        if readings is None or len(readings) == 0:
            logger.error("No ECG readings were extracted.")
            return
        
        # معالجة وحفظ البيانات
        new_data = extractor.process_and_save_data(readings)
        
        # دمج مع البيانات الموجودة إذا تم تحديد ملف
        if args.merge and os.path.exists(args.merge):
            logger.info(f"Merging with existing data from {args.merge}")
            final_data = extractor.merge_with_existing_data(new_data, args.merge)
        else:
            final_data = new_data
        
        # تحليل جودة البيانات
        extractor.analyze_data_quality(final_data)
        
        logger.info("Data extraction completed successfully.")
        
    except Exception as e:
        logger.error(f"An error occurred during data extraction: {e}", exc_info=True)

if __name__ == "__main__":
    main() 