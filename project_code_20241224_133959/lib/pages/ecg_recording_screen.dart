import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ecg_service.dart';
import '../services/websocket_service.dart';
import '../services/firestore_service.dart';
import '../models/recording_model.dart';

class ECGRecordingScreen extends StatefulWidget {
  const ECGRecordingScreen({super.key});

  @override
  _ECGRecordingScreenState createState() => _ECGRecordingScreenState();
}

class _ECGRecordingScreenState extends State<ECGRecordingScreen> {
  bool isRecording = false;
  late WebSocketService _webSocketService;
  StreamSubscription<RecordingModel>? _subscription;

  @override
  void initState() {
    super.initState();
    _webSocketService = Provider.of<WebSocketService>(context, listen: false);
  }

  void toggleRecording() {
    setState(() {
      isRecording = !isRecording;
    });
    if (isRecording) {
      _webSocketService.connect();
      _subscription = _webSocketService.recordingStream.listen((recording) {
        // Handle incoming recording data
        Provider.of<FirestoreService>(context, listen: false).addRecording(recording);
      }, onError: (error) {
        // Handle errors
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      });
    } else {
      _subscription?.cancel();
      _webSocketService.disconnect();
    }
  }

  @override
  void dispose() {
    if (isRecording) {
      _subscription?.cancel();
      _webSocketService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Optionally, display real-time ECG data or status
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Recording'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: toggleRecording,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isRecording ? 'Stop Recording' : 'Start Recording',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/monitoring');
              },
              child: const Text('Open ECG Monitoring'),
            ),
          ],
        ),
      ),
    );
  }
}