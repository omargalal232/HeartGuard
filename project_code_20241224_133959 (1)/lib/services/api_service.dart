// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class ApiService {
//   final String baseUrl = 'https://yourapi.com'; // Replace with your API URL

//   Future<void> login(String email, String password) async {
//     final response = await http.post(
//       Uri.parse('$baseUrl/login'),
//       body: jsonEncode({'email': email, 'password': password}),
//       headers: {'Content-Type': 'application/json'},
//     );

//     if (response.statusCode == 200) {
//       // Handle successful login
//     } else {
//       // Handle error
//     }
//   }

//   Future<List<ECGRecord>> fetchECGRecords() async {
//     final response = await http.get(Uri.parse('$baseUrl/ecg_records'));

//     if (response.statusCode == 200) {
//       List<dynamic> data = jsonDecode(response.body);
//       return data.map((record) => ECGRecord(
//         timestamp: DateTime.parse(record['timestamp']),
//         data: List<double>.from(record['data']),
//       )).toList();
//     } else {
//       throw Exception('Failed to load ECG records');
//     }
//   }

//   Future<List<Alert>> fetchAlerts() async {
//     final response = await http.get(Uri.parse('$baseUrl/alerts'));

//     if (response.statusCode == 200) {
//       List<dynamic> data = jsonDecode(response.body);
//       return data.map((alert) => Alert(
//         message: alert['message'],
//         timestamp: DateTime.parse(alert['timestamp']),
//         isCritical: alert['isCritical'],
//       )).toList();
//     } else {
//       throw Exception('Failed to load alerts');
//     }
//   }
// }