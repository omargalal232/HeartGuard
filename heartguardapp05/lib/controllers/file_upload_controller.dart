import 'dart:convert';
import 'package:http/http.dart' as http;

class FileUploadController {
  final String serverUrl = "http://127.0.0.1:5000/predict"; // Update with your server URL

  Future<String> uploadFile(String filePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        return jsonResponse['result'] ?? 'No response';
      } else {
        return "Failed to upload file. Status code: ${response.statusCode}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
