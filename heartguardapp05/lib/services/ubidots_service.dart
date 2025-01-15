import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;


class UbidotsService {
  final String token;
  final String deviceLabel;
  final _client = http.Client();
  bool _isDisposed = false;
  
  // Base URL for Ubidots dashboard
  static const String _dashboardBaseUrl = 'https://industrial.ubidots.com/app/dashboards/public/dashboard/aC9mz3U8pQz5xzJOyQQnq4-h2KHrMT7e5sTgM_wFPUE?navbar=true&contextbar=false';
  // Replace this with your actual dashboard ID
  static const String _dashboardId = 'YOUR_DASHBOARD_ID';

  UbidotsService({
    required this.token,
    required this.deviceLabel,
  });

  String get dashboardUrl => '$_dashboardBaseUrl$_dashboardId';

  Future<double?> getLatestVariableValue(String variableLabel) async {
    if (_isDisposed) return null;

    try {
      final response = await _client.get(
        Uri.parse('https://industrial.api.ubidots.com/api/v1.6/devices/$deviceLabel/$variableLabel/values/?page_size=1'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['value']?.toDouble();
        }
      }
      return null;
    } catch (e) {
      print('Error fetching $variableLabel: $e');
      return null;
    }
  }

  Future<List<double>?> getLatestECGData() async {
    if (_isDisposed) return null;

    try {
      final response = await _client.get(
        Uri.parse('https://industrial.api.ubidots.com/api/v1.6/devices/$deviceLabel/ecg/values/?page_size=100'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          return List<double>.from(
            data['results'].map((result) => result['value']?.toDouble() ?? 0.0),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error fetching ECG data: $e');
      return null;
    }
  }

  void dispose() {
    _isDisposed = true;
    _client.close();
  }
}