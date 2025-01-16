import 'package:flutter/material.dart';
import '../services/analysis_service.dart';

class AnalysisAlertsScreen extends StatelessWidget {
  const AnalysisAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis & Alerts'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertsSummary(),
              const SizedBox(height: 24),
              _buildRecentAnalysis(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSummary() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text('Irregular Heartbeat Detected'),
              subtitle: Text('2 hours ago'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnalysisCard(
          date: 'Today',
          heartRate: '72 BPM',
          status: 'Normal',
          details: 'No abnormalities detected',
        ),
      ],
    );
  }

  Widget _buildAnalysisCard({
    required String date,
    required String heartRate,
    required String status,
    required String details,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: const TextStyle(color: Colors.grey)),
                Text(heartRate, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(details),
          ],
        ),
      ),
    );
  }
}