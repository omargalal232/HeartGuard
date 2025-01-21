import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../controllers/file_upload_controller.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({Key? key}) : super(key: key);

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final FileUploadController _controller = FileUploadController();
  String _statusMessage = "No file uploaded yet.";
  PlatformFile? _selectedFile;

  // Function to pick an audio file
  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result != null && result.files.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedFile = result.files.single;
            _statusMessage = "File selected: ${_selectedFile!.name}";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = "No file selected.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error selecting file: $e";
        });
      }
    }
  }

  // Function to upload the selected file
  void _uploadFile() async {
    if (_selectedFile != null) {
      if (mounted) {
        setState(() {
          _statusMessage = "Uploading file...";
        });
      }

      final response = await _controller.uploadFileFromBytes(
        _selectedFile!.bytes!,
        _selectedFile!.name,
      );

      if (mounted) {
        setState(() {
          _statusMessage = response;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _statusMessage = "Please select a file first.";
        });
      }
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
