import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';

class ECGResultsScreen extends StatefulWidget {
  const ECGResultsScreen({super.key});

  @override
  _ECGResultsScreenState createState() => _ECGResultsScreenState();
}

class _ECGResultsScreenState extends State<ECGResultsScreen> {
  late MqttService _mqttService;
  List<String> _ecgData = []; // List to store received ECG data

  @override
  void initState() {
    super.initState();
    _mqttService = MqttService();
    _mqttService.connect();
    _mqttService.onMessageReceived = (String message) {
      setState(() {
        _ecgData.add(message); // Add the received message to the list
      });
    };
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Results'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _ecgData.isEmpty
            ? const Center(child: Text('No ECG data received yet.'))
            : ListView.builder(
                itemCount: _ecgData.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('ECG Value: ${_ecgData[index]}'),
                  );
                },
              ),
      ),
    );
  }
} 