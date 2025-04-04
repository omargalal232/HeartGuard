import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logger_service.dart';


class UbidotsService {
  final String token;
  final String deviceLabel;
  final _client = http.Client();
  final Logger _logger = Logger();
  static const String _tag = 'UbidotsService';
  bool _isDisposed = false;
  
  // Update the base URL for STEM Ubidots
  static const String _baseUrl = 'https://industrial.api.ubidots.com/api/v1.6';
 
  static const String _dashboardBaseUrl = 'https://stem.ubidots.com/app/dashboards/';
  
  static const String _defaultDeviceLabel = 'esp32';

  UbidotsService({
    required this.token,
    this.deviceLabel = _defaultDeviceLabel,
  });

  String get dashboardUrl => _dashboardBaseUrl;

  Future<double?> getLatestVariableValue(String variableLabel) async {
    if (_isDisposed) return null;

    try {
      // Get current time in milliseconds since epoch
      final now = DateTime.now().millisecondsSinceEpoch;
      // Get time 5 seconds ago to avoid retention limit issues
      final fiveSecondsAgo = now - (5 * 1000);
      
      _logger.i(_tag, 'Fetching data from Ubidots for device: $deviceLabel, variable: $variableLabel');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/devices/$deviceLabel/$variableLabel/values/?page_size=1&start_time=$fiveSecondsAgo&end_time=$now'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final value = data['results'][0]['value']?.toDouble();
          _logger.i(_tag, 'Successfully received data: $value');
          return value;
        } else {
          _logger.w(_tag, 'No results found in Ubidots response');
        }
      } else {
        _logger.e(_tag, 'Error fetching $variableLabel from Ubidots: ${response.statusCode}');
        _logger.e(_tag, 'Response body: ${response.body}');
        
        if (response.statusCode == 404) {
          _logger.e(_tag, 'Device or variable not found in Ubidots. Please check your device label and variable name.');
        } else if (response.statusCode == 401) {
          _logger.e(_tag, 'Authentication error with Ubidots. Please check your API token.');
        } else if (response.statusCode == 402) {
          _logger.e(_tag, 'Payment required error. Your account may have exceeded the free tier limits.');
        }
      }
      return null;
    } catch (e) {
      _logger.e(_tag, 'Error fetching $variableLabel from Ubidots', e);
      return null;
    }
  }

  Future<List<double>?> getLatestECGData() async {
    if (_isDisposed) return null;

    try {
      // Get current time in milliseconds since epoch
      final now = DateTime.now().millisecondsSinceEpoch;
      // Get time 10 seconds ago to avoid retention limit issues
      final tenSecondsAgo = now - (10 * 1000);
      
      _logger.i(_tag, 'Fetching ECG data from Ubidots for device: $deviceLabel');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/devices/$deviceLabel/ecg/values/?page_size=100&start_time=$tenSecondsAgo&end_time=$now'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final values = List<double>.from(
            data['results'].map((result) => result['value']?.toDouble() ?? 0.0),
          );
          _logger.i(_tag, 'Successfully received ${values.length} ECG data points from Ubidots');
          return values;
        } else {
          _logger.w(_tag, 'No ECG results found in Ubidots response');
        }
      } else {
        _logger.e(_tag, 'Error fetching ECG data from Ubidots: ${response.statusCode}');
        _logger.e(_tag, 'Response body: ${response.body}');
        
        if (response.statusCode == 404) {
          _logger.e(_tag, 'Device or ECG variable not found in Ubidots. Please check your device label.');
        }
      }
      return null;
    } catch (e) {
      _logger.e(_tag, 'Error fetching ECG data from Ubidots', e);
      return null;
    }
  }
  
  // Method to check if Ubidots token is valid
  Future<bool> validateToken() async {
    if (_isDisposed) return false;
    
    try {
      _logger.i(_tag, 'Validating Ubidots token');
      
      // For STEM accounts, we don't need to validate the token format
      // Just check if we can access the device
      final response = await _client.get(
        Uri.parse('$_baseUrl/devices/$deviceLabel'),
        headers: {
          'X-Auth-Token': token,
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'Token validation successful');
        return true;
      } else {
        _logger.e(_tag, 'Token validation failed: ${response.statusCode}');
        _logger.e(_tag, 'Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error validating token', e);
      return false;
    }
  }
  
  // Method to check if a device and variable exist
  Future<bool> validateDeviceAndVariable(String variableLabel) async {
    if (_isDisposed) return false;

    try {
      _logger.i(_tag, 'Validating Ubidots device: $deviceLabel and variable: $variableLabel');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/devices/$deviceLabel/$variableLabel/'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _logger.i(_tag, 'Device and variable validation successful in Ubidots');
        return true;
      } else {
        _logger.e(_tag, 'Device or variable validation failed in Ubidots: ${response.statusCode}');
        _logger.e(_tag, 'Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error validating device and variable in Ubidots', e);
      return false;
    }
  }
  
  // Add a method to create a device and variable if they don't exist
  Future<bool> createDeviceAndVariable(String variableLabel, double initialValue) async {
    if (_isDisposed) return false;

    try {
      _logger.i(_tag, 'Creating device and variable in Ubidots if they don\'t exist');
      
      final payload = {
        variableLabel: initialValue,
      };
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/devices/$deviceLabel/'),
        headers: {
          'X-Auth-Token': token,
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i(_tag, 'Successfully created or updated device and variable in Ubidots');
        return true;
      } else {
        _logger.e(_tag, 'Failed to create device and variable in Ubidots: ${response.statusCode}');
        _logger.e(_tag, 'Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error creating device and variable in Ubidots', e);
      return false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _client.close();
  }
}