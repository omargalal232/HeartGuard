import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../../services/fcm_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final String ubidotsToken = 'BBUS-gKl3iGUVlBfpU2Aan3mixPdnPjruzP';
  final String deviceLabel = 'esp32';
  final String variableLabel = 'sensor12';
  
  List<FlSpot> ecgData = [];
  Timer? _timer;
  bool isMonitoring = false;
  double maxY = 200;
  double minY = 0;
  int heartRate = 0;
  double lastValue = 0;
  double rawBpmValue = 0;
  final int dataWindowSize = 100;
  DateTime? lastUpdateTime;
  bool _disposed = false;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _notificationService = NotificationService();
  final _fcmService = FCMService();

  @override
  void dispose() {
    _disposed = true;
    stopMonitoring();
    super.dispose();
  }

  Future<void> fetchEcgData() async {
    if (_disposed) return;
    
    try {
      final response = await http.get(
        Uri.parse(
          'https://industrial.api.ubidots.com/api/v1.6/devices/$deviceLabel/$variableLabel/values?page_size=1',
        ),
        headers: {
          'X-Auth-Token': ubidotsToken,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 2));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final value = data['results'][0]['value'].toDouble();
          final timestamp = DateTime.now();
          
          // Only update if we have a new value
          if (lastUpdateTime == null || timestamp.difference(lastUpdateTime!).inMilliseconds > 500) {
            print('New heart rate reading: $value BPM at ${timestamp.toIso8601String()}');
            
            if (!_disposed) {
              setState(() {
                rawBpmValue = value;
                heartRate = value.round();
                lastUpdateTime = timestamp;
                
                if (ecgData.length >= dataWindowSize) {
                  ecgData.removeAt(0);
                  for (int i = 0; i < ecgData.length; i++) {
                    ecgData[i] = FlSpot(i.toDouble(), ecgData[i].y);
                  }
                }
                ecgData.add(FlSpot(ecgData.length.toDouble(), value));
              });
            }

            // Check for abnormalities and save data
            if (value < 60 || value > 100) {
              print('Abnormal heart rate detected: $value BPM');
              print('Saving data and sending notification...');
              await _saveHeartRateData(value, timestamp);
            }
          }
        }
      } else {
        debugPrint('Error fetching data: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error fetching heart rate data: $e');
      }
    }
  }

  Future<void> _saveHeartRateData(double rawValue, DateTime timestamp) async {
    if (_disposed) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('Error: No user logged in');
        return;
      }

      print('Saving heart rate data: $rawValue BPM');
      
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
      print('Heart rate data saved successfully');

      // Send FCM notification for abnormal readings
      if ((rawValue < 60 || rawValue > 100) && !_disposed) {
        final deviceToken = 'eHdVTYh9QPmflHP_RB6Olc:APA91bHUsZWDXkcscf2HAwgEtJZk9Hh6o6NAAktPxOwgcLHCj4sw7DyqSg1p_-YQsZGIsjyYMuOcbMqZl12sOWwNkQPBQeDq_2_RNj4VZ_r9HPRxEWpw4sA';
        final abnormalityType = rawValue < 60 ? 'low_heart_rate' : 'high_heart_rate';
        
        print('Abnormal heart rate detected: $rawValue BPM - Sending FCM notification');
        final success = await _fcmService.sendAbnormalHeartRateNotification(
          deviceToken: deviceToken,
          heartRate: rawValue,
          abnormalityType: abnormalityType,
        );
        
        if (success) {
          print('FCM notification sent successfully');
        } else {
          print('Failed to send FCM notification');
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
      print('Error saving heart rate data and sending notification: $e');
      print('Error details: ${e.toString()}');
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
    });
    
    // Initial fetch
    fetchEcgData();
    
    // Set up periodic fetching every 500ms
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_disposed) {
        fetchEcgData();
      } else {
        timer.cancel();
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed && mounted) {
      setState(() {
        isMonitoring = false;
      });
    }
  }

  Color _getHeartRateColor() {
    if (heartRate == 0) return Colors.grey;
    if (heartRate < 60) return Colors.blue;
    if (heartRate > 100) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Monitoring'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final padding = constraints.maxWidth > 600 ? 24.0 : 16.0;
          
          Widget mainContent = Column(
            children: [
              // Current Heart Rate and Status Row
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Current Heart Rate Card
                    SizedBox(
                      width: constraints.maxWidth > 600 ? 300 : double.infinity,
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Heart Rate:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    rawBpmValue.toStringAsFixed(0),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getHeartRateColor(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BPM',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getHeartRateColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Status Card
                    SizedBox(
                      width: constraints.maxWidth > 600 ? 300 : double.infinity,
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monitoring Status',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isMonitoring ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isMonitoring ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: isMonitoring ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: isMonitoring ? stopMonitoring : startMonitoring,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMonitoring ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
                                label: Text(isMonitoring ? 'Stop' : 'Start'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ECG Graph
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
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
                                'ECG Waveform',
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
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Range: 40-200 BPM',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ecgData.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.monitor_heart_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No ECG data available\nPress Start to begin monitoring',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      minY: minY,
                                      maxY: maxY,
                                      minX: 0,
                                      maxX: dataWindowSize.toDouble(),
                                      clipData: const FlClipData.all(),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: ecgData,
                                          isCurved: true,
                                          curveSmoothness: 0.3,
                                          color: Theme.of(context).colorScheme.primary,
                                          barWidth: 2,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          ),
                                        ),
                                      ],
                                      gridData: FlGridData(
                                        show: true,
                                        drawHorizontalLine: true,
                                        horizontalInterval: 40,
                                        drawVerticalLine: true,
                                        verticalInterval: 20,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: Colors.grey.withOpacity(0.2),
                                            strokeWidth: 0.8,
                                          );
                                        },
                                        getDrawingVerticalLine: (value) {
                                          return FlLine(
                                            color: Colors.grey.withOpacity(0.1),
                                            strokeWidth: 0.8,
                                          );
                                        },
                                      ),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: 40,
                                          ),
                                        ),
                                        bottomTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    duration: const Duration(milliseconds: 0),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
}
