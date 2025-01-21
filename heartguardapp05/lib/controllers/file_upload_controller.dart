import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // Import Dart's IO library to handle file operations

class FileUploadController {
  // Function to run the local Python script
  Future<String> runPythonScript(String filePath) async {
    try {
      // Get the path to the Python executable
      String pythonPath = 'python'; // For some systems, it might be 'python3'

      // Get the path to the script (make sure it's located correctly)
      String scriptPath = 'assets/python/demo(sound detection).py';

      // Run the Python script with the audio file as an argument
      final result = await Process.run(
        pythonPath,
        [
          scriptPath,
          filePath
        ], // Pass the file path as an argument to the script
      );

      // Capture the output from the script
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      } else {
        return "Error: ${result.stderr}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  // Function to handle file selection and upload
  Future<String> uploadFileFromBytes(PlatformFile file) async {
    try {
      // Get the path to the temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.name}');

      // Write the selected file's bytes to the temp file
      await tempFile.writeAsBytes(file.bytes!);

      // Run the Python script on the selected file and get the result
      String result = await runPythonScript(tempFile.path);
      return result;
    } catch (e) {
      return "Error: $e";
    }
  }
}
