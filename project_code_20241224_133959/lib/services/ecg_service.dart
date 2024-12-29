import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ECGService extends ChangeNotifier {
  final String _apiKey = 'BBUS-7852e52f710b8cc6ed6ecbc0a43661b13ce'; // Replace with your actual API key
  final String _deviceId = '677147e60fa85c000ed6ba49'; // Your device ID

  Future<List<dynamic>> fetchECGData() async {
    final url = 'https://industrial.api.ubidots.com/api/v1.6/devices/$_deviceId/';
    final headers = {
      'X-Auth-Token': _apiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['last_value']; // Adjust based on your API response structure
      } else {
        throw Exception('Failed to load ECG data: ${response.body}');
      }
    } catch (e) {
      print('Error fetching ECG data: $e');
      return [];
    }
  }
} 