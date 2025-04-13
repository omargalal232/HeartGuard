#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HeartGuard ECG Data Labeler
===========================
سكريبت لتسمية بيانات ECG المستخرجة من Firebase للتدريب
"""

import os
import pandas as pd
import numpy as np
import sys
import matplotlib.pyplot as plt
from datetime import datetime

class ECGDataLabeler:
    """فئة مسؤولة عن تسمية بيانات ECG للتدريب"""
    
    def __init__(self, input_file, output_file=None):
        """
        تهيئة الأداة مع ملفات الإدخال والإخراج
        
        Parameters:
        -----------
        input_file : str
            مسار ملف البيانات المراد تسميته (CSV)
        output_file : str
            مسار ملف الإخراج (CSV) للبيانات المسماة
        """
        self.input_file = input_file
        
        if output_file is None:
            base_name = os.path.splitext(input_file)[0]
            self.output_file = f"{base_name}_labeled.csv"
        else:
            self.output_file = output_file
            
        self.data = None
        
    def load_data(self):
        """تحميل البيانات من ملف CSV"""
        try:
            self.data = pd.read_csv(self.input_file)
            print(f"تم تحميل {len(self.data)} من القراءات من {self.input_file}")
            
            # عرض معلومات عن البيانات
            print("\nمعلومات عن البيانات:")
            print(f"الأعمدة: {list(self.data.columns)}")
            
            # فحص القيم المفقودة
            missing_values = self.data.isnull().sum()
            print("\nالقيم المفقودة:")
            for col, missing in missing_values.items():
                if missing > 0:
                    print(f"  {col}: {missing} ({missing/len(self.data)*100:.2f}%)")
            
            return True
        except Exception as e:
            print(f"خطأ في تحميل البيانات: {e}")
            return False
            
    def auto_label_data(self):
        """تسمية البيانات تلقائياً بناءً على القواعد"""
        if self.data is None:
            print("لا توجد بيانات محملة! قم بتحميل البيانات أولاً.")
            return False
            
        print("\nبدء التسمية التلقائية للبيانات...")
        
        # التأكد من وجود الأعمدة الضرورية
        required_cols = ['bpm', 'raw_value', 'average']
        missing_cols = [col for col in required_cols if col not in self.data.columns]
        
        if missing_cols:
            print(f"الأعمدة التالية غير موجودة: {missing_cols}")
            print("يجب توفير على الأقل عمود bpm للتسمية التلقائية.")
            if 'bpm' in missing_cols:
                return False
        
        # إنشاء عمود condition إذا لم يكن موجوداً
        if 'condition' not in self.data.columns:
            self.data['condition'] = None
            
        # تحويل البيانات العددية الممثلة كنصوص
        for col in ['bpm', 'average']:
            if col in self.data.columns:
                try:
                    self.data[col] = pd.to_numeric(self.data[col], errors='coerce')
                except:
                    print(f"تعذر تحويل العمود {col} إلى قيم عددية")
        
        # قواعد التسمية التلقائية (مبسطة لأغراض هذه الأداة)
        label_count = 0
        
        # قاعدة 1: القراءات ذات معدل ضربات القلب الطبيعي تعتبر طبيعية
        normal_condition = (self.data['bpm'] >= 60) & (self.data['bpm'] <= 100)
        self.data.loc[normal_condition, 'condition'] = 'normal'
        normal_count = normal_condition.sum()
        label_count += normal_count
        
        # قاعدة 2: القراءات ذات معدل ضربات القلب المرتفع (> 100) تعتبر afib
        afib_condition = (self.data['bpm'] > 100)
        self.data.loc[afib_condition, 'condition'] = 'afib'
        afib_count = afib_condition.sum()
        label_count += afib_count
        
        # قاعدة 3: القراءات ذات معدل ضربات القلب المنخفض (< 60) تعتبر arrhythmia
        arrhythmia_condition = (self.data['bpm'] < 60)
        self.data.loc[arrhythmia_condition, 'condition'] = 'arrhythmia'
        arrhythmia_count = arrhythmia_condition.sum()
        label_count += arrhythmia_count
        
        # إضافة صفة heart_attack عن طريق اختيار عشوائي من القراءات ذات معدلات ضربات القلب المرتفعة أو المنخفضة
        # هذا تبسيط كبير ولأغراض النموذج فقط
        high_or_low_bpm = (self.data['bpm'] < 50) | (self.data['bpm'] > 120)
        heart_attack_indices = self.data[high_or_low_bpm].sample(
            n=min(20, high_or_low_bpm.sum()), 
            random_state=42
        ).index
        self.data.loc[heart_attack_indices, 'condition'] = 'heart_attack'
        heart_attack_count = len(heart_attack_indices)
        
        # تسمية القراءات المتبقية كطبيعية
        unlabeled_condition = self.data['condition'].isnull()
        self.data.loc[unlabeled_condition, 'condition'] = 'normal'
        additional_normal_count = unlabeled_condition.sum()
        
        # إحصاء التسميات النهائية
        final_counts = self.data['condition'].value_counts()
        print("\nملخص التسمية:")
        for condition, count in final_counts.items():
            print(f"  {condition}: {count} قراءة")
            
        return True
    
    def calculate_features(self):
        """حساب الميزات اللازمة للتدريب"""
        if self.data is None:
            print("لا توجد بيانات محملة! قم بتحميل البيانات أولاً.")
            return False
            
        print("\nحساب الميزات...")
        
        # إعداد raw_values من raw_value إذا كانت موجودة كسلسلة
        try:
            if 'raw_value' in self.data.columns and not 'raw_values' in self.data.columns:
                try:
                    self.data['raw_values'] = self.data['raw_value'].apply(
                        lambda x: [float(v) for v in str(x).split(',')] 
                        if isinstance(x, str) and ',' in str(x) else 
                        ([float(x)] if not pd.isna(x) else [])
                    )
                    print("تم استخراج القيم الخام بنجاح.")
                except Exception as e:
                    print(f"خطأ في استخراج القيم الخام: {e}")
                    print("سيتم استخدام قيم افتراضية للميزات.")
                    self.data['raw_values'] = [[]]  # قائمة فارغة لكل صف
        except Exception as e:
            print(f"خطأ عام: {e}")
        
        # حساب الميزات المطلوبة للتدريب
        
        # 1. heart_rate (استخدام BPM المتاح)
        self.data['heart_rate'] = self.data['bpm']
        
        # استخدام قيم افتراضية لجميع الميزات بناءً على التصنيفات
        print("تحذير: استخدام قيم افتراضية للميزات بناءً على التصنيفات.")
        
        # إنشاء ميزات عشوائية بناءً على التصنيفات
        self.data['hrv_sdnn'] = self.data.apply(
            lambda row: np.random.uniform(30, 60) if row['condition'] == 'normal' 
                else (np.random.uniform(60, 120) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(80, 150) if row['condition'] == 'afib'
                else np.random.uniform(20, 80))), axis=1
        )
        
        self.data['hrv_rmssd'] = self.data.apply(
            lambda row: np.random.uniform(20, 40) if row['condition'] == 'normal' 
                else (np.random.uniform(40, 100) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(60, 120) if row['condition'] == 'afib'
                else np.random.uniform(15, 60))), axis=1
        )
        
        self.data['qrs_duration'] = self.data.apply(
            lambda row: np.random.uniform(80, 110) if row['condition'] == 'normal' 
                else (np.random.uniform(110, 150) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(80, 120) if row['condition'] == 'afib'
                else np.random.uniform(80, 130))), axis=1
        )
        
        self.data['qrs_amplitude'] = self.data.apply(
            lambda row: np.random.uniform(0.8, 1.2) if row['condition'] == 'normal' 
                else (np.random.uniform(0.5, 1.5) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(0.7, 1.3) if row['condition'] == 'afib'
                else np.random.uniform(0.4, 1.0))), axis=1
        )
        
        self.data['st_elevation'] = self.data.apply(
            lambda row: np.random.uniform(0.0, 0.1) if row['condition'] == 'normal' 
                else (np.random.uniform(0.0, 0.2) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(0.0, 0.1) if row['condition'] == 'afib'
                else np.random.uniform(0.2, 0.5))), axis=1
        )
        
        self.data['st_slope'] = self.data.apply(
            lambda row: np.random.uniform(0.0, 0.05) if row['condition'] == 'normal' 
                else (np.random.uniform(-0.1, 0.1) if row['condition'] == 'arrhythmia'
                else (np.random.uniform(-0.05, 0.05) if row['condition'] == 'afib'
                else np.random.uniform(0.1, 0.3))), axis=1
        )
        
        print(f"تم حساب الميزات لـ {len(self.data)} قراءة.")
        
        return True
    
    def balance_data(self):
        """موازنة البيانات عبر التصنيفات المختلفة"""
        if self.data is None or 'condition' not in self.data.columns:
            print("لا توجد بيانات مصنفة لموازنتها!")
            return False
            
        print("\nموازنة البيانات...")
        
        # حساب عدد العينات لكل تصنيف
        class_counts = self.data['condition'].value_counts()
        print("عدد القراءات الحالي لكل تصنيف:")
        for cls, count in class_counts.items():
            print(f"  {cls}: {count}")
        
        # العثور على الحد الأدنى المناسب للفئات
        min_count = min(class_counts)
        target_count = min(min_count, 50)  # الهدف 50 عينة لكل فئة على الأقل
        
        balanced_data = []
        
        # أخذ عينات من كل فئة
        for condition in class_counts.index:
            class_data = self.data[self.data['condition'] == condition]
            
            if len(class_data) > target_count:
                # أخذ عينة للتقليل
                sampled_data = class_data.sample(n=target_count, random_state=42)
                balanced_data.append(sampled_data)
            else:
                # إضافة جميع البيانات المتاحة
                balanced_data.append(class_data)
                
                # إذا كان العدد أقل من الهدف، قم بتوليد عينات اصطناعية
                if len(class_data) < target_count:
                    print(f"تحذير: تصنيف {condition} به {len(class_data)} عينات فقط. سيتم استخدام ما هو متاح.")
        
        # دمج البيانات المتوازنة
        balanced_df = pd.concat(balanced_data)
        
        # عرض النتائج
        new_class_counts = balanced_df['condition'].value_counts()
        print("\nعدد القراءات بعد الموازنة:")
        for cls, count in new_class_counts.items():
            print(f"  {cls}: {count}")
        
        # تحديث البيانات
        self.data = balanced_df
        
        return True
    
    def save_labeled_data(self):
        """حفظ البيانات المسماة"""
        if self.data is None:
            print("لا توجد بيانات لحفظها!")
            return False
            
        try:
            self.data.to_csv(self.output_file, index=False)
            print(f"\nتم حفظ {len(self.data)} قراءة مسماة في {self.output_file}")
            return True
        except Exception as e:
            print(f"خطأ في حفظ البيانات: {e}")
            return False
    
    def show_class_statistics(self):
        """عرض إحصائيات تفصيلية لكل تصنيف"""
        if self.data is None or 'condition' not in self.data.columns:
            print("لا توجد بيانات مصنفة لعرض إحصائياتها!")
            return False
        
        print("\nإحصائيات التصنيفات:")
        
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
        axes = axes.flatten()
        
        features = ['heart_rate', 'hrv_sdnn', 'hrv_rmssd', 
                    'qrs_duration', 'qrs_amplitude', 'st_elevation']
        
        for i, feature in enumerate(features):
            ax = axes[i]
            for condition in self.data['condition'].unique():
                condition_data = self.data[self.data['condition'] == condition][feature]
                ax.hist(condition_data, alpha=0.5, label=condition, bins=10)
            
            ax.set_title(feature)
            ax.set_xlabel('القيمة')
            ax.set_ylabel('العدد')
            ax.legend()
        
        plt.tight_layout()
        
        # حفظ الرسم البياني
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        plot_file = f"class_statistics_{timestamp}.png"
        plt.savefig(plot_file)
        
        print(f"تم حفظ الرسم البياني في {plot_file}")
        
        # تحليل إحصائي نصي
        print("\nمتوسط وانحراف كل ميزة حسب التصنيف:")
        
        for condition in self.data['condition'].unique():
            condition_data = self.data[self.data['condition'] == condition]
            print(f"\n{condition}:")
            
            for feature in ['heart_rate', 'hrv_sdnn', 'hrv_rmssd', 
                            'qrs_duration', 'qrs_amplitude', 'st_elevation', 'st_slope']:
                mean = condition_data[feature].mean()
                std = condition_data[feature].std()
                print(f"  {feature}: {mean:.2f} ± {std:.2f}")
        
        return True
        
def main():
    """الدالة الرئيسية"""
    
    # التحقق من المعلمات
    if len(sys.argv) < 2:
        print("الاستخدام: python data_labeler.py <input_file.csv> [output_file.csv]")
        return
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # إنشاء أداة التسمية
    labeler = ECGDataLabeler(input_file, output_file)
    
    # تحميل البيانات
    if not labeler.load_data():
        return
    
    # تسمية البيانات تلقائياً
    if not labeler.auto_label_data():
        return
    
    # حساب الميزات اللازمة
    if not labeler.calculate_features():
        return
    
    # موازنة البيانات
    if not labeler.balance_data():
        return
    
    # عرض إحصائيات التصنيفات
    labeler.show_class_statistics()
    
    # حفظ البيانات المسماة
    labeler.save_labeled_data()
    
if __name__ == "__main__":
    main() 