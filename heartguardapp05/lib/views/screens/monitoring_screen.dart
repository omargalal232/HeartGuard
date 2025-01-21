import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final String ubidotsToken = 'BBUS-dotPnGDytYSjPQNBGKs68MztvEV1uD';
  final String deviceLabel = 'esp32';
  final String variableLabel = 'heart_rate';

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

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveHeartRateData(double rawValue, DateTime timestamp) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('heartRateData').add({
        'userId': userId,
        'heartRate': rawValue,
        'timestamp': timestamp,
      });
    } catch (e) {
      debugPrint('Error saving heart rate data: $e');
    }
  }

  Future<void> fetchEcgData() async {
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final value = data['results'][0]['value'].toDouble();
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            (data['results'][0]['timestamp'] * 1000).toInt(),
          );

          if (lastUpdateTime != timestamp) {
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

            _saveHeartRateData(value, timestamp);
          }
        }
      } else {
        debugPrint('Error fetching data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching heart rate data: $e');
    }
  }

  void startMonitoring() {
    setState(() {
      isMonitoring = true;
      ecgData.clear();
      heartRate = 0;
      lastValue = 0;
      rawBpmValue = 0;
      lastUpdateTime = null;
    });

    fetchEcgData();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      fetchEcgData();
    });
  }

  void stopMonitoring() {
    setState(() {
      isMonitoring = false;
    });
    _timer?.cancel();
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
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0), // Add vertical padding for better spacing
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Heart Rate and Status Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Current Heart Rate Card
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
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
                    width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                      SizedBox(
                        height: 300, // Set a fixed height for the graph
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
          ],
        ),
      ),
    ),
  );
}
}