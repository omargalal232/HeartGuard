import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'home_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          // Top Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 24,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Reports',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.bell,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),

          // Reports Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Example report item
                  _buildReportItem(context, 'ECG Report', 'Normal Rhythm',
                      'Today, 10:30 AM'),
                  const SizedBox(height: 12),
                  _buildReportItem(context, 'Heart Rate Report', '72 BPM',
                      'Yesterday, 8:45 PM'),
                  const SizedBox(height: 12),
                  _buildReportItem(context, 'Blood Pressure Report',
                      '120/80 mmHg', 'Last Week, 5:00 PM'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(
      BuildContext context, String title, String status, String date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ],
          ),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
