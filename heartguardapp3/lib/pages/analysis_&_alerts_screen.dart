import 'package:flutter/material.dart';
import '../services/analysis_service.dart';

class AnalysisAlertsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis & Alerts'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertsSummary(),
              SizedBox(height: 24),
              _buildRecentAnalysis(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSummary() {
    return Card(
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
        Text(
          'Recent Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: TextStyle(color: Colors.grey)),
                Text(heartRate, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 4),
            Text(details),
          ],
        ),
      ),
    );
  }
}