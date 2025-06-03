// Dart imports
import 'dart:async';
import 'dart:math';

// Flutter imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/logger_service.dart' as app_logger;


// Models
// import '../../models/ecg_reading.dart'; // Unused import

// Services
import '../../services/ecg_service.dart';
// import '../../services/ecg_data_service.dart'; // Unused import
import '../../services/sms_service.dart';

// Unawaited utility function
void unawaited(Future<void> future) {}

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = app_logger.Logger();
  late final ECGService _ecgService;
  final SMSService _smsService = SMSService();
  final _databaseRef = FirebaseDatabase.instance.ref();
  
  // --- State Variables ---
  bool _isMonitoring = false;
  String _status = 'Not monitoring';
  Map<String, dynamic>? _latestHealthData;
  Timer? _monitoringTimer;
  Timer? _cleanupTimer;
  int _heartRate = 0;
  int _bloodPressure = 0;
  int _oxygenLevel = 0;

  // Analysis state variables
  String? _analysisResultText;

  // Connection status variables
  DatabaseReference? _connectionRef;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  // Subscription for real-time health data
  StreamSubscription<DatabaseEvent>? _healthDataSubscription;

  // User profile data
  String? _userEmail;
  String? _doctorPhone;
  List<Map<String, String>> _emergencyContacts = [];

  // Add ECG chart data properties
  final List<FlSpot> _ecgChartData = [];
  final int _maxDataPoints = 100; // Maximum number of points to show on chart


  // Add these state variables for emergency contact form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  // إضافة متغير لتتبع آخر وقت تم فيه إرسال رسالة تلقائية
  // DateTime? _lastAutoMessageTime; // Unused field

  // Add these constants at the top of the class
  static const Duration _monitoringInterval = Duration(seconds: 1);
  static const Duration _reconnectionDelay = Duration(seconds: 3);
  static const int _maxReconnectionAttempts = 5;
  static const Duration _dataRefreshInterval = Duration(minutes: 1);

  // Add these variables for better state management
  bool _isReconnecting = false;
  int _reconnectionAttempts = 0;
  DateTime? _lastDataUpdate;
  Timer? _reconnectionTimer;

  // تحسين معالجة بيانات ECG
  double _normalizeEcgValue(double value) {
    // تحويل القيم الخام إلى نطاق مناسب للرسم البياني
    const double inputMin = 0;
    const double inputMax = 4095;
    const double outputMin = -0.5;
    const double outputMax = 0.5;
    
    // تطبيع القيمة إلى النطاق [-0.5, 0.5]
    return ((value - inputMin) / (inputMax - inputMin)) * (outputMax - outputMin) + outputMin;
  }

  // تحديث المؤشرات الصحية بناءً على BPM
  // void _updateHealthMetrics(double bpm) { // Unused method
  //   if (!mounted) return;
  //   
  //   setState(() {
  //     _heartRate = bpm.round();
  //     
  //     // تحديث ضغط الدم بناءً على BPM
  //     if (bpm < 60) {
  //       _bloodPressure = 90; // ضغط منخفض
  //     } else if (bpm > 100) {
  //       _bloodPressure = 140; // ضغط مرتفع
  //     } else {
  //       _bloodPressure = 120; // ضغط طبيعي
  //     }
  //     
  //     // تحديث مستوى الأكسجين بناءً على BPM
  //     if (bpm > 120) {
  //       _oxygenLevel = 92; // انخفاض مع زيادة BPM
  //     } else if (bpm < 60) {
  //       _oxygenLevel = 95; // انخفاض طفيف مع BPM المنخفض
  //     } else {
  //       _oxygenLevel = 98; // طبيعي
  //     }
  //   });
  // }

  // دالة التنبيه للحالات الخطرة
  void _triggerAlert(String message) {
    // عرض التنبيه فقط إذا لم يتم عرضه مؤخراً
    final now = DateTime.now();
    if (_lastAlertTime == null || now.difference(_lastAlertTime!) > const Duration(minutes: 5)) {
      _lastAlertTime = now;
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Health Warning!'),
          content: Text(message),
          backgroundColor: Colors.red[100],
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Understood'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleEmergency();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Contact Emergency'),
            ),
          ],
        ),
      );
    }
  }

  // متغير لتتبع وقت آخر تنبيه
  DateTime? _lastAlertTime;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    
    _checkAndSetupAuth();
    _loadEmergencyContacts();
    _setupConnectionListener();
    _setupHealthDataListener();
    
    // Start monitoring timer with optimized interval
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      if (_isMonitoring && !_isReconnecting) {
        _collectHealthData();
      }
    });

    // Add periodic data refresh
    Timer.periodic(_dataRefreshInterval, (_) {
      if (_isMonitoring) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _stopMonitoring();
    _cleanupTimer?.cancel();
    _connectionSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _monitoringTimer?.cancel();
    _reconnectionTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize ECG service
      _ecgService = ECGService();
      await _ecgService.init();
    } catch (e) {
      _logError('Error initializing services', e);
    }
  }

  Future<void> _checkAndSetupAuth() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _status = 'Please sign in to start monitoring';
        });
      }
      return;
    }
    
    // Store user email
    _userEmail = user.email;
    
    // Fetch user profile data (contacts, doctor phone) from Firestore
    // Keep this part as it fetches non-ECG related user data
    try {
      // final connectionRef = FirebaseDatabase.instance.ref('.info/connected');
      // final snapshot = await connectionRef.get();
      // final isConnected = snapshot.value as bool? ?? false;

      // if (!isConnected) {
      //    _logWarning('No connection to Firebase while fetching profile. Operating in offline mode.');
      //    if (mounted) {
      //      setState(() {
      //        _status = 'Offline mode - Limited functionality';
      //      });
      //      ScaffoldMessenger.of(context).showSnackBar(
      //        const SnackBar(
      //          content: Text('No internet connection. Profile data might be stale.'),
      //          backgroundColor: Colors.orange,
      //          duration: Duration(seconds: 5),
      //        ),
      //      );
      //    }
      //  }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _doctorPhone = data['doctorPhone'] as String?;
        final contactsRaw = data['emergencyContacts'] as List<dynamic>?;
        _emergencyContacts = contactsRaw
           ?.map((contact) => contact is Map ? {'phone': contact['phone'] as String? ?? ''} : {'phone': ''})
           .where((contact) => contact['phone']!.isNotEmpty)
           .toList() ?? [];
        _logInfo('Fetched user profile data: Doctor=$_doctorPhone, Contacts=${_emergencyContacts.length}');
      } else {
        _logWarning('User document not found in Firestore for uid: ${user.uid}');
      }
    } catch (e) {
      _logError('Error fetching user profile data', e);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Error loading profile: ${e.toString().contains('network') ? 'Network issue' : 'Data access error'}'),
             backgroundColor: Colors.red,
           ),
         );
       }
    }

    _setupHealthDataListener(); // Keep as it uses /users/<uid>/health_data
  }

  void _setupConnectionListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel any existing subscription first
    _connectionSubscription?.cancel();

    // Correctly reference the connection status at the database root
    _connectionRef = FirebaseDatabase.instance.ref('.info/connected');

    _connectionSubscription = _connectionRef?.onValue.listen((DatabaseEvent event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (!mounted) return;
      
      setState(() {
        if (!connected && _status != 'Offline') {
          _status = 'Offline - Reconnecting...';
          _logWarning('Database connection lost.');
          _startReconnectionAttempts();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection lost. Attempting to reconnect...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (connected && _status.contains('Offline')) {
          _status = _isMonitoring ? 'Monitoring resumed' : 'Connected';
          _logInfo('Database connection established.');
          _isReconnecting = false;
          _reconnectionAttempts = 0;
          _reconnectionTimer?.cancel();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection restored!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Refresh data when connection is restored
          _refreshDataAfterReconnection();
        }
      });
    }, onError: (error) {
      _logError('Error in connection listener', error);
      _startReconnectionAttempts();
    });
  }

  // New method to refresh data after reconnection
  Future<void> _refreshDataAfterReconnection() async {
      if (!mounted) return;
    
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
    setState(() {
        _status = 'Refreshing data...';
    });

      // Refresh health data
      if (_isMonitoring) {
      await _collectHealthData();
      }

    } catch (e) {
      _logError('Error refreshing data after reconnection', e);
    }
  }

  void _stopMonitoring() {
    if (!_isMonitoring) return;
    
    _monitoringTimer?.cancel();
    setState(() {
      _isMonitoring = false;
      _status = 'Not monitoring';
    });
  }

  Future<void> _collectHealthData() async {
    if (!_isMonitoring) {
      _logDebug('Health monitoring is not active');
      return;
    }

    _logDebug('Collecting health data...');
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null || _userEmail == null) {
      if (!mounted) return;
      setState(() { 
        _status = 'Error: User not authenticated';
        _isMonitoring = false; 
      });
      _logWarning('Attempted health data collection but user/email is missing.');
      return;
    }

    try {
      // Get latest health data from Firebase - MODIFIED PATH
      final snapshot = await _databaseRef
          .child('heart_monitor') // MODIFIED path
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      if (!snapshot.exists) {
        _logInfo('No health data found at /heart_monitor');
        // Generate realistic initial values - COMMENTED OUT FOR GLOBAL PATH
        // final random = Random();
        // final initialHeartRate = 65 + random.nextInt(15); // 65-80 bpm
        // final initialBloodPressure = 110 + random.nextInt(20); // 110-130 mmHg
        // final initialOxygenLevel = 96 + random.nextInt(4); // 96-99%
        
        // final initialData = {
        //   'heartRate': initialHeartRate,
        //   'bloodPressure': initialBloodPressure,
        //   'oxygenLevel': initialOxygenLevel,
        //   'timestamp': ServerValue.timestamp,
        //   'location': {
        //     'latitude': 0.0,
        //     'longitude': 0.0
        //   }
        // };

        // await _databaseRef
        //     .child('heart_monitor') // Would write to global path
        //     .push()
        //     .set(initialData);
            
        if (!mounted) return;
        setState(() {
          _heartRate = 0; // Default if no data
          _bloodPressure = 0; // Default if no data
          _oxygenLevel = 0; // Default if no data
          _status = 'No data from ESP32 at /heart_monitor';
        });
        
        return;
      }

      // Process the data if it exists
      if (snapshot.value == null || snapshot.value is! Map) {
        throw Exception('Invalid data format received from /heart_monitor');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data.isEmpty) {
        throw Exception('Empty data received from /heart_monitor');
      }
      
      final latestDataRaw = data.values.first;
      if (latestDataRaw == null || latestDataRaw is! Map) {
         throw Exception('Invalid data format in /heart_monitor entry');
      }
      
      final latestData = Map<String, dynamic>.from(latestDataRaw);
      
      // Extract location data safely - ESP32 does not send this
      // final locationRaw = latestData['location'];
      // final locationData = (locationRaw != null && locationRaw is Map)
      //     ? Map<String, dynamic>.from(locationRaw)
      //     : <String, dynamic>{};
      
      // Create health data structure
      final healthData = <String, dynamic>{
        'heartRate': (latestData['bpm_pulse'] as num?)?.toDouble() ?? 0.0, // MODIFIED field from bpm_pulse
        'bloodPressure': (latestData['bloodPressure'] as num?)?.toDouble() ?? 0.0, // ESP32 does not send, will default to 0
        'oxygenLevel': (latestData['oxygenLevel'] as num?)?.toDouble() ?? 0.0, // ESP32 does not send, will default to 0
        'timestamp': (latestData['timestamp'] as num?)?.toDouble() ?? DateTime.now().millisecondsSinceEpoch.toDouble(),
        // 'location': locationData, // ESP32 does not send location
        'ecgData': latestData['ecgData'], // ESP32 does not send this as a list, chart might be empty
        'raw_pulse': (latestData['raw_pulse'] as num?)?.toDouble() ?? 0.0 // Store raw_pulse if needed later
      };

      // Update state
      if (!mounted) return;
      setState(() {
        _heartRate = healthData['heartRate'].round();
        _bloodPressure = healthData['bloodPressure'].round(); // Will be 0
        _oxygenLevel = healthData['oxygenLevel'].round(); // Will be 0
        _latestHealthData = healthData;
        
        // Update status with formatted time
        final timestamp = healthData['timestamp'];
        if (timestamp != null) {
          final updateTime = DateTime.fromMillisecondsSinceEpoch((timestamp.round() * 1000)); // ESP32 timestamp is in seconds
          _status = 'Monitoring... (ESP32 Data Updated: ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}:${updateTime.second.toString().padLeft(2, '0')})';
        } else {
             _status = 'Monitoring...';
        }
      });

      // Analyze the health data
      _analyzeCurrentReading(healthData);
      
    } catch (e) {
      _logError('Error collecting health data', e);
      if (!mounted) return;
      
      String errorMessage = 'Error collecting health data';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Database access denied. Please check permissions.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      setState(() {
        _status = 'Error: $errorMessage';
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _collectHealthData,
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  // تحسين بطاقة التحليل
  Widget _buildAnalysisCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700),
                const SizedBox(width: 8),
              Text(
                  'تحليل القراءة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalysisResultState(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _analyzeCurrentReading(_latestHealthData),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'تحديث التحليل',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      );
    }

  // تحسين بطاقة التحليل
  Widget _buildAnalysisResultState() {
    // إذا لم تكن هناك بيانات، نعرض رسالة بسيطة
    if (_analysisResultText == null || _analysisResultText!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'في انتظار البيانات...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // تحديد لون البطاقة بناءً على نتيجة التحليل
    Color cardColor;
    Color textColor = Colors.white;
    IconData statusIcon;
    
    if (_heartRate < 60) {
      cardColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      statusIcon = Icons.warning;
    } else if (_heartRate > 100) {
      cardColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
      statusIcon = Icons.error;
    } else {
      cardColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
      statusIcon = Icons.check_circle;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withAlpha((0.5 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade200.withAlpha((0.8 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 40,
            color: textColor,
          ),
          const SizedBox(height: 16),
          Text(
            _analysisResultText!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (_heartRate > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: textColor.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: textColor.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Text(
                'معدل ضربات القلب: $_heartRate BPM',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // تحديث دالة تحليل القراءة الحالية
  void _analyzeCurrentReading(dynamic reading) {
    if (reading == null) {
      setState(() {
        _analysisResultText = null;  // سنترك البطاقة فارغة بدلاً من عرض رسالة خطأ
      });
      return;
    }

    try {
      // التحقق من وجود معدل ضربات القلب
      final bpm = _heartRate;
      if (bpm <= 0) {
        setState(() {
          _analysisResultText = null;
        });
        return;
      }

      // تحليل حالة القلب بناءً على معدل ضربات القلب
      String analysis;
      if (bpm < 60) {
        analysis = "معدل ضربات القلب منخفض";
        // تنبيه في حالة الانخفاض الشديد
        if (bpm < 50) {
          _triggerAlert("تحذير: معدل ضربات القلب منخفض جداً!");
        }
      } else if (bpm > 100) {
        analysis = "معدل ضربات القلب مرتفع";
        // تنبيه في حالة الارتفاع الشديد
        if (bpm > 120) {
          _triggerAlert("تحذير: معدل ضربات القلب مرتفع جداً!");
        }
      } else {
        analysis = "معدل ضربات القلب طبيعي";
      }

      setState(() {
        _analysisResultText = analysis;
      });

    } catch (e) {
      setState(() {
        _analysisResultText = null;  // في حالة الخطأ، نترك البطاقة فارغة
      });
      _logError('خطأ في تحليل البيانات', e);
    }
  }

  // تحسين الدالة المسؤولة عن لون معدل ضربات القلب
  Color _getHeartRateColor(double? bpm) {
    if (bpm == null) return Colors.grey;
    if (bpm > 100) return Colors.red.shade700;
    if (bpm < 60) return Colors.orange.shade800;
    return Colors.green.shade600;
  }

  // إضافة دوال تسجيل المعلومات
  void _logDebug(String message) => _logger.d(message);
  void _logInfo(String message) => _logger.i(message);
  void _logWarning(String message) => _logger.w(message);
  void _logError(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }

  Future<void> _refreshData() async {
    if (!mounted || !_isMonitoring) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if we need to refresh based on last update
      if (_lastDataUpdate != null && 
          DateTime.now().difference(_lastDataUpdate!) < _dataRefreshInterval) {
        return;
      }

      // Force a fresh data fetch
      await _collectHealthData();
      
      // Update last refresh time
      _lastDataUpdate = DateTime.now();
      
      if (mounted) {
        setState(() {
          _status = 'Data refreshed';
        });
      }
    } catch (e) {
      _logError('Error refreshing data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _refreshData,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  void _startReconnectionAttempts() {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    _reconnectionAttempts = 0;
    _reconnectionTimer?.cancel();
    
    _reconnectionTimer = Timer.periodic(_reconnectionDelay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        timer.cancel();
        _isReconnecting = false;
        if (mounted) {
          setState(() {
            _status = 'Connection failed - Please check your internet';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to reconnect. Please check your internet connection.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  _reconnectionAttempts = 0;
                  _startReconnectionAttempts();
                },
                textColor: Colors.white,
              ),
            ),
          );
        }
        return;
      }

      _reconnectionAttempts++;
      _logInfo('Reconnection attempt $_reconnectionAttempts of $_maxReconnectionAttempts');
      
      // Attempt to reconnect
      _checkAndSetupAuth().then((_) {
        if (mounted) {
          setState(() {
            _status = 'Reconnecting... (Attempt $_reconnectionAttempts)';
          });
        }
      }).catchError((error) {
        _logError('Reconnection attempt failed', error);
      });
    });
  }

  Future<void> _handleEmergency() async {
    if (!mounted) return;

    try {
      await _loadEmergencyContacts();
      if (!mounted) return;
      
      if (_emergencyContacts.isEmpty) {
        // إذا لم تكن هناك جهات اتصال طوارئ، اعرض رسالة تحذير
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تنبيه'),
            content: const Text('لم يتم إضافة جهات اتصال للطوارئ. هل تريد إضافة جهات اتصال الآن؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقاً'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddEmergencyContactDialog();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('إضافة الآن'),
              ),
            ],
          ),
        );
        return;
      }

      // عرض قائمة جهات الاتصال مع خيارات الاتصال
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'جهات اتصال الطوارئ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _emergencyContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade100,
                        child: Icon(Icons.person, color: Colors.red.shade700),
                      ),
                      title: Text(contact['name'] ?? 'جهة اتصال ${index + 1}'),
                      subtitle: Text(contact['phone'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.message),
                            color: Colors.orange,
                            onPressed: () => _sendEmergencySMS(contact['phone'] ?? ''),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call),
                            color: Colors.green,
                            onPressed: () => _makeEmergencyCall(contact['phone'] ?? ''),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showAddEmergencyContactDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة جهة اتصال'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendEmergencyToAll(),
                        icon: const Icon(Icons.warning),
                        label: const Text('إرسال تنبيه للجميع'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _logError('Error handling emergency', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال بجهات الطوارئ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmergencySMS(String phoneNumber) async {
    try {
      // تحضير الرسالة باستخدام الدالة المساعدة
      final message = _smsService.formatEmergencyMessage(
        userEmail: _userEmail ?? 'غير معروف',
        heartRate: _heartRate,
        bloodPressure: _bloodPressure,
        oxygenLevel: _oxygenLevel,
        diagnosis: _analysisResultText ?? 'غير متوفر',
      );

      // إرسال الرسالة عبر واتساب
      final success = await _smsService.sendWhatsAppMessage(
        phoneNumber: phoneNumber,
        message: message,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رسالة الطوارئ عبر واتساب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        throw 'فشل في إرسال رسالة الطوارئ';
      }
    } catch (e) {
      _logError('Error sending emergency WhatsApp message', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال رسالة الطوارئ: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'حاول مرة أخرى',
              onPressed: () => _sendEmergencySMS(phoneNumber),
            ),
          ),
        );
      }
    }
  }

  Future<void> _makeEmergencyCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch phone app';
      }
    } catch (e) {
      _logError('Error making emergency call', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إجراء مكالمة الطوارئ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmergencyToAll() async {
    try {
      for (final contact in _emergencyContacts) {
        await _sendEmergencySMS(contact['phone'] ?? '');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال تنبيه الطوارئ لجميع جهات الاتصال'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logError('Error sending emergency to all contacts', e);
    }
  }

  Future<void> _showAddEmergencyContactDialog() async {
    try {
      _nameController.clear();
      _phoneController.clear();
      _relationController.clear();

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إضافة جهة اتصال طوارئ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _relationController,
                decoration: const InputDecoration(
                  labelText: 'صلة القرابة',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      );

      if (result == true) {
        await _loadEmergencyContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت إضافة جهة الاتصال بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _logError('Error adding emergency contact', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة جهة الاتصال: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // إضافة دالة الاستماع لبيانات الصحة
  void _setupHealthDataListener() {
    final user = _auth.currentUser;
    if (user == null) {
      _logWarning('Cannot setup health data listener: User not logged in');
      return;
    }

    try {
      // Reference to the user's health data in Firebase - MODIFIED PATH
      final healthDataRef = _databaseRef.child('heart_monitor'); // MODIFIED path
      
      // Cancel existing subscription if any
      _healthDataSubscription?.cancel();
      
      // Listen for changes to health data
      _healthDataSubscription = healthDataRef
        .orderByChild('timestamp') // Order by timestamp to get latest
        .limitToLast(1)        // Get only the latest entry
        .onValue.listen((event) {
        if (!mounted) return;
        
        if (event.snapshot.value == null || event.snapshot.value is! Map) {
          _logWarning('Health data listener received null or invalid data from /heart_monitor');
          return;
        }

        final dataMap = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (dataMap.isEmpty) {
          _logWarning('Health data listener received empty map from /heart_monitor');
          return;
        }

        // The value is a map with one entry: { "<timestamp_key>": { ...data... } }
        final latestEntryKey = dataMap.keys.first;
        final latestData = Map<String, dynamic>.from(dataMap[latestEntryKey] as Map);

        if (latestData != null) {
          final currentRawPulse = (latestData['raw_pulse'] as num?)?.toDouble();

          setState(() {
            _heartRate = (latestData['bpm_pulse'] as num?)?.toInt() ?? _heartRate;
            _bloodPressure = (latestData['bloodPressure'] as num?)?.toInt() ?? _bloodPressure;
            _oxygenLevel = (latestData['oxygenLevel'] as num?)?.toInt() ?? _oxygenLevel;
            
            if (currentRawPulse != null) {
              // Add the new raw_pulse to the chart data
              _updateEcgChartDataWithSinglePoint(currentRawPulse);
            }

            _latestHealthData = {
              'heartRate': (latestData['bpm_pulse'] as num?)?.toDouble() ?? 0.0,
              'bloodPressure': 0.0, 
              'oxygenLevel': 0.0, 
              'timestamp': (latestData['timestamp'] as num?)?.toDouble() ?? DateTime.now().millisecondsSinceEpoch.toDouble(),
              'raw_pulse': currentRawPulse ?? 0.0
            }; 

          });
          
          _analyzeCurrentReading(_latestHealthData);
        }
      }, onError: (error) {
        _logError('Error listening to health data', error);
      });
      
      _logInfo('Health data listener setup complete');
    } catch (e) {
      _logError('Failed to setup health data listener', e);
    }
  }

  // New method to add a single point from raw_pulse
  void _updateEcgChartDataWithSinglePoint(double rawValue) {
    if (!mounted) return;

    double nextX = _ecgChartData.isEmpty ? 0 : _ecgChartData.last.x + 1; // Increment X-axis by 1 for each new point
    
    // Normalize the raw_pulse value if needed, or use it directly.
    // The existing _normalizeEcgValue function expects input 0-4095 and outputs -0.5 to 0.5.
    // Adjust this normalization based on the actual range and desired display of raw_pulse.
    // For now, let's assume raw_pulse is within a range that can be somewhat normalized by this.
    double normalizedValue = _normalizeEcgValue(rawValue); 

    final newSpot = FlSpot(nextX, normalizedValue);

    setState(() {
      if (_ecgChartData.length >= _maxDataPoints) {
        _ecgChartData.removeAt(0); // Remove oldest point
      }
      _ecgChartData.add(newSpot);

      // Optional: Adjust X-axis of all points if they go off-screen, 
      // or let the chart scroll if it supports it with minX/maxX.
      // For simplicity, we'll let minX/maxX handle it for now based on first/last point.
    });
  }

  Future<void> _loadEmergencyContacts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        // إنشاء وثيقة جديدة للمستخدم إذا لم تكن موجودة
        await userDocRef.set({
          'email': user.email,
          'emergencyContacts': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _emergencyContacts = [];
        });
        return;
      }

      final data = userDoc.data()!;
      final contactsRaw = data['emergencyContacts'] as List<dynamic>?;
      
      if (mounted) {
        setState(() {
          _emergencyContacts = contactsRaw
              ?.map((contact) => contact is Map<String, dynamic> 
                  ? {
                      'name': contact['name'] as String? ?? '',
                      'phone': contact['phone'] as String? ?? '',
                      'relation': contact['relation'] as String? ?? '',
                    } 
                  : {'name': '', 'phone': '', 'relation': ''})
              .where((contact) => contact['phone']!.isNotEmpty)
              .toList() ?? [];
        });
      }
      _logInfo('Loaded ${_emergencyContacts.length} emergency contacts');
    } catch (e) {
      _logError('Error loading emergency contacts', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل جهات الاتصال: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthMetricsCard(),
              const SizedBox(height: 16),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Live ECG',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_ecgChartData.length} points',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: _buildEcgChart(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildAnalysisCard(),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _handleEmergency,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade200.withAlpha((0.8 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Emergency Contacts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthMetricsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Health Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.monitor_heart, color: Colors.teal.shade600)
              ],
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Heart Rate',
              '$_heartRate BPM',
              icon: Icons.favorite,
              color: _getHeartRateColor(_heartRate.toDouble()),
            ),
            _buildMetricRow(
              'Blood Pressure',
              '$_bloodPressure mmHg',
              icon: Icons.speed,
              color: _bloodPressure > 140 ? Colors.red.shade700 : (_bloodPressure < 90 ? Colors.orange.shade800 : Colors.green.shade600),
            ),
            _buildMetricRow(
              'Oxygen Level',
              '$_oxygenLevel%',
              icon: Icons.air,
              color: _oxygenLevel < 95 ? Colors.red.shade700 : Colors.green.shade600,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: _getProgressValue(label),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withAlpha((0.3 * 255).round()),
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getProgressValue(String metricType) {
    switch (metricType) {
      case 'Heart Rate':
        if (_heartRate < 60) return 0.3;
        if (_heartRate > 100) return 0.9;
        return 0.3 + ((_heartRate - 60) / 40) * 0.4;
      
      case 'Blood Pressure':
        if (_bloodPressure < 90) return 0.3;
        if (_bloodPressure > 140) return 0.9;
        return 0.3 + ((_bloodPressure - 90) / 50) * 0.4;
      
      case 'Oxygen Level':
        if (_oxygenLevel < 90) return 0.3;
        return 0.3 + ((_oxygenLevel - 90) / 10) * 0.7;
      
      default:
        return 0.5;
    }
  }

  // تحسين تكوين الرسم البياني
  Widget _buildEcgChart() {
    return Container(
      // height: 300, // Parent SizedBox already defines height
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).round()), // Reverted to withAlpha, assuming withValues handles it
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: LineChart(
          LineChartData(
            minY: -0.6,
            maxY: 0.6,
            minX: _ecgChartData.isEmpty ? 0 : _ecgChartData.first.x,
            maxX: _ecgChartData.isEmpty ? 10 : _ecgChartData.last.x,
            lineBarsData: [
              LineChartBarData(
                spots: _ecgChartData,
                isCurved: true,
                curveSmoothness: 0.3,
                color: Colors.red,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withAlpha((0.1 * 255).round()), // Reverted to withAlpha, assuming withValues handles it
                ),
              ),
            ],
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              drawHorizontalLine: true,
              horizontalInterval: 0.2,
              verticalInterval: 0.5,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: value == 0 ? Colors.grey[400]! : Colors.grey[200]!,
                  strokeWidth: value == 0 ? 1.5 : 0.8,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                );
              },
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 0.2,
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}
