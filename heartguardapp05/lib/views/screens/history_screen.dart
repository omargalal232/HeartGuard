import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/logger_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  static const String _tag = 'HistoryScreen';
  bool _isLoading = true;
  List<Map<String, dynamic>> _heartRateHistory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHeartRateHistory();
  }

  Future<void> _loadHeartRateHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser ;
      if (user == null) {
        setState(() {
          _error = 'User  not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get heart rate data from Firestore
      final snapshot = await _firestore
          .collection('heartRateData')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() {
          _heartRateHistory = [];
          _isLoading = false;
        });
        return;
      }

      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'heartRate': data['heartRate'] ?? 0,
          'timestamp': data['timestamp'] as Timestamp,
          'favorite': data['favorite'] ?? false,
        };
      }).toList();

      setState(() {
        _heartRateHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e(_tag, 'Error loading heart rate history', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load heart rate history';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    try {
      await _firestore.collection('heartRateData').doc(id).delete();
      _loadHeartRateHistory();
    } catch (e) {
      _logger.e(_tag, 'Error deleting record', e);
      setState(() {
        _error = 'Failed to delete record';
      });
    }
  }

  Future<void> _toggleFavorite(String id, bool isFavorite) async {
    try {
      await _firestore.collection('heartRateData').doc(id).update({
        'favorite': !isFavorite,
      });
      _loadHeartRateHistory();
    } catch (e) {
      _logger.e(_tag, 'Error toggling favorite', e);
      setState(() {
        _error = 'Failed to toggle favorite';
      });
    }
  }

  void _sortRecords(String sortBy) {
    setState(() {
      if (sortBy == 'heartRate') {
        _heartRateHistory.sort((a, b) => a['heartRate'].compareTo(b['heartRate']));
      } else if (sortBy == 'timestamp') {
        _heartRateHistory.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      }
    });
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
              onPressed: _loadHeartRateHistory,
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
        title: const Text('Heart Rate History'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: _sortRecords,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'heartRate',
                child: Text('Sort by Heart Rate'),
              ),
              const PopupMenuItem(
                value: 'timestamp',
                child: Text('Sort by Timestamp'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHeartRateHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHeartRateHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView(_error!)
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
                              leading: IconButton(
                                icon: Icon(
                                  record['favorite'] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                onPressed: () => _toggleFavorite(
                                    record['id'], record['favorite'] ?? false),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteRecord(record['id']),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}