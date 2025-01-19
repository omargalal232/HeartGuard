import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _notificationService = NotificationService();
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
        .limit(1) // Only listen to the latest reading
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final heartRate = data['heartRate'] as num?;
      final timestamp = data['timestamp'] as Timestamp?;
      
      if (heartRate == null || timestamp == null) return;

      // Only process readings from the last minute
      final now = DateTime.now();
      final readingTime = timestamp.toDate();
      if (now.difference(readingTime).inMinutes > 1) return;

      // Check for abnormalities
      String? abnormalityType;
      if (heartRate < 60) {
        abnormalityType = 'low_heart_rate';
      } else if (heartRate > 100) {
        abnormalityType = 'high_heart_rate';
      }

      // Send notification if abnormality detected
      if (abnormalityType != null) {
        await _notificationService.sendAbnormalityNotification(
          userId: user.uid,
          heartRate: heartRate.toInt(),
          abnormalityType: abnormalityType,
        );
      }
    }, onError: (error) {
      print('Error monitoring heart rate: $error');
    });
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
          .limit(50) // Limit to last 50 notifications
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
          'abnormalityType': data['abnormalityType'],
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

  Future<void> _addTestNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Add a test notification to Firestore
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'heartRate': 120,
        'message': 'Abnormality detected in your heart rate (120 BPM). Your heart rate is too high. Please contact a doctor.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'abnormalityType': 'high_heart_rate',
      });

      // Refresh notifications
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification added'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error adding test notification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            icon: const Icon(Icons.add_alert),
            onPressed: _addTestNotification,
          ),
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
                        final heartRate = notification['heartRate'] as int;
                        final isRead = notification['isRead'] as bool;
                        final message = notification['message'] as String;
                        final timestamp = notification['timestamp'] as Timestamp;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isRead ? 1 : 3,
                          color: isRead ? null : Colors.blue.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: isRead ? Colors.grey : Colors.orange,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Heart Guard Alert',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                          color: isRead ? Colors.grey[700] : Colors.black,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isRead ? Colors.grey[700] : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getHeartRateColor(heartRate).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$heartRate BPM',
                                        style: TextStyle(
                                          color: _getHeartRateColor(heartRate),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      TextButton(
                                        onPressed: () => _markAsRead(notification['id']),
                                        child: const Text('Mark as Read'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getHeartRateColor(int heartRate) {
    if (heartRate < 60) {
      return Colors.blue; // Low heart rate
    } else if (heartRate > 100) {
      return Colors.red; // High heart rate
    }
    return Colors.green; // Normal heart rate
  }
} 