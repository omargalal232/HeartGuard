import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/notification_service.dart';
import '../../services/fcm_service.dart';
import '../../services/logger_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final String deviceLabel = 'ESP32_Device';
  final String variableLabel = 'heartrate';
  
  // Update the database path to match Firebase structure
  final String databasePath = 'ecg_data';
  
  List<FlSpot> ecgData = [];
  bool isMonitoring = false;
  double maxY = 200.0;
  double minY = 0.0;
  int heartRate = 0;
  double lastValue = 0;
  double rawBpmValue = 0;
  final int dataWindowSize = 100;
  DateTime? lastUpdateTime;
  bool _disposed = false;
  String? _fcmToken;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;
  final _notificationService = NotificationService();
  final _fcmService = FCMService();
  final Logger _logger = Logger();
  static const String _tag = 'MonitoringScreen';

  // For showing connection status
  String connectionStatus = 'Not connected';
  bool hasConnectionError = false;

  // Firebase Realtime Database reference and listener
  late DatabaseReference _ecgRef;
  StreamSubscription<DatabaseEvent>? _ecgSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _setupDatabaseReference();
  }

  void _setupDatabaseReference() {
    try {
      // Initialize the database with the correct path
      _ecgRef = _database.ref().child(databasePath);
      _logger.i(_tag, 'Database reference initialized: ${_ecgRef.path}');
    } catch (e) {
      _logger.e(_tag, 'Error setting up database reference', e);
    }
  }

  Future<void> _initializeFCM() async {
    try {
      // Get the FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      _logger.i(_tag, 'FCM Token: $_fcmToken');

      // Save the token to Firestore
      if (_fcmToken != null && _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('tokens')
            .doc('fcm')
            .set({
          'token': _fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        });
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        if (_auth.currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('tokens')
              .doc('fcm')
              .set({
            'token': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': 'android',
          });
        }
      });
    } catch (e) {
      _logger.e(_tag, 'Error initializing FCM', e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopMonitoring();
    super.dispose();
  }

  void _showConnectionError(String message) {
    if (_disposed) return;
    setState(() {
      connectionStatus = message;
      hasConnectionError = true;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase Error: $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void startMonitoring() {
    if (_disposed) return;
    
    setState(() {
      isMonitoring = true;
      ecgData.clear();
      heartRate = 0;
      lastValue = 0;
      rawBpmValue = 0;
      lastUpdateTime = null;
      _consecutiveErrors = 0;
      hasConnectionError = false;
    });
    
    // Listen to real-time updates from Firebase
    _ecgSubscription = _ecgRef.onValue.listen(
      (event) {
        if (_disposed) return;
        
        final snapshot = event.snapshot;
        if (snapshot.exists) {
          try {
            final data = snapshot.value;
            double value;
            
            // Handle different data formats
            if (data is num) {
              value = data.toDouble();
            } else {
              throw FormatException('Unexpected data format: ${data.runtimeType}');
            }
            
            final timestamp = DateTime.now();
            
            // Reset consecutive errors on success
            _consecutiveErrors = 0;
            hasConnectionError = false;
            
            // Update data more frequently for smoother real-time display
            if (lastUpdateTime == null || timestamp.difference(lastUpdateTime!).inMilliseconds > 2) {
              _logger.i(_tag, 'New ECG reading: $value at ${timestamp.toIso8601String()}');
              
              if (!_disposed) {
                setState(() {
                  rawBpmValue = value;
                  heartRate = value.round();
                  lastUpdateTime = timestamp;
                  
                  // Optimize data handling for faster updates
                  if (ecgData.length >= dataWindowSize) {
                    // Remove oldest point and shift remaining points
                    ecgData.removeAt(0);
                    for (int i = 0; i < ecgData.length; i++) {
                      ecgData[i] = FlSpot(i.toDouble(), ecgData[i].y);
                    }
                  }
                  // Add new point with optimized x-coordinate
                  ecgData.add(FlSpot(ecgData.length.toDouble(), value));
                });
              }

              // Check for abnormalities
              if (value < 60 || value > 100) {
                _saveHeartRateData(value, timestamp);
              }
            }
          } catch (e) {
            _logger.e(_tag, 'Error processing data', e);
            _showConnectionError('Error processing data: ${e.toString()}');
          }
        } else {
          _logger.w(_tag, 'No data found in Firebase');
          _consecutiveErrors++;
          _showConnectionError('No data found at ${_ecgRef.path}');
          
          if (_consecutiveErrors >= _maxConsecutiveErrors) {
            stopMonitoring();
          }
        }
      },
      onError: (error) {
        if (!_disposed) {
          _logger.e(_tag, 'Error listening to Firebase updates', error);
          _showConnectionError('Connection error: ${error.toString()}');
          _consecutiveErrors++;
          
          if (_consecutiveErrors >= _maxConsecutiveErrors) {
            stopMonitoring();
          }
        }
      },
    );
  }

  void stopMonitoring() {
    _ecgSubscription?.cancel();
    if (!_disposed && mounted) {
      setState(() {
        isMonitoring = false;
      });
    }
  }

  Future<void> _saveHeartRateData(double rawValue, DateTime timestamp) async {
    if (_disposed) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _logger.e(_tag, 'Error: No user logged in');
        return;
      }

      _logger.i(_tag, 'Saving heart rate data: $rawValue BPM');
      
      // Create Firestore timestamp
      final firestoreTimestamp = Timestamp.fromDate(timestamp);
      
      // Save heart rate data to Firestore
      await _firestore.collection('heartRateData').add({
        'userId': userId,
        'heartRate': rawValue,
        'timestamp': firestoreTimestamp,
        'isAbnormal': rawValue < 60 || rawValue > 100,
        'abnormalityType': rawValue < 60 ? 'low_heart_rate' : (rawValue > 100 ? 'high_heart_rate' : null),
      });
      _logger.i(_tag, 'Heart rate data saved successfully');

      // Send FCM notification for abnormal readings
      if ((rawValue < 60 || rawValue > 100) && !_disposed && _fcmToken != null) {
        final abnormalityType = rawValue < 60 ? 'low_heart_rate' : 'high_heart_rate';
        
        _logger.w(_tag, 'Abnormal heart rate detected: $rawValue BPM - Sending FCM notification');
        final success = await _fcmService.sendAbnormalHeartRateNotification(
          deviceToken: _fcmToken!,
          heartRate: rawValue,
          abnormalityType: abnormalityType,
        );
        
        if (success) {
          _logger.i(_tag, 'FCM notification sent successfully');
        } else {
          _logger.w(_tag, 'Failed to send FCM notification');
        }

        // Also send through NotificationService for local notifications
        if (!_disposed) {
          await _notificationService.sendAbnormalityNotification(
            userId: userId,
            heartRate: rawValue.round(),
            abnormalityType: abnormalityType,
          );
        }
      }
    } catch (e) {
      _logger.e(_tag, 'Error saving heart rate data and sending notification', e);
    }
  }

  Color _getHeartRateColor() {
    if (heartRate == 0) return Colors.grey;
    if (heartRate < 60) return Colors.blue;
    if (heartRate > 100) return Colors.red;
    return Colors.green;
  }

  String _getHeartRateStatus() {
    if (heartRate == 0) return 'No Data';
    if (heartRate < 60) return 'Low';
    if (heartRate > 100) return 'High';
    return 'Normal';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Monitoring'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Heart Rate Monitoring'),
                  content: const Text(
                    'Normal heart rate range: 60-100 BPM\n\n'
                    '• Below 60 BPM: Bradycardia\n'
                    '• Above 100 BPM: Tachycardia\n\n'
                    'The graph shows real-time heart rate data from your device.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final padding = constraints.maxWidth > 600 ? 24.0 : 16.0;
          
          Widget mainContent = Column(
            children: [
              // Status and Controls Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Heart Rate Card with Animation
                    SizedBox(
                      width: constraints.maxWidth > 600 ? 300 : double.infinity,
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Heart Rate',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getHeartRateColor().withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getHeartRateStatus(),
                                      style: TextStyle(
                                        color: _getHeartRateColor(),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rawBpmValue.toStringAsFixed(0),
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getHeartRateColor(),
                                    ),
                                  ),
                                  Text(
                                    'BPM',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _getHeartRateColor(),
                                    ),
                                  ),
                                ],
                              ),
                              if (lastUpdateTime != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Last updated: ${_formatTime(lastUpdateTime!)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Monitoring Controls Card
                    SizedBox(
                      width: constraints.maxWidth > 600 ? 300 : double.infinity,
                      child: _buildMonitoringControlsCard(),
                    ),
                  ],
                ),
              ),

              // ECG Graph with Enhanced Features
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: _buildECGGraphCard(),
                ),
              ),
            ],
          );

          // For landscape mode on smaller screens, use SingleChildScrollView
          if (isLandscape && constraints.maxWidth <= 600) {
            mainContent = SingleChildScrollView(
              child: mainContent,
            );
          }

          return mainContent;
        },
      ),
    );
  }

  Widget _buildMonitoringControlsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monitoring Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMonitoring ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isMonitoring ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMonitoring ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isMonitoring ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMonitoring ? stopMonitoring : startMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMonitoring ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: clearGraph,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Clear Graph',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Data Points: ${ecgData.length}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildECGGraphCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ECG Graph',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    Text(
                      'Range: 40-200 BPM',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: clearGraph,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Clear Graph',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 500,
              child: ecgData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          if (isMonitoring) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Waiting for data...',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          horizontalInterval: 50,
                          drawVerticalLine: true,
                          verticalInterval: 50,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[300]?.withOpacity(0.5),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.grey[300]?.withOpacity(0.5),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: 50,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}s',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              interval: 50,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        minX: 0,
                        maxX: dataWindowSize.toDouble(),
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: ecgData,
                            isCurved: true,
                            curveSmoothness: 0.02,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void clearGraph() {
    setState(() {
      ecgData.clear();
    });
  }
}
