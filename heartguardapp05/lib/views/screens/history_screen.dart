import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _historySubscription;
  List<Map<String, dynamic>> _heartRateHistory = [];

  @override
  void initState() {
    super.initState();
    _setupHistoryStream();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  void _setupHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Set up real-time listener for heart rate history
    _historySubscription = _firestore
        .collection('heartRateData')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit to last 100 readings
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        
        final history = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'heartRate': data['heartRate'] ?? 0, // Use the correct field name
            'timestamp': data['timestamp'] as Timestamp,
          };
        }).toList();

        setState(() {
          _heartRateHistory = history;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  String _formatDateTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate History'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _heartRateHistory.isEmpty
              ? const Center(
                  child: Text('No heart rate history available'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _heartRateHistory.length,
                  itemBuilder: (context, index) {
                    final record = _heartRateHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                        ),
                        title: Text(
                          '${record['heartRate']} BPM',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _formatDateTime(record['timestamp']),
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 