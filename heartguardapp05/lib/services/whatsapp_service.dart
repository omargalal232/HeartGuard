// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class WhatsAppService {
//   static const String apiUrl = 'https://messages-sandbox.nexmo.com/v1/messages';
//   static const String apiKey = '2e27d987'; // Replace with your actual API key
//   static const String apiSecret = '2e27d987'; // Replace with your actual API secret

//   static Future<void> sendWhatsAppMessage(String toNumber) async {
//     final String basicAuth =
//         'Basic ' + base64Encode(utf8.encode('$apiKey:$apiSecret'));

//     final response = await http.post(
//       Uri.parse(apiUrl),
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': basicAuth,
//       },
//       body: jsonEncode({
//         "from": "14157386102", // Your Nexmo number
//         "to": "01281760571", // The recipient's number
//         "message_type": "text",
//         "text": "This is a WhatsApp Message sent from the Messages API",
//         "channel": "whatsapp"
//       }),
//     );

//     if (response.statusCode == 202) {
//       print('Message sent successfully');
//     } else {
//       print('Failed to send message: ${response.body}');
//     }
//   }
// }
