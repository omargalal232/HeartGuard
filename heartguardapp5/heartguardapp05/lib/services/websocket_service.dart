import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data_model.dart';

/// Service for managing WebSocket connections and sensor data
class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final _messageController = StreamController<SensorDataModel>.broadcast();

  /// Stream of sensor data
  Stream<SensorDataModel> get dataStream => _messageController.stream;

  /// Whether the WebSocket is currently connected
  bool get isConnected => _isConnected;

  /// Connects to a WebSocket server
  /// 
  /// Throws [WebSocketException] if connection fails
  Future<void> connect(String ipAddress) async {
    try {
      // Close existing connection if any
      await disconnect();

      // Create new connection
      final uri = Uri.parse('ws://$ipAddress:81');
      _channel = IOWebSocketChannel.connect(uri);
      _isConnected = true;

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  /// Disconnects from the WebSocket server
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// Handles incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      if (message is! String) {
        throw const FormatException('Message must be a string');
      }

      final data = json.decode(message) as Map<String, dynamic>;
      if (!data.containsKey('sensor')) {
        throw const FormatException('Message missing sensor data');
      }

      final value = double.tryParse(data['sensor'].toString());
      if (value == null) {
        throw const FormatException('Invalid sensor value');
      }

      _messageController.add(SensorDataModel(
        value: value,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _handleError(e.toString());
    }
  }

  /// Handles WebSocket errors
  void _handleError(Object error) {
    _isConnected = false;
    _messageController.addError(error);
  }

  /// Handles WebSocket connection closure
  void _handleDone() {
    _isConnected = false;
    disconnect();
  }

  /// Disposes of the service
  void dispose() {
    disconnect();
    _messageController.close();
  }
} 