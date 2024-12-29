import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String _broker = 'industrial.api.ubidots.com';
  final String _token = 'BBUS-dotPnGDytYSjPQNBGKs68MztvEV1uD'; // Replace with your Ubidots token
  final String _clientId = 'alexnewton'; // Unique client ID
  late MqttServerClient _client;

  // Define a callback for received messages
  Function(String)? onMessageReceived;

  MqttService() {
    _client = MqttServerClient(_broker, _clientId);
    _client.port = 1883;
    _client.onDisconnected = onDisconnected; // Ensure onDisconnected is defined
    _client.onConnected = onConnected; // Ensure onConnected is defined
  }

  void onConnected() {
    print('Connected to MQTT broker');
  }

  void onDisconnected() {
    print('Disconnected from MQTT broker');
  }

  Future<void> connect() async {
    try {
      await _client.connect(_clientId, _token);
      print('Connected to MQTT broker');
      _client.subscribe('/v1.6/devices/YOUR_DEVICE_LABEL', MqttQos.atMostOnce); // Replace with your device label
      _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String message =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('Received message: $message');

        // Call the callback if it's set
        if (onMessageReceived != null) {
          onMessageReceived!(message);
        }
      });
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  void disconnect() {
    _client.disconnect();
  }
} 