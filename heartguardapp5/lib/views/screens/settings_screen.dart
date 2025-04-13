import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _logger = Logger();
  bool _notificationsEnabled = false;
  bool _locationEnabled = false;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(AppConstants.notificationsEnabledKey) ?? false;
      _locationEnabled = prefs.getBool(AppConstants.locationEnabledKey) ?? false;
      _selectedLanguage = prefs.getString(AppConstants.languageKey) ?? 'English';
    });
  }

  Future<void> _toggleNotifications() async {
    if (!mounted) return;
    
    final status = await Permission.notification.request();
    if (status.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.notificationsEnabledKey, !_notificationsEnabled);
      setState(() {
        _notificationsEnabled = !_notificationsEnabled;
      });
      _logger.i('Notifications ${_notificationsEnabled ? 'enabled' : 'disabled'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings updated')),
        );
      }
    } else {
      _logger.w('Notification permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied')),
        );
      }
    }
  }

  Future<void> _toggleLocation() async {
    if (!mounted) return;
    
    final status = await Permission.location.request();
    if (status.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.locationEnabledKey, !_locationEnabled);
      setState(() {
        _locationEnabled = !_locationEnabled;
      });
      _logger.i('Location ${_locationEnabled ? 'enabled' : 'disabled'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location settings updated')),
        );
      }
    } else {
      _logger.w('Location permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    }
  }

  Future<void> _changeLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.languageKey, language);
    setState(() {
      _selectedLanguage = language;
    });
    _logger.i('Language changed to $language');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language changed to $language')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
              SwitchListTile(
                title: const Text('Notifications'),
                value: _notificationsEnabled,
                onChanged: (_) => _toggleNotifications(),
              ),
              SwitchListTile(
                title: const Text('Location'),
                value: _locationEnabled,
                onChanged: (_) => _toggleLocation(),
              ),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(_selectedLanguage),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Language'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('English'),
                            onTap: () {
                              _changeLanguage('English');
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text('Spanish'),
                            onTap: () {
                              _changeLanguage('Spanish');
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Help & Support'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Help & Support'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Frequently Asked Questions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('• How do I set up emergency contacts?\n'
                                 '  Go to Emergency Contacts screen and tap the + button.\n\n'
                                 '• How do I use the SOS feature?\n'
                                 '  Go to Emergency screen and press the SOS button.\n\n'
                                 '• How do I set medication reminders?\n'
                                 '  Go to Medications screen and tap the + button.\n\n'),
                            SizedBox(height: 16),
                            Text(
                              'Contact Support',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Email: support@heartguard.com\n'
                                 'Phone: +1 (234) 567-890'),
                            SizedBox(height: 16),
                            Text(
                              'App Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Version: 1.0.0\n'
                                 'Last Updated: April 2024'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('About'),
                onTap: () => Navigator.pushNamed(context, AppConstants.aboutRoute),
              ),
            ],
          );
        },
      ),
    );
  }
} 