import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'ecg_recording_screen.dart';
import 'analysis_&_alerts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Heart Guard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserGreeting(authService.currentUser),
              SizedBox(height: 24),
              _buildQuickActions(context),
              SizedBox(height: 24),
              _buildHealthMetrics(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildUserGreeting(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${user?.displayName ?? 'User'}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Monitor your heart health',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _actionCard(
          context,
          'Start ECG',
          Icons.favorite,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ECGRecordingScreen()),
          ),
        ),
        _actionCard(
          context,
          'View Analysis',
          Icons.analytics,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AnalysisAlertsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetrics() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricItem('Heart Rate', '72', 'BPM'),
                _metricItem('ECG Status', 'Normal', ''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text(unit),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'ECG'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
      ],
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ECGRecordingScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AnalysisAlertsScreen()),
            );
            break;
        }
      },
    );
  }
}