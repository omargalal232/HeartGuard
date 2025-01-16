import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/ecg_service.dart';

class ECGRecordingScreen extends StatefulWidget {
  const ECGRecordingScreen({super.key});

  @override
  _ECGRecordingScreenState createState() => _ECGRecordingScreenState();
}

class _ECGRecordingScreenState extends State<ECGRecordingScreen> {
  bool isRecording = false;
  bool isLoading = true;
  final ECGService ecgService = ECGService();
  late final WebViewController _controller;
  static const String _ubidotsUrl = 'https://industrial.ubidots.com/app/dashboards/public/dashboard/eKw2V7QZ3aaThG6FUPWpHWwPO5LqsX-q0QpOE-RwICM?navbar=true&contextbar=false';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_ubidotsUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ECG Recording')),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildControls(),
                const SizedBox(height: 16),
                _buildStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
          label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
          onPressed: _toggleRecording,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRecording ? 'Recording in progress...' : 'Ready to record',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
    });
    if (isRecording) {
      ecgService.startRecording();
    } else {
      ecgService.stopRecording();
    }
  }
}