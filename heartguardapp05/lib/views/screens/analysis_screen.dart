import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> analysisHistory = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAnalysisHistory();
  }

  Future<void> _loadAnalysisHistory() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analysis')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        analysisHistory = snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load analysis history';
        isLoading = false;
      });
    }
  }

  Future<void> _startNewAnalysis() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // TODO: Implement ML analysis here
      // This is where you would:
      // 1. Get the latest ECG readings
      // 2. Process them through your ML model
      // 3. Save the results to Firestore
      
      await Future.delayed(const Duration(seconds: 2)); // Simulated analysis time

      // Sample analysis result
      final analysisResult = {
        'timestamp': DateTime.now(),
        'risk_level': 'Low',
        'confidence': 0.89,
        'recommendations': [
          'Regular exercise',
          'Maintain healthy diet',
          'Regular check-ups',
        ],
        'abnormalities_detected': false,
      };

      // Save to Firestore
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('analysis')
          .add(analysisResult);

      // Refresh the history
      await _loadAnalysisHistory();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete analysis: ${e.toString()}'),
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
        title: const Text('Heart Analysis'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalysisHistory,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New Analysis Button
              ElevatedButton.icon(
                onPressed: _startNewAnalysis,
                icon: const Icon(Icons.add_chart),
                label: const Text('Start New Analysis'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Analysis History
              Text(
                'Analysis History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      TextButton(
                        onPressed: _loadAnalysisHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (analysisHistory.isEmpty)
                const Center(
                  child: Text('No analysis history available'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: analysisHistory.length,
                    itemBuilder: (context, index) {
                      final analysis = analysisHistory[index];
                      final timestamp = analysis['timestamp'] as DateTime;
                      final riskLevel = analysis['risk_level'] as String;
                      final confidence = analysis['confidence'] as double;
                      final recommendations =
                          List<String>.from(analysis['recommendations']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Analysis Result',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    timestamp.toString().split('.')[0],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Risk Level',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        riskLevel,
                                        style: TextStyle(
                                          color: riskLevel == 'Low'
                                              ? Colors.green
                                              : riskLevel == 'Medium'
                                                  ? Colors.orange
                                                  : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Confidence',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '${(confidence * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Recommendations',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ...recommendations.map(
                                (rec) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(rec),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}