import 'package:flutter/material.dart';
import 'package:heartguard/pages/profile_&_settings_screen.dart';
import 'package:heartguard/pages/main_screen.dart';
import 'package:heartguard/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/alert_model.dart';

class AnalysisAndAlertsScreen extends StatelessWidget {
  const AnalysisAndAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Analysis & Alerts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: firestoreService.getUserAlerts(userId),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final alerts = snapshot.data!;
            if (alerts.isEmpty) {
              return Center(
                child: Text(
                  'No alerts yet.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  color: _getAlertColor(alert.type),
                  child: ListTile(
                    leading: Icon(
                      _getAlertIcon(alert.type),
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    title: Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    subtitle: Text(
                      alert.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    trailing: Text(
                      _formatTimestamp(alert.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    onTap: () {
                      // Handle alert tap if needed
                    },
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Color _getAlertColor(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return Colors.red.shade100;
      case 'warning':
        return Colors.orange.shade100;
      case 'info':
      default:
        return Colors.blue.shade100;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'warning':
        return Icons.warning_amber;
      case 'info':
      default:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}