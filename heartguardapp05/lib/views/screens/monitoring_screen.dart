import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final String ubidotsToken = 'BBUS-dotPnGDytYSjPQNBGKs68MztvEV1uD';
  final String deviceLabel = 'esp32';
  final String variableLabel = 'sensor';
  
  List<FlSpot> ecgData = [];
  Timer? _timer;
  bool isMonitoring = false;
  double maxY = 1024;
  double minY = 0;
  int heartRate = 0;
  int signalQuality = 100;
  double lastValue = 0;
  int peakCount = 0;
  DateTime? lastPeakTime;
  final int dataWindowSize = 200;
  List<double> rawData = [];
  final int smoothingWindow = 3;
  final double scaleFactor = 1.5;
  
  // Add variables for improved heart rate detection
  List<int> rrIntervals = [];
  final int maxRRIntervals = 10;  // Store last 10 RR intervals
  double threshold = 500;  // Initial threshold for R peak detection
  bool isPotentialPeak = false;
  int lastPeakIndex = -1;
  final int minRRInterval = 300;  // Minimum 300ms between peaks (200 BPM max)
  final int maxRRInterval = 1500; // Maximum 1.5s between peaks (40 BPM min)

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateHeartRate(double value, DateTime timestamp) {
    // Dynamic threshold adjustment (60% of recent maximum)
    if (value > threshold) {
      threshold = value * 0.6;
    } else {
      threshold *= 0.95; // Gradually decrease threshold
    }

    // R-peak detection with slope and amplitude criteria
    if (value > threshold && !isPotentialPeak) {
      isPotentialPeak = true;
    }

    if (isPotentialPeak && value < lastValue) {
      // Found a peak
      final currentTime = timestamp.millisecondsSinceEpoch;
      if (lastPeakTime != null) {
        final interval = currentTime - lastPeakTime!.millisecondsSinceEpoch;
        
        // Check if the interval is physiologically possible
        if (interval >= minRRInterval && interval <= maxRRInterval) {
          rrIntervals.add(interval);
          if (rrIntervals.length > maxRRIntervals) {
            rrIntervals.removeAt(0);
          }
          
          // Calculate heart rate using median of recent RR intervals
          if (rrIntervals.isNotEmpty) {
            // Sort intervals and take median to reduce impact of outliers
            List<int> sortedIntervals = List.from(rrIntervals)..sort();
            final medianInterval = sortedIntervals[sortedIntervals.length ~/ 2];
            
            // Convert to BPM
            final newRate = (60000 / medianInterval).round();
            
            // Apply smoothing with validity check
            if (newRate >= 40 && newRate <= 200) {
              setState(() {
                heartRate = (heartRate * 0.7 + newRate * 0.3).round();
              });
            }
          }
        }
      }
      lastPeakTime = timestamp;
      peakCount++;
      isPotentialPeak = false;
    }
    
    lastValue = value;
  }

  void _updateSignalQuality(double value) {
    int quality = 100;

    // Check amplitude range
    if (value < 100 || value > 900) {
      quality -= 20;
    }

    // Check for rapid changes (noise)
    if (lastValue > 0) {
      final change = (value - lastValue).abs();
      if (change > 300) {
        quality -= 30;
      } else if (change > 200) {
        quality -= 15;
      }
    }

    // Check heart rate validity
    if (heartRate < 40 || heartRate > 200) {
      quality -= 25;
    }

    // Check RR interval consistency
    if (rrIntervals.length >= 3) {
      final intervals = List.from(rrIntervals)..sort();
      final medianInterval = intervals[intervals.length ~/ 2];
      for (final interval in intervals) {
        if ((interval - medianInterval).abs() > medianInterval * 0.2) {
          quality -= 5; // Penalty for each irregular interval
        }
      }
    }

    // Ensure quality stays within 0-100
    quality = quality.clamp(0, 100);

    setState(() {
      signalQuality = quality;
    });
  }

  Future<void> fetchEcgData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://industrial.api.ubidots.com/api/v1.6/devices/$deviceLabel/$variableLabel/values',
        ),
        headers: {
          'X-Auth-Token': ubidotsToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final value = data['results'][0]['value'].toDouble();
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            (data['results'][0]['timestamp'] * 1000).toInt(),
          );
          
          // Process the signal
          rawData.add(value);
          if (rawData.length > smoothingWindow) {
            rawData.removeAt(0);
          }
          
          // Apply simple moving average for smoothing
          double smoothedValue = 0;
          for (double val in rawData) {
            smoothedValue += val;
          }
          smoothedValue /= rawData.length;
          
          setState(() {
            // Scale the value for better visualization
            final scaledValue = smoothedValue * scaleFactor;
            
            // Add new data point
            ecgData.add(FlSpot(ecgData.length.toDouble(), scaledValue));
            
            // Keep last dataWindowSize points for better visualization
            if (ecgData.length > dataWindowSize) {
              ecgData.removeAt(0);
              // Shift x-coordinates to maintain continuous scrolling
              for (int i = 0; i < ecgData.length; i++) {
                ecgData[i] = FlSpot(i.toDouble(), ecgData[i].y);
              }
            }
            
            // Update Y-axis range with padding
            if (ecgData.isNotEmpty) {
              final maxValue = ecgData.map((spot) => spot.y).reduce(math.max);
              final minValue = ecgData.map((spot) => spot.y).reduce(math.min);
              final range = maxValue - minValue;
              maxY = maxValue + range * 0.2;  // 20% padding
              minY = math.max(0, minValue - range * 0.2);  // Ensure non-negative
            }
          });

          _updateHeartRate(value, timestamp);
          _updateSignalQuality(value);
        }
      }
    } catch (e) {
      debugPrint('Error fetching ECG data: $e');
    }
  }

  void startMonitoring() {
    setState(() {
      isMonitoring = true;
      ecgData.clear();
      rawData.clear();
      rrIntervals.clear();
      heartRate = 0;
      signalQuality = 100;
      lastValue = 0;
      peakCount = 0;
      lastPeakTime = null;
      threshold = 500;
      isPotentialPeak = false;
    });
    
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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

  Color _getSignalQualityColor() {
    if (signalQuality >= 80) return Colors.green;
    if (signalQuality >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Monitoring'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMonitoring ? 'Monitoring' : 'Stopped',
                          style: TextStyle(
                            color: isMonitoring ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: isMonitoring ? stopMonitoring : startMonitoring,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMonitoring ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isMonitoring ? 'Stop' : 'Start'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ECG Graph
            Expanded(
              flex: 4,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ECG Reading',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ecgData.isEmpty
                            ? const Center(
                                child: Text('No data available'),
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
                                      curveSmoothness: 0.35,  // Adjust curve smoothness
                                      color: Colors.red,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.red.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                  gridData: FlGridData(
                                    show: true,
                                    drawHorizontalLine: true,
                                    horizontalInterval: 200,  // Adjust grid interval
                                    drawVerticalLine: true,
                                    verticalInterval: 40,     // Adjust grid interval
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
                                        interval: 200,
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

            // Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          context,
                          'Heart Rate',
                          heartRate.toString(),
                          'BPM',
                          Icons.favorite,
                          _getHeartRateColor(),
                        ),
                        _buildStatItem(
                          context,
                          'Signal Quality',
                          signalQuality.toString(),
                          '%',
                          Icons.signal_cellular_alt,
                          _getSignalQualityColor(),
                        ),
                      ],
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

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ],
    );
  }
} 