import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Logger _logger = Logger();
  bool _locationEnabled = false;
  bool _smsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locationEnabled = prefs.getBool(AppConstants.locationEnabledKey) ?? false;
      _smsEnabled = prefs.getBool(AppConstants.smsEnabledKey) ?? false;
    });
  }

  Future<void> _toggleLocation() async {
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

  Future<void> _toggleSMS() async {
    final status = await Permission.sms.request();
    if (status.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.smsEnabledKey, !_smsEnabled);
      setState(() {
        _smsEnabled = !_smsEnabled;
      });
      _logger.i('SMS ${_smsEnabled ? 'enabled' : 'disabled'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS settings updated')),
        );
      }
    } else {
      _logger.w('SMS permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'App Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('Location Services'),
            subtitle: const Text('Enable location tracking for emergency services'),
            trailing: Switch(
              value: _locationEnabled,
              onChanged: (_) => _toggleLocation(),
            ),
          ),
          ListTile(
            title: const Text('SMS Services'),
            subtitle: const Text('Enable SMS notifications for emergency contacts'),
            trailing: Switch(
              value: _smsEnabled,
              onChanged: (_) => _toggleSMS(),
            ),
          ),
        ],
      ),
    );
  }
} 