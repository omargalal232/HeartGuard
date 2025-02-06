import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final Map<String, dynamic> _credentials = {
    "type": "service_account",
    "project_id": "heart-guard-1c49e",
    "private_key_id": "8aa1722644b52f3d8cb14b491e3f0fc82c1c7ce4",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCuaw4X03ty0MGQ\ncijJZ6n/aKwuvQ9k7NQt08bgmAp8beZHHCXdTGtFKkhIaBA+MACbF8BcDPZOixZp\nmelggAXUmxunyXHq66w9yFgI/Kxamwst45+VOsZGnv6Io4xljI/94XWXxz3CKQ1J\nmJVxhAGNtbMcxmzq4St/KXZOMnTJj05EEo4R+pDgmUh1vZ+ToBfyoHkdNuVgq8AX\n892U147YlYPGKs+mtzZGUlKvZ4J+7tX1oyz667/PNx2Xbxny65+dxF6Fw1S/W3Ji\nz8UqhisxuLX2jb/dTUr0rXLjcyqxiGfwkYXBQGeDFex1ytzKeV/b17P6UcJyPycK\nv23ARWrDAgMBAAECggEAD14dXW9jwXJalliIoXOXIIrfc4rIOsiRyqvjKlIbHRWD\nJEwlm0GqyJWjeBsQe0+NbhzXSlpWBVuZ5kS1BwH2AY0yZZkz2/1XLWZj41Qn93UR\nChez2C6CiSG5zt43djxpSiGS/oQukSyUICI9NfA/QXYl9D4YxfqASPGlRoSJkmH+\nwXNJHDzBtr0VCD0ycCFYeYmUDVniWcDcS6u3wqvUikJ9tcRAxa7zJjWGKu2uscCA\n2c+lOqmjjJUNXmsiYC05p3SMebJR1bTxs+QSeEygVNbcZXmK6MsKtDXviGBG3/NQ\n46U20nPmVD3zPbQ5dYJkC7SOVaoyvNuTb4f1Z7QfEQKBgQDy2T+KR/Eh/pDQQxx2\nr8A+jy00FJkJ68a7QpkW3Z+/eSpj5gzAPBHb9/vVEKXRW4003pKAmpk3+ceN274L\nNtAO9WVtNawjJU5yQWJA4X8V2Ksl3o5amX3ZU9khXHMwmPTKclMhkGhrbHkZi1+5\nsNngNF17RQ7VHceHy2Fp2H2nKQKBgQC33R2mCy8xdU4ofE18ane2B6HHkjuJkqIp\nLboH+RoVALvya+tY/9AguUV+eNP5bYsoi+SiDCrT0AeowtYwajm4QyHeOTko4azK\nxj4T+HBRxPfuoPaV6gGfcZmWTihAMWUwkN/OU6D2Ah4rYKqhkU1hzF3Fou2FjlqO\nMF1lvHjcCwKBgQCoso3XK36wlLxYUCZ3tEMhsig+o4hkQes9rlfWcIJGao8t8mMt\nLw1g9vVz3yqxMp32+h5fRAXnwpYDT4DHHX6OxZ19rek0SPgjmpP8aij0Lh1GI0JU\nYYfw7rRI3oYOXlK+R4jEKiK/bQz617zZq6bOftHpjeFt3k/7Xyb+ditjcQKBgHTg\nfkRav7k01GYv/iGknEx+NXzjnC0rpSGAC82dr9LCELddmtGMbAUhQOfQbw8Tb25q\n3v+TtHXIu9WvZPCJ1f8nzZOx1IAEVQ7hTfzr5JpWFzT95UIO6tEsKXG+ZR/JRoXE\n0kAaMSuw1PTGEjF6aDJO8xz7IPnRMAdK/1P4putZAoGBANi9wk47ANp7bYLPrqlc\nNGlg2lxwSznNuZCe8n2xlPl13e6gfWJDrRdZdmGu8r+cSK9m6W2RYDJp5MlZeaNY\nwIgPIXxMjbRoimiNRUB4mQHfT5Iq6V855VvDdcN39XCwKYlfmaGwnkJeQoVKxMgD\nGhusoLceLi/YnVymeqhHA6OL\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@heart-guard-1c49e.iam.gserviceaccount.com",
    "client_id": "117864630290475258569",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40heart-guard-1c49e.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  String? _accessToken;
  DateTime? _tokenExpiry;

  Future<String?> getAccessToken() async {
    try {
      // Check if we have a valid cached token
      if (_accessToken != null && 
          _tokenExpiry != null && 
          DateTime.now().isBefore(_tokenExpiry!)) {
        print('Using cached FCM access token (expires in: ${_tokenExpiry!.difference(DateTime.now()).inMinutes} minutes)');
        return _accessToken;
      }

      print('Generating new FCM access token...');

      // Generate JWT claims
      final now = DateTime.now();
      final expiry = now.add(const Duration(hours: 1));

      final claims = {
        'iss': _credentials['client_email'],
        'sub': _credentials['client_email'],
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      };

      // Create JWT
      final key = JsonWebKey.fromPem(_credentials['private_key']);
      
      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims
        ..addRecipient(key, algorithm: 'RS256');

      final jwt = builder.build().toCompactSerialization();

      // Exchange JWT for access token
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = now.add(Duration(seconds: data['expires_in']));
        
        print('New FCM access token generated successfully');
        return _accessToken;
      } else {
        print('Failed to get FCM access token: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('Error getting FCM access token: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> sendAbnormalHeartRateNotification({
    required String deviceToken,
    required double heartRate,
    required String abnormalityType,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        print('Failed to get access token');
        return false;
      }

      String title;
      String body;

      if (abnormalityType == 'high_heart_rate') {
        title = 'High Heart Rate Alert!';
        body = 'Your heart rate is high at ${heartRate.round()} BPM. Please check your condition.';
      } else if (abnormalityType == 'low_heart_rate') {
        title = 'Low Heart Rate Alert!';
        body = 'Your heart rate is low at ${heartRate.round()} BPM. Please check your condition.';
      } else {
        title = 'Abnormal Heart Rate Alert!';
        body = 'Your heart rate is abnormal at ${heartRate.round()} BPM. Please check your condition.';
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/heart-guard-1c49e/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'message': {
            'token': deviceToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'heartRate': heartRate.toString(),
              'abnormalityType': abnormalityType,
              'timestamp': DateTime.now().toIso8601String(),
            },
            'android': {
              'notification': {
                'channel_id': 'heart_guard_channel',
                'default_sound': true,
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_HIGH',
                'visibility': 'PUBLIC',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Abnormal heart rate notification sent successfully');
        return true;
      } else {
        print('Failed to send abnormal heart rate notification: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending abnormal heart rate notification: $e');
      return false;
    }
  }

  Future<bool> sendTestNotification() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        print('Failed to get access token');
        return false;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/heart-guard-1c49e/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'message': {
            'topic': 'test',
            'notification': {
              'title': 'Test Notification',
              'body': 'This is a test notification from Heart Guard',
            },
            'android': {
              'notification': {
                'channel_id': 'heart_guard_channel',
                'default_sound': true,
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_HIGH',
                'visibility': 'PUBLIC',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Test notification sent successfully');
        return true;
      } else {
        print('Failed to send test notification: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }
} 