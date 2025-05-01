import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HeartGuard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.settingsRoute);
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeatureCard(
            context,
            'Health Monitoring',
            Icons.monitor_heart,
            AppConstants.monitoringRoute,
          ),
          
          _buildFeatureCard(
            context,
            'Emergency Contacts',
            Icons.emergency,
            AppConstants.emergencyContactsRoute,
          ),
          _buildFeatureCard(
            context,
            'Health Assistant',
            Icons.chat,
            AppConstants.chatbotRoute,
          ),
          _buildFeatureCard(
            context,
            'Profile',
            Icons.person,
            AppConstants.profileRoute,
          ),
          _buildFeatureCard(
            context,
            'Settings',
            Icons.settings,
            AppConstants.settingsRoute,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppConstants.profileRoute);
          }
        },
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return Card(
      elevation: 4.0,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.0),
            const SizedBox(height: 8.0),
            Text(title),
          ],
        ),
      ),
    );
  }
}
