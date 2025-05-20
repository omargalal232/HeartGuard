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
import '../../models/ecg_reading.dart';

// Services
import '../../services/ecg_service.dart';
import '../../services/ecg_data_service.dart';
import '../../services/sms_service.dart';

// Unawaited utility function
void unawaited(Future<void> future) {}

// Add at the top level, after imports and before class declarations
// Message sending types enum
enum MessageType { sms, whatsapp, both }

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
  final EcgDataService _ecgDataService = EcgDataService();
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

  // --- NEW: Subscription for EcgDataService ---
  StreamSubscription<EcgReading?>? _latestEcgReadingSubscription;

  // Add ECG chart data properties
  final List<FlSpot> _ecgChartData = [];
  final int _maxDataPoints = 100; // Maximum number of points to show on chart


  // Add these state variables for emergency contact form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  // إضافة متغير لتتبع آخر وقت تم فيه إرسال رسالة تلقائية
  DateTime? _lastAutoMessageTime;

  // Add message status tracking
  final Map<String, String> _messageStatus = {};
  
  // Add this property to track retry attempts
  final int _maxRetryAttempts = 3;

  // تحديث المؤشرات الصحية بناءً على BPM
  void _updateHealthMetrics(double bpm) {
    if (!mounted) return;
    
    setState(() {
      _heartRate = bpm.round();
      
      // Update blood pressure based on BPM
      if (bpm < 60) {
        _bloodPressure = 90; // Low pressure
      } else if (bpm > 100) {
        _bloodPressure = 140; // High pressure
      } else {
        _bloodPressure = 120; // Normal pressure
      }
      
      // Update oxygen level based on BPM
      if (bpm > 120) {
        _oxygenLevel = 92; // Decreased with high BPM
      } else if (bpm < 60) {
        _oxygenLevel = 95; // Slight decrease with low BPM
      } else {
        _oxygenLevel = 98; // Normal
      }
    });
  }

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
    
    _checkAndSetupAuth(); // This now only fetches user profile, not ECG listeners
    _loadEmergencyContacts(); // Add initial load of emergency contacts
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      // _clearOldECGReadings(); // Needs rework for the new structure
      _logDebug("Skipping _clearOldECGReadings - needs rework.");
    });
    _setupConnectionListener();

    // Start listening to latest ECG readings from the correct service
    _listenToLatestEcg();

    // إضافة مؤقت للتحقق من الحالة كل دقيقة
    Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndSendAutoAlert();
    });
  }

  @override
  void dispose() {
    _stopMonitoring();
    _cleanupTimer?.cancel();
    _connectionSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _latestEcgReadingSubscription?.cancel();
    // Dispose of controllers
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
      final connectionRef = FirebaseDatabase.instance.ref('.info/connected');
      final snapshot = await connectionRef.get();
      final isConnected = snapshot.value as bool? ?? false;

      if (!isConnected) {
         _logWarning('No connection to Firebase while fetching profile. Operating in offline mode.');
         if (mounted) {
           setState(() {
             _status = 'Offline mode - Limited functionality';
           });
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('No internet connection. Profile data might be stale.'),
               backgroundColor: Colors.orange,
               duration: Duration(seconds: 5),
             ),
           );
         }
       }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection lost. Trying to reconnect...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (connected && _status.contains('Offline')) {
          _status = _isMonitoring ? 'Monitoring resumed' : 'Connected';
          _logInfo('Database connection established.');
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
      _logError('Error in connection listener: $error');
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
    if (!_isMonitoring) {
      return;
    }
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
    final String userId = user.uid;

    try {
      // First try to get existing data
      final snapshot = await _databaseRef
          .child('users')
          .child(userId)
          .child('health_data')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      // If no data exists, create initial data
      if (!snapshot.exists) {
        _logInfo('No health data found, creating initial data');
        
        // Generate realistic initial values
        final random = Random();
        final initialHeartRate = 65 + random.nextInt(15); // 65-80 bpm
        final initialBloodPressure = 110 + random.nextInt(20); // 110-130 mmHg
        final initialOxygenLevel = 96 + random.nextInt(4); // 96-99%
        
        final initialData = {
          'heartRate': initialHeartRate,
          'bloodPressure': initialBloodPressure,
          'oxygenLevel': initialOxygenLevel,
          'timestamp': ServerValue.timestamp,
          'location': {
            'latitude': 0.0,
            'longitude': 0.0
          }
        };

        await _databaseRef
            .child('users')
            .child(userId)
            .child('health_data')
            .push()
            .set(initialData);
            
        if (!mounted) return;
        setState(() {
          _heartRate = initialHeartRate;
          _bloodPressure = initialBloodPressure;
          _oxygenLevel = initialOxygenLevel;
          _status = 'Monitoring started with initial values';
        });
        
        return;
      }

      // Process the data if it exists
      if (snapshot.value == null || snapshot.value is! Map) {
        throw Exception('Invalid data format received from database');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data.isEmpty) {
        throw Exception('Empty data received from database');
      }
      
      final latestDataRaw = data.values.first;
      if (latestDataRaw == null || latestDataRaw is! Map) {
         throw Exception('Invalid data format received from database');
      }
      
      final latestData = Map<String, dynamic>.from(latestDataRaw);
      
      // Extract location data safely
      final locationRaw = latestData['location'];
      final locationData = (locationRaw != null && locationRaw is Map)
          ? Map<String, dynamic>.from(locationRaw)
          : <String, dynamic>{};
      
      // Create health data structure
      final healthData = <String, dynamic>{
        'heartRate': (latestData['heartRate'] as num?)?.toDouble() ?? 70.0,
        'bloodPressure': (latestData['bloodPressure'] as num?)?.toDouble() ?? 120.0,
        'oxygenLevel': (latestData['oxygenLevel'] as num?)?.toDouble() ?? 98.0,
        'timestamp': (latestData['timestamp'] as num?)?.toDouble() ?? DateTime.now().millisecondsSinceEpoch.toDouble(),
        'location': locationData,
      };

      // Update state
      if (!mounted) return;
      setState(() {
        _heartRate = healthData['heartRate'].round();
        _bloodPressure = healthData['bloodPressure'].round();
        _oxygenLevel = healthData['oxygenLevel'].round();
        _latestHealthData = healthData;
        
        // Update status with formatted time
        final timestamp = healthData['timestamp'];
        if (timestamp != null) {
          final updateTime = DateTime.fromMillisecondsSinceEpoch(timestamp.round());
          _status = 'Monitoring... (Updated: ${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}:${updateTime.second.toString().padLeft(2, '0')})';
        } else {
             _status = 'Monitoring...';
        }
      });
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

  // Add a BPM conversion function
  double _convertToBPM(double rawValue) {
    // Simple conversion from raw ECG value to approximate BPM
    // This is a placeholder implementation - adjust based on your actual data calibration
    const double minBPM = 40.0;
    const double maxBPM = 180.0;
    
    // Map raw value to BPM range
    // This assumes higher raw values correspond to higher BPM
    double bpmValue = minBPM + (rawValue / 4095.0) * (maxBPM - minBPM);
    
    // Ensure realistic BPM values
    return _heartRate > 0 ? _heartRate.toDouble() : bpmValue;
  }

  // Update process sequential values to use BPM
  void _processSequentialValues(List<double> values) {
    if (values.isEmpty) return;
    
    List<FlSpot> newSpots = [];
    double nextX = _ecgChartData.isEmpty ? 0 : _ecgChartData.last.x + 0.1; // Smaller time interval
    
    // Remove old points if exceeding max
    while (_ecgChartData.length + values.length > _maxDataPoints) {
      _ecgChartData.removeAt(0);
    }
    
    // Renumber existing points
    for (int i = 0; i < _ecgChartData.length; i++) {
      _ecgChartData[i] = FlSpot(i * 0.1, _ecgChartData[i].y);
    }
    
    // Add new points using BPM values
    for (final value in values) {
      double bpmValue = _convertToBPM(value);
      newSpots.add(FlSpot(nextX, bpmValue));
      nextX += 0.1;
    }
    
    if (mounted) {
      setState(() {
        _ecgChartData.addAll(newSpots);
      });
    }
  }

  // Update add single data point to use BPM
  void _addSingleDataPoint(double value) {
    if (!mounted) return;
    
    // Remove oldest point if at max
    if (_ecgChartData.length >= _maxDataPoints) {
      _ecgChartData.removeAt(0);
      
      // Renumber remaining points
      for (int i = 0; i < _ecgChartData.length; i++) {
        _ecgChartData[i] = FlSpot(i * 0.1, _ecgChartData[i].y);
      }
    }
    
    double bpmValue = _convertToBPM(value);
    double x = _ecgChartData.isEmpty ? 0 : _ecgChartData.last.x + 0.1;
    
    setState(() {
      _ecgChartData.add(FlSpot(x, bpmValue));
    });
  }

  // تحسين دالة الاستماع للبيانات
  void _listenToLatestEcg() {
    _logger.i("Setting up ECG data stream...");
    
    _latestEcgReadingSubscription?.cancel();
    
    // تجميع البيانات لمعالجتها دفعة واحدة
    List<EcgReading> readingBuffer = [];
    Timer? updateTimer;
    
    _latestEcgReadingSubscription = _ecgDataService.latestEcgReadingStream.listen(
      (EcgReading? reading) {
        if (!mounted || reading == null) return;
        
        readingBuffer.add(reading);
        
        // تحديث كل 50 مللي ثانية لتحسين الأداء
        updateTimer?.cancel();
        updateTimer = Timer(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          
          for (var bufferedReading in readingBuffer) {
            if (bufferedReading.values != null && bufferedReading.values!.isNotEmpty) {
              _processSequentialValues(bufferedReading.values!
                  .map((v) => v.toDouble())
                  .toList());
            } else if (bufferedReading.rawValue != null) {
              _addSingleDataPoint(bufferedReading.rawValue!.toDouble());
            }
            
            // تحديث معدل ضربات القلب إذا كان متوفراً
            if (bufferedReading.bpm != null) {
              _updateHealthMetrics(bufferedReading.bpm!);
            }
          }
          
          readingBuffer.clear();
        });
      },
      onError: (error) {
        _logError('Error in ECG stream', error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error receiving ECG data: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    );
  }

  // Update ECG chart configuration to display BPM values
  Widget _buildEcgChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2 * 255),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: LineChart(
          LineChartData(
            minY: 30, // Minimum BPM value
            maxY: 200, // Maximum BPM value
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
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withValues(alpha: 0.1 * 255),
                ),
              ),
            ],
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              drawHorizontalLine: true,
              horizontalInterval: 20, // Interval in BPM
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
                axisNameWidget: const Text(
                  'BPM',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold, 
                  ),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 20, // BPM intervals
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
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
                  'Reading Analysis',
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
                  'Update Analysis',
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
    // If no data available, display a simple message
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
            'Waiting for data...',
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
        color: cardColor.withValues(alpha: 0.5 * 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3 * 255),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade200.withValues(alpha: 0.8 * 255),
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
                color: textColor.withValues(alpha: 0.1 * 255),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.2 * 255),
                  width: 1,
                ),
              ),
              child: Text(
                'Heart Rate: $_heartRate BPM',
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
        _analysisResultText = null;  // We'll leave the card empty instead of showing an error message
      });
      return;
    }

    try {
      // Check for heart rate
      final bpm = _heartRate;
      if (bpm <= 0) {
        setState(() {
          _analysisResultText = null;
        });
        return;
      }

      // Analyze heart condition based on heart rate
      String analysis;
      if (bpm < 60) {
        analysis = "Low heart rate";
        // Alert for severe low rate
        if (bpm < 50) {
          _triggerAlert("Warning: Very low heart rate!");
        }
      } else if (bpm > 100) {
        analysis = "High heart rate";
        // Alert for severe high rate
        if (bpm > 120) {
          _triggerAlert("Warning: Very high heart rate!");
        }
      } else {
        analysis = "Normal heart rate";
      }

      setState(() {
        _analysisResultText = analysis;
      });

    } catch (e) {
      setState(() {
        _analysisResultText = null;  // In case of error, leave the card empty
      });
      _logError('Error analyzing data', e);
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
  void _logError(String message, [Object? error]) {
    _logger.e(message, error);
  }

  Future<void> _refreshData() async {
    try {
      await _loadEmergencyContacts(); // Refresh emergency contacts
      final newReading = await _ecgService.getCurrentReading();
      if (mounted) {
        setState(() {
          if (newReading != null) {
            // Add to chart data
            _ecgChartData.add(FlSpot(
              _ecgChartData.length.toDouble(),
              newReading['value']?.toDouble() ?? 0.0
            ));
            
            // Keep only last 100 points
            if (_ecgChartData.length > 100) {
              _ecgChartData.removeAt(0);
            }
          }
        });
        
        // Analyze the new reading
        _analyzeCurrentReading(newReading);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating data: $e'))
        );
      }
    }
  }

  Future<void> _handleEmergency() async {
    if (!mounted) return;

    try {
      await _loadEmergencyContacts();
      if (!mounted) return;
      
      if (_emergencyContacts.isEmpty) {
        // If no emergency contacts, show warning message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Alert'),
            content: const Text('No emergency contacts added. Do you want to add contacts now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddEmergencyContactDialog();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Add Now'),
              ),
            ],
          ),
        );
        return;
      }

      // Show list of contacts with call options
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
                      'Emergency Contacts',
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
                      title: Text(contact['name'] ?? 'Contact ${index + 1}'),
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
                        label: const Text('Add Contact'),
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
                        label: const Text('Send Alert to All'),
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
            content: Text('Error contacting emergency contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Improved SMS sending function with multiple options
  Future<void> _sendEmergencySMS(String phoneNumber, {MessageType type = MessageType.both}) async {
    if (phoneNumber.isEmpty) {
      _logWarning("Cannot send message - empty phone number");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Phone number is empty'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Clean phone number of non-digit characters
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneNumber.isEmpty) {
      _logWarning("Cannot send message - phone number contains no digits");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid phone number format'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      // Show sending indicator
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear any existing snackbars first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                SizedBox(width: 16),
                Text('Sending emergency message...'),
              ],
            ),
            duration: Duration(seconds: 15), // Longer duration while sending
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      // Format and sanitize the message
      String message = _smsService.formatEmergencyMessage(
        userEmail: _userEmail ?? 'Unknown',
        heartRate: _heartRate,
        bloodPressure: _bloodPressure,
        oxygenLevel: _oxygenLevel,
        diagnosis: _analysisResultText ?? 'Not available',
      ).trim();

      bool whatsappSuccess = false;
      bool smsSuccess = false;
      String statusKey = "${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}";
      _messageStatus[statusKey] = "Sending...";
      
      // Try sending through selected channels
      if (type == MessageType.whatsapp || type == MessageType.both) {
        whatsappSuccess = await _sendWithRetry(
          () => _smsService.sendWhatsAppMessage(phoneNumber: phoneNumber, message: message),
          "WhatsApp message"
        );
      }
      
      // Only try SMS if WhatsApp failed or SMS was specifically requested
      if ((type == MessageType.sms || (type == MessageType.both && !whatsappSuccess))) {
        smsSuccess = await _sendWithRetry(
          () => _smsService.sendSMS(phoneNumber: phoneNumber, message: message),
          "SMS message"
        );
      }
      
      // Update status based on results
      if (whatsappSuccess || smsSuccess) {
        _messageStatus[statusKey] = "Sent successfully";
        
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Emergency message sent to $phoneNumber via ${whatsappSuccess ? "WhatsApp" : "SMS"}'
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        _messageStatus[statusKey] = "Failed to send";
        throw 'Failed to send emergency message through any channel';
      }
    } catch (e) {
      _logError('Error sending emergency message', e);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Try Options',
              onPressed: () => _showMessageOptionsDialog(phoneNumber),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  // Helper function to retry sending with exponential backoff
  Future<bool> _sendWithRetry(Future<bool> Function() sendFunction, String messageType) async {
    int attempts = 0;
    int baseDelayMs = 500;
    
    while (attempts < _maxRetryAttempts) {
      try {
        bool success = await sendFunction();
        if (success) return true;
        
        // If failed, wait before retrying (exponential backoff)
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(Duration(milliseconds: baseDelayMs * (1 << attempts)));
        }
      } catch (e) {
        _logError('Error in attempt $attempts', e);
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(Duration(milliseconds: baseDelayMs * (1 << attempts)));
        }
      }
    }
    return false;
  }
  
  // Show dialog with messaging options
  Future<void> _showMessageOptionsDialog(String phoneNumber) async {
    if (!mounted) return;
    
    await showDialog<MessageType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Emergency Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send to: $phoneNumber'),
            const SizedBox(height: 16),
            const Text('Choose sending method:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmergencySMS(phoneNumber, type: MessageType.sms);
            },
            child: const Text('SMS Only'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmergencySMS(phoneNumber, type: MessageType.whatsapp);
            },
            child: const Text('WhatsApp Only'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmergencySMS(phoneNumber, type: MessageType.both);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Both'),
          ),
        ],
      ),
    );
  }

  // Update the SMS service function to handle edge cases better
  Future<void> _sendEmergencyToAll() async {
    if (_emergencyContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency contacts available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Count valid phone numbers
    int validContactsCount = 0;
    for (final contact in _emergencyContacts) {
      String phone = contact['phone'] ?? '';
      phone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (phone.isNotEmpty) validContactsCount++;
    }
    
    if (validContactsCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid phone numbers in contacts'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Store context in local variable for safe access
    final BuildContext currentContext = context;
    
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Send Emergency Alert'),
        content: Text(
          'Send alert to all $validContactsCount contacts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send to All'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    // Store a fresh context for safe access after await
    final BuildContext freshContext = context;
    
    // Show progress dialog and capture its context
    BuildContext? dialogContext;
    showDialog(
      // ignore: use_build_context_synchronously
      context: freshContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogContext = context;
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Sending to $validContactsCount contacts...'),
            ],
          ),
        );
      },
    );
    
    int successCount = 0;
    int failCount = 0;
    
    // Send to all contacts
    for (final contact in _emergencyContacts) {
      try {
        String phoneNumber = contact['phone'] ?? '';
        if (phoneNumber.isEmpty) continue;
        
        // Clean phone number
        phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
        if (phoneNumber.isEmpty) continue;
        
        // Prepare message
        final message = _smsService.formatEmergencyMessage(
          userEmail: _userEmail ?? 'Unknown',
          heartRate: _heartRate,
          bloodPressure: _bloodPressure,
          oxygenLevel: _oxygenLevel,
          diagnosis: _analysisResultText ?? 'Not available',
        );
        
        bool success = await _smsService.sendWhatsAppMessage(
          phoneNumber: phoneNumber,
          message: message,
        );
        
        if (!success) {
          // Try SMS as fallback
          success = await _smsService.sendSMS(
            phoneNumber: phoneNumber,
            message: message,
          );
        }
        
        if (success) {
          successCount++;
          _messageStatus["${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}"] = "Sent successfully";
        } else {
          failCount++;
          _messageStatus["${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}"] = "Failed";
        }
      } catch (e) {
        failCount++;
        _logError('Error sending to contact', e);
      }
    }
    
    // Close progress dialog and show results
    if (mounted) {
      // Close dialog if it was shown
      if (dialogContext != null) {
        // ignore: use_build_context_synchronously
        Navigator.of(dialogContext!).pop();
      }
      
      // Show results in a new snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent to $successCount contacts${failCount > 0 ? ', $failCount failed' : ''}',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          action: failCount > 0 ? SnackBarAction(
            label: 'Retry Failed',
            onPressed: _retryFailedMessages,
            textColor: Colors.white,
          ) : null,
        ),
      );
    }
  }
  
  // Function to retry failed messages
  void _retryFailedMessages() {
    // This would need to track which specific messages failed
    // For now, just show the send to all dialog again
    _sendEmergencyToAll();
  }
  
  // Fix the auto-alert function to be more robust
  void _checkAndSendAutoAlert() async {
    // Check for emergency contacts
    if (_emergencyContacts.isEmpty) return;

    // Check if last message was sent more than 15 minutes ago
    if (_lastAutoMessageTime != null &&
        DateTime.now().difference(_lastAutoMessageTime!) < const Duration(minutes: 15)) {
      return;
    }

    // Check if any values are unrealistic
    if (_heartRate <= 0 || _heartRate > 300 || 
        _bloodPressure <= 0 || _bloodPressure > 300 ||
        _oxygenLevel <= 0 || _oxygenLevel > 100) {
      _logWarning("Skipping auto-alert due to unrealistic values");
      return;
    }

    bool isDangerous = false;
    String reason = '';

    // Check heart rate
    if (_heartRate > 120) {
      isDangerous = true;
      reason = 'Dangerous high heart rate ($_heartRate BPM)';
    } else if (_heartRate < 50) {
      isDangerous = true;
      reason = 'Dangerous low heart rate ($_heartRate BPM)';
    }
    
    // Check oxygen level
    if (_oxygenLevel < 90) {
      isDangerous = true;
      reason = 'Dangerous low oxygen level ($_oxygenLevel%)';
    }

    // Check blood pressure
    if (_bloodPressure > 180) {
      isDangerous = true;
      reason = 'Dangerous high blood pressure ($_bloodPressure mmHg)';
    } else if (_bloodPressure < 90) {
      isDangerous = true;
      reason = 'Dangerous low blood pressure ($_bloodPressure mmHg)';
    }

    if (isDangerous) {
      _lastAutoMessageTime = DateTime.now();
      
      // Log the dangerous condition
      _logWarning('Auto-alert triggered: $reason');
      
      // Store current context before async operations
      final BuildContext currentContext = context;
      
      // Show alert to user first (if app is visible)
      if (mounted) {
        _triggerAlert('Automatic alert: $reason');
      }
      
      // Validate contacts before sending
      List<Map<String, String>> validContacts = [];
      for (final contact in _emergencyContacts) {
        String phone = contact['phone'] ?? '';
        phone = phone.replaceAll(RegExp(r'[^\d]'), '');
        if (phone.isNotEmpty) {
          validContacts.add({...contact, 'phone': phone});
        }
      }
      
      if (validContacts.isEmpty) {
        _logWarning('No valid contacts for auto-alert');
        return;
      }
      
      // Send message to first valid contact only to avoid spamming
      try {
        final firstContact = validContacts.first;
        final phoneNumber = firstContact['phone'] ?? '';
        
        if (phoneNumber.isNotEmpty) {
          final message = _smsService.formatEmergencyMessage(
            userEmail: _userEmail ?? 'Unknown',
            heartRate: _heartRate,
            bloodPressure: _bloodPressure,
            oxygenLevel: _oxygenLevel,
            diagnosis: reason,
          );

          // Try both channels for auto alerts
          bool success = false;
          
          try {
            success = await _smsService.sendWhatsAppMessage(
              phoneNumber: phoneNumber,
              message: message,
            );
          } catch (e) {
            _logError('Failed WhatsApp auto-alert', e);
          }
          
          if (!success) {
            try {
              success = await _smsService.sendSMS(
                phoneNumber: phoneNumber,
                message: message,
              );
            } catch (e) {
              _logError('Failed SMS auto-alert', e);
            }
          }
          
          // Check mounted and use stored context
          if (success && mounted) {
            final String successMessage = 'Automatic alert sent: $reason';
            
            // Use a safe method to show a snackbar after async operations
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                    content: Text(successMessage),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            });
          }
        }
      } catch (e) {
        _logError('Error sending automatic alert', e);
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
            content: Text('Failed to make emergency call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddEmergencyContactDialog() async {
    try {
      _nameController.clear();
      _phoneController.clear();
      _relationController.clear();
      
      // Store context before async operation
      final BuildContext currentContext = context;

      final result = await showDialog<bool>(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _relationController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      );

      if (result == true) {
        await _loadEmergencyContacts();
        
        // Use a post-frame callback to safely handle UI after async
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      _logError('Error adding emergency contact', e);
      if (mounted) {
        // Use a post-frame callback to safely handle UI after async
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add contact: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
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
      // Reference to the user's health data in Firebase
      final healthDataRef = _databaseRef.child('users/${user.uid}/health_data');
      
      // Cancel existing subscription if any
      _healthDataSubscription?.cancel();
      
      // Listen for changes to health data
      _healthDataSubscription = healthDataRef.onValue.listen((event) {
        if (!mounted) return;
        
        final healthData = event.snapshot.value as Map<dynamic, dynamic>?;
        if (healthData != null) {
          setState(() {
            _latestHealthData = Map<String, dynamic>.from(healthData);
            _heartRate = (_latestHealthData?['heart_rate'] as num?)?.toInt() ?? 0;
            _bloodPressure = (_latestHealthData?['blood_pressure'] as num?)?.toInt() ?? 0;
            _oxygenLevel = (_latestHealthData?['oxygen_level'] as num?)?.toInt() ?? 0;
          });
        }
      }, onError: (error) {
        _logError('Error listening to health data', error);
      });
      
      _logInfo('Health data listener setup complete');
    } catch (e) {
      _logError('Failed to setup health data listener', e);
    }
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
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                        color: Colors.red.shade200.withValues(alpha: 0.8 * 255),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              color: color.withValues(alpha: 0.1 * 255),
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
              color: color.withValues(alpha: 0.1 * 255),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3 * 255),
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
}
