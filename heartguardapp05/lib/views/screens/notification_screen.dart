import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String? _error;
  StreamSubscription<QuerySnapshot>? _heartRateSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startHeartRateMonitoring();
  }

  @override
  void dispose() {
    _heartRateSubscription?.cancel();
    super.dispose();
  }

  void _startHeartRateMonitoring() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    _heartRateSubscription?.cancel();

    _heartRateSubscription = _firestore
        .collection('heartRateData')
        .orderBy('timestamp', descending: true)
        .limit(10) // Monitor last 10 readings
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      // Process each reading for abnormalities
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final heartRate = data['heartRate'] as num?;
        final timestamp = data['timestamp'] as Timestamp?;
        final ecgReading = data['ecgReading'] as List<dynamic>?;
        
        if (heartRate == null || timestamp == null) continue;

        // Only process readings from the last minute
        final now = DateTime.now();
        final readingTime = timestamp.toDate();
        if (now.difference(readingTime).inMinutes > 1) continue;

        // Check for abnormalities
        bool hasAbnormality = false;
        String abnormalityMessage = '';

        // Check heart rate abnormalities
        if (heartRate < 60) {
          hasAbnormality = true;
          abnormalityMessage = 'Low heart rate detected: $heartRate BPM';
        } else if (heartRate > 100) {
          hasAbnormality = true;
          abnormalityMessage = 'High heart rate detected: $heartRate BPM';
        }

        // Check ECG reading abnormalities if available
        if (ecgReading != null && ecgReading.isNotEmpty) {
          bool hasIrregularRhythm = _checkForIrregularRhythm(ecgReading);
          if (hasIrregularRhythm) {
            hasAbnormality = true;
            abnormalityMessage = 'Irregular heart rhythm detected';
          }
        }

        // Create notification if abnormality detected
        if (hasAbnormality) {
          await _createNotification(
            userId: user.uid,
            heartRate: heartRate.toInt(),
            message: abnormalityMessage,
          );
        }
      }
    }, onError: (error) {
      print('Error monitoring heart rate: $error');
    });
  }

  bool _checkForIrregularRhythm(List<dynamic> ecgReading) {
    // Basic irregular rhythm detection
    if (ecgReading.length < 2) return false;

    try {
      // Convert readings to numbers
      List<double> readings = ecgReading.map((e) => double.parse(e.toString())).toList();
      
      // Calculate average difference between consecutive readings
      double sumDiff = 0;
      for (int i = 1; i < readings.length; i++) {
        sumDiff += (readings[i] - readings[i - 1]).abs();
      }
      double avgDiff = sumDiff / (readings.length - 1);

      // Check for significant variations
      int irregularCount = 0;
      for (int i = 1; i < readings.length; i++) {
        double diff = (readings[i] - readings[i - 1]).abs();
        if (diff > avgDiff * 2) { // If difference is more than double the average
          irregularCount++;
        }
      }

      // If more than 20% of intervals are irregular
      return irregularCount > readings.length * 0.2;
    } catch (e) {
      print('Error analyzing ECG reading: $e');
      return false;
    }
  }

  String _getHeartRateMessage(int heartRate) {
    if (heartRate < 60) {
      return 'Low heart rate detected: $heartRate BPM';
    } else if (heartRate > 100) {
      return 'High heart rate detected: $heartRate BPM';
    }
    return 'Abnormal heart rate detected: $heartRate BPM';
  }

  Future<void> _createNotification({
    required String userId,
    required int heartRate,
    required String message,
  }) async {
    try {
      // Check if a similar notification was created in the last 5 minutes
      final recentNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ))
          .get();

      // Don't create a new notification if there's a recent one
      if (recentNotifications.docs.isNotEmpty) return;

      await _firestore.collection('notifications').add({
        'userId': userId,
        'heartRate': heartRate,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Reload notifications to show the new one
      if (mounted) {
        await _loadNotifications();
      }
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      if (!mounted) return;

      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'message': data['message'] ?? 'Abnormal heart rate detected',
          'heartRate': data['heartRate'] ?? 0,
          'timestamp': data['timestamp'] as Timestamp? ?? Timestamp.now(),
          'isRead': data['isRead'] ?? false,
          'userId': data['userId'] ?? user.uid,
        };
      }).toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    // Restart heart rate monitoring
    _startHeartRateMonitoring();
    
    // Load notifications
    await _loadNotifications();
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications refreshed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
            'isRead': true,
          });

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark as read: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(_error!)
              : _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'No notifications available',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshNotifications,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: notification['isRead']
                              ? null
                              : Colors.blue.withOpacity(0.1),
                          child: ListTile(
                            leading: Icon(
                              Icons.warning_amber_rounded,
                              color: notification['isRead']
                                  ? Colors.grey
                                  : Colors.orange,
                            ),
                            title: Text(notification['message']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Heart Rate: ${notification['heartRate']} BPM'),
                                Text(_formatDateTime(notification['timestamp'])),
                              ],
                            ),
                            trailing: !notification['isRead']
                                ? TextButton(
                                    onPressed: () => _markAsRead(notification['id']),
                                    child: const Text('Mark as Read'),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
} 