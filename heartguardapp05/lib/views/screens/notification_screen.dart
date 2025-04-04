import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/notification_service.dart';
import '../../services/logger_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _notificationService = NotificationService();
  final Logger _logger = Logger();
  static const String _tag = 'NotificationScreen';
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String? _error;
  StreamSubscription<QuerySnapshot>? _heartRateSubscription;
  final _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _noMoreData = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startHeartRateMonitoring();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _heartRateSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
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
      _logger.e(_tag, 'Error monitoring heart rate', error);
    });
  }

  Future<void> _loadNotifications({DocumentSnapshot? lastDocument}) async {
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

      Query query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(50); // Limit to last 50 notifications
          
      // If we have a last document, start after it (for pagination)
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      if (!mounted) return;
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _noMoreData = true;
          _isLoading = false;
        });
        return;
      }

      final notifications = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
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
        // If loading more, append to the existing list
        if (lastDocument != null) {
          _notifications.addAll(notifications);
        } else {
          _notifications = notifications;
        }
        _isLoading = false;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      });
    } catch (e) {
      _logger.e(_tag, 'Error loading notifications', e);
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
      _logger.e(_tag, 'Error marking notification as read', e);
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshNotifications,
                      child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final heartRate = notification['heartRate'] as int;
                        final isRead = notification['isRead'] as bool;
                        final message = notification['message'] as String;
                        final timestamp = notification['timestamp'] as Timestamp;
                          final abnormalityType = notification['abnormalityType'] as String?;

                          // Determine alert type and color
                          Color alertColor;
                          IconData alertIcon;
                          if (abnormalityType == 'high_heart_rate') {
                            alertColor = Colors.red;
                            alertIcon = Icons.arrow_upward;
                          } else if (abnormalityType == 'low_heart_rate') {
                            alertColor = Colors.blue;
                            alertIcon = Icons.arrow_downward;
                          } else {
                            alertColor = Colors.orange;
                            alertIcon = Icons.warning;
                          }

                          return Dismissible(
                            key: Key(notification['id']),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              // Remove the notification
                              _firestore
                                  .collection('notifications')
                                  .doc(notification['id'])
                                  .delete();
                              setState(() {
                                _notifications.removeAt(index);
                              });
                            },
                            child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isRead ? 1 : 3,
                              color: isRead ? null : alertColor.withAlpha(13),
                              child: InkWell(
                                onTap: () => _markAsRead(notification['id']),
                          child: Padding(
                                  padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                            alertIcon,
                                            color: alertColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                          Text(
                                            '$heartRate BPM',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              color: alertColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!isRead)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: alertColor.withAlpha(26),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'NEW',
                                      style: TextStyle(
                                                  color: alertColor,
                                                  fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: isRead ? Colors.grey[600] : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                      Text(
                                        _formatDateTime(timestamp),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ),
                        );
                      },
                      ),
                    ),
    );
  }

  void _scrollListener() {
    if (_scrollController.position.maxScrollExtent == _scrollController.offset) {
      _loadMoreNotifications();
    }
  }

  void _loadMoreNotifications() {
    if (!_isLoading && !_noMoreData) {
      _loadNotifications(lastDocument: _lastDocument);
    }
  }
} 