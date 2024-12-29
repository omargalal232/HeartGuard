import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../models/recording_model.dart';
import '../services/ubidots_service.dart';

class ECGMonitoringScreen extends StatefulWidget {
  const ECGMonitoringScreen({super.key});

  @override
  _ECGMonitoringScreenState createState() => _ECGMonitoringScreenState();
}

class _ECGMonitoringScreenState extends State<ECGMonitoringScreen> {
  late WebSocketService _webSocketService;
  late UbidotsService _ubidotsService;
  StreamSubscription<RecordingModel>? _subscription;
  List<String> _ecgData = [];

  @override
  void initState() {
    super.initState();
    _webSocketService = Provider.of<WebSocketService>(context, listen: false);
    _ubidotsService = UbidotsService();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    _webSocketService.connect();
    _subscription = _webSocketService.recordingStream.listen((recording) {
      // Assuming recording contains ECG data as a string
      setState(() {
        _ecgData.add(recording.toString()); // Adjust this based on your data structure
      });

      // Send ECG data to Ubidots
      _ubidotsService.sendData(recording.ecgData as double); // Assuming recording has a property `ecgData`
    }, onError: (error) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Cancel the subscription when disposing
    _webSocketService.disconnect(); // Disconnect the WebSocket
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Monitoring'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _ecgData.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('ECG Data: ${_ecgData[index]}'),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Optionally, you can add functionality to clear the data
                setState(() {
                  _ecgData.clear();
                });
              },
              child: const Text('Clear Data'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/results'); // Navigate to ECG results screen
              },
              child: const Text('View ECG Results'),
            ),
          ],
        ),
      ),
    );
  }
} 