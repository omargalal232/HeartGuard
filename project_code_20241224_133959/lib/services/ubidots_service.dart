import 'dart:convert';
import 'package:http/http.dart' as http;

class UbidotsService {
  final String _apiKey = 'BBUS-7852e52f710b8cc6ed6ecbc0a43661b13ce'; // Replace with your Ubidots API key
  final String _deviceId = '677147e60fa85c000ed6ba49'; // Your device ID

  Future<void> sendData(double ecgValue) async {
    final url = 'https://industrial.api.ubidots.com/api/v1.6/devices/$_deviceId/';
    final headers = {
      'Content-Type': 'application/json',
      'X-Auth-Token': _apiKey,
    };

    final body = json.encode({
      'ecg_value': ecgValue, // Replace 'ecg_value' with the variable name you set in Ubidots
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        print('Data sent to Ubidots successfully');
      } else {
        print('Failed to send data: ${response.body}');
      }
    } catch (e) {
      print('Error sending data to Ubidots: $e');
    }
  }
} 