import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../controllers/file_upload_controller.dart'; // Adjust this path based on your project structure.

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final FileUploadController _controller = FileUploadController();
  String _statusMessage = "No file uploaded yet.";
  String? _filePath;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowedExtensions: ['mp3'], // Only allow .mp3 files
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
        _statusMessage = "File selected: ${result.files.single.name}";
      });
    } else {
      setState(() {
        _statusMessage = "No file selected.";
      });
    }
  }

  void _uploadFile() async {
    if (_filePath != null) {
      setState(() {
        _statusMessage = "Uploading file...";
      });

      final response = await _controller.uploadFile(_filePath!);

      setState(() {
        _statusMessage = response;
      });
    } else {
      setState(() {
        _statusMessage = "Please select a file first.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Heart Sound'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Pick File'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _uploadFile,
                child: const Text('Upload File'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
