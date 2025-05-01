#include <WiFi.h>
#include <FirebaseESP32.h>
#include <time.h>

// --- بيانات الواي فاي ---
const char* ssid = "Batman"; // <<< عدّل اسم الشبكة
const char* password = "12345678"; // <<< عدّل الباسورد

// --- بيانات Firebase ---
#define DATABASE_URL "https://heart-guard-1c49e-default-rtdb.firebaseio.com/" // رابط قاعدة البيانات
#define API_KEY "AIzaSyAljUNCr6Qh6FikDif2oDZ6tU38wENopC0" // <<< استخدم الـ API Key بتاع مشروعك >>>

// *** بيانات المستخدم للمصادقة (Email/Password) ***
#define USER_EMAIL "test@test.com"       // <<< حط الإيميل اللي عملته في Firebase Auth >>>
#define USER_PASSWORD "password123"    // <<< حط الباسورد اللي عملته >>>

// --- تعريف كائنات Firebase ---
FirebaseData fbdo;
FirebaseAuth auth; // سيحتوي على بيانات المصادقة بعد تسجيل الدخول
FirebaseConfig config;

// --- إعدادات NTP (Time Synchronization) ---
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 2 * 3600;
const int daylightOffset_sec = 0;

// --- متغيرات حساس النبض والحسابات (بدون تغيير) ---
#define PLOTT_DATA
#define MAX_BUFFER 100
uint32_t prevData[MAX_BUFFER];
uint32_t sumData = 0;
uint32_t maxData = 0;
uint32_t avgData = 0;
uint32_t roundrobin = 0;
uint32_t countData = 0;
uint32_t period = 0;
uint32_t lastperiod = 0;
uint32_t millistimer = millis();
double frequency;
double beatspermin = 0;
uint32_t newData;

// --- دالة freqDetec (بدون تغيير) ---
void freqDetec() { /* ... نفس الكود ... */
    if (countData == MAX_BUFFER) { if (prevData[roundrobin] < avgData * 1.5 && newData >= avgData * 1.5) { period = millis() - millistimer; millistimer = millis(); maxData = 0; } } roundrobin++; if (roundrobin >= MAX_BUFFER) { roundrobin = 0; } if (countData < MAX_BUFFER) { countData++; sumData += newData; } else { sumData += newData - prevData[roundrobin]; } avgData = sumData / countData; if (newData > maxData) { maxData = newData; }
#ifdef PLOTT_DATA
    Serial.print("Raw:"); Serial.print(newData); Serial.print("\tAvg:"); Serial.print(avgData); Serial.print("\tThr:"); Serial.print(avgData * 1.5); Serial.print("\tMax:"); Serial.print(maxData); Serial.print("\tBPM:"); Serial.println(beatspermin);
#endif
    prevData[roundrobin] = newData;
}

// --- دالة طباعة الوقت المحلي (بدون تغيير) ---
void printLocalTime() { /* ... نفس الكود ... */
    struct tm timeinfo; if (!getLocalTime(&timeinfo)) { Serial.println("Failed to obtain time"); return; } Serial.print("Current time: "); Serial.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");
}

// --- دالة الإعداد (Setup) --- // <<< تم التعديل هنا >>>
void setup() {
  Serial.begin(115200);

  // الاتصال بالواي فاي
  WiFi.begin(ssid, password); Serial.println("\nConnecting to WiFi...");
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\nConnected to WiFi"); Serial.print("IP Address: "); Serial.println(WiFi.localIP());

  // مزامنة الوقت باستخدام NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer); Serial.println("Configuring time using NTP...");
  printLocalTime();

  // طباعة بيانات Firebase للتأكد
  Serial.print("Firebase Database URL: "); Serial.println(DATABASE_URL);
  Serial.print("Firebase API Key: "); Serial.println(API_KEY);
  Serial.println("Attempting Email/Password Authentication (Implicitly via Firebase.begin).");

  // إعداد Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  /* Assign the user sign in credentials to the FirebaseAuth object */
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  // تهيئة Firebase - ستحاول تسجيل الدخول ضمنياً باستخدام بيانات auth
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // *** التحقق من حالة المصادقة بعد Firebase.begin() ***
  Serial.println("Checking authentication status after Firebase.begin()...");
  delay(2000); // انتظر قليلاً للمصادقة

  if (Firebase.ready()) {
      // Firebase.ready() تتحقق من الاتصال والمصادقة الناجحة
      Serial.println("Firebase connection and authentication successful!");
      Serial.print("User UID: "); Serial.println(auth.token.uid.c_str()); // استخدام auth object
  } else {
      Serial.println("!!! Firebase connection or authentication FAILED after begin() !!!");
      // --- تم حذف محاولة طباعة الخطأ من Firebase.errorReason() ---
      Serial.println("Check credentials, Firebase Console settings (Auth enabled, User exists, Rules), and network connection.");
      // ----------------------------------------------------------
  }
  // *******************************************************

  // إعدادات إضافية (اختياري)
  Firebase.setReadTimeout(fbdo, 1000 * 60);
  Firebase.setwriteSizeLimit(fbdo, "tiny");

  Serial.println("Firebase setup sequence complete. Monitor loop for Firebase readiness.");
  Serial.println("Ensure Email/Password Auth is ENABLED & User EXISTS in Firebase Console & Rules allow writes for auth != null.");
}


// --- الدالة الرئيسية (Loop) --- // <<< بدون تغيير >>>
void loop() {
  // التحقق من اتصال الواي فاي
  if (WiFi.status() != WL_CONNECTED) { Serial.println("WiFi connection lost! Library will attempt reconnection..."); delay(5000); return; }

  // التحقق من جاهزية Firebase (يشمل المصادقة الناجحة)
  if (!Firebase.ready()) {
      Serial.println("Firebase not ready (Auth failed or disconnected). Waiting...");
      // إذا فشل تسجيل الدخول في setup، ستظل هذه الرسالة تظهر
      delay(5000);
      return;
  }

  // قراءة بيانات الحساس ومعالجتها
  newData = analogRead(34);
  freqDetec();

  // التحقق وإرسال البيانات (نفس الكود السابق باستخدام pushJSON)
  if (period != lastperiod) {
      frequency = 1000.0 / period;
      if (frequency * 60 > 20 && frequency * 60 < 200) {
          beatspermin = frequency * 60;
          lastperiod = period;
          String pushPath = "/ecg_data";
          FirebaseJson json;
          json.set("raw_value", newData);
          json.set("average", avgData);
          json.set("max_in_period", maxData);
          json.set("bpm", beatspermin);
          json.set("timestamp", ".sv");
          json.set("user_email", USER_EMAIL); // ممكن نضيف الإيميل للتأكيد

          if (Firebase.pushJSON(fbdo, pushPath, json)) {
              Serial.print("Data pushed! Key: "); Serial.println(fbdo.dataPath());
          } else {
              Serial.println("!!! Failed to push data !!!");
              Serial.print("Firebase Error Reason (fbdo): "); Serial.println(fbdo.errorReason()); // <<< استخدام fbdo هنا صحيح
          }
      }
  }

  delay(10);
}