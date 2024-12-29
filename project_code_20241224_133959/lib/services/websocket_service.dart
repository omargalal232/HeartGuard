import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/recording_model.dart';

class WebSocketService {
  late WebSocketChannel _channel;
  final StreamController<RecordingModel> _recordingController = StreamController<RecordingModel>();

  /// Stream to emit Recording Models
  Stream<RecordingModel> get recordingStream => _recordingController.stream;

  /// Connect to the WebSocket echo service
  void connect() {
    String url = 'wss://echo.websocket.events'; // Using the public WebSocket echo service
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel.stream.listen((data) {
      try {
        // Assuming data is JSON with ECG details
        final Map<String, dynamic> jsonData = json.decode(data);
        final recording = RecordingModel.fromMap(jsonData, jsonData['recordingId']);
        _recordingController.add(recording);
      } catch (e) {
        _recordingController.addError('Invalid ECG data received');
      }
    }, onError: (error) {
      _recordingController.addError('WebSocket Error: $error');
      // Optionally implement reconnection logic here
    }, onDone: () {
      _recordingController.close();
    });
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _channel.sink.close();
    _recordingController.close();
  }
}