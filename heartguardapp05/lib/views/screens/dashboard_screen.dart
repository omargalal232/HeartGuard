import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/logger_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  static const String _tag = 'DashboardScreen';
  String userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists) {
          setState(() {
            userName = userData.data()?['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      _logger.e(_tag, 'Error loading user data', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $userName!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Monitor your heart health and stay connected.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Section
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildQuickActionCard(
                  context,
                  'Heart Rate',
                  Icons.favorite,
                  Colors.red,
                  () {
                    // Add navigation or action
                  },
                ),
                _buildQuickActionCard(
                  context,
                  'Emergency',
                  Icons.emergency,
                  Colors.orange,
                  () {
                    // Add navigation or action
                  },
                ),
                _buildQuickActionCard(
                  context,
                  'History',
                  Icons.history,
                  Colors.blue,
                  () {
                    // Add navigation or action
                  },
                ),
                _buildQuickActionCard(
                  context,
                  'Settings',
                  Icons.settings,
                  Colors.grey,
                  () {
                    // Add navigation or action
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Health Stats Section
            Text(
              'Health Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildHealthStat('Average Heart Rate', '72 BPM'),
                    const Divider(),
                    _buildHealthStat('Last Reading', '75 BPM'),
                    const Divider(),
                    _buildHealthStat('Daily Steps', '8,456'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}