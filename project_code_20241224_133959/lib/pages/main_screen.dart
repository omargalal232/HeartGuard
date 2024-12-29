import 'package:flutter/material.dart';
import 'package:heartguard/pages/analysis_&_alerts_screen.dart';
import 'package:heartguard/pages/history_screen.dart';
import 'package:heartguard/pages/home_page.dart';
import 'package:heartguard/pages/profile_&_settings_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // List of widgets for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    AnalysisAndAlertsScreen(),
    HistoryScreen(),
    ProfileSettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.activity),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 