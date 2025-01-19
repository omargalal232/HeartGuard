import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'monitoring_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import '../../controllers/file_upload_controller.dart'; // Adjust this path based on your project structure.

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({Key? key}) : super(key: key);

  @override
  State createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final FileUploadController _controller = FileUploadController();
  String _statusMessage = "No file uploaded yet.";
  String? _filePath;
  int _selectedIndex =
      4; // Assuming 'Heart Sound' is the 5th item in the navbar

  // List of screens to navigate to
  final List<Widget> _screens = [
    const MonitoringScreen(),
    const NotificationScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
    const FileUploadScreen(), // Add FileUploadScreen here
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
        title: _selectedIndex == 4
            ? const Text('Upload Heart Sound')
            : const Text('Upload Heart Sound'),
      ),
      body: _selectedIndex == 4
        ?  Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: _pickFile,
                    child: const Text('Pick File'),
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: _uploadFile,
                    child: const Text('Upload File'),
                  ),
                ],
              ),
            ),
          )
          : _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speaker),
            label: 'Heart Sound',
          ),
        ],
      ),
    );
  }
}
