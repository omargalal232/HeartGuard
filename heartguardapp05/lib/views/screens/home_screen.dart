import 'package:flutter/material.dart';
import 'monitoring_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'file_upload_screen.dart'; // Add the import for the FileUploadScreen.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MonitoringScreen(),
    const NotificationScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
    const FileUploadScreen(), // Add the FileUploadScreen to the list.
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 4) {
      // Redirect to the file upload screen when the heart sound icon is tapped.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FileUploadScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speaker),
            label: 'Heart Sound',
          ),
        ],
      ),
    );
  }
}
