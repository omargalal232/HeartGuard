import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data_model.dart';

/// Service for managing WebSocket connections and sensor data
class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  final _messageController = StreamController<SensorDataModel>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  static const _connectionTimeout = Duration(seconds: 10);
  static const _reconnectDelay = Duration(seconds: 3);
  static const _pingInterval = Duration(seconds: 30);
  
  String? _lastConnectedIp;
  bool _isReconnecting = false;

  /// Stream of sensor data
  Stream<SensorDataModel> get dataStream => _messageController.stream;

  /// Stream of connection status updates
  Stream<String> get connectionStatus => _statusController.stream;

  /// Whether the WebSocket is currently connected
  bool get isConnected => _isConnected;

  /// Connects to a WebSocket server
  Future<void> connect(String ipAddress) async {
    if (_isReconnecting) return;
    
    _lastConnectedIp = ipAddress;
    await _cleanupConnection();

    try {
      _statusController.add('Testing connection...');
      
      // Test TCP connection first
      final socket = await Socket.connect(
        ipAddress, 
        81,  // ESP32 WebSocket port
        timeout: _connectionTimeout
      ).catchError((e) {
        throw SocketException('Failed to establish TCP connection: ${e.message}');
      });
      
      await socket.close();
      
      _statusController.add('Establishing WebSocket connection...');
      
      // ESP32 WebSocket URL format
      final uri = Uri.parse('ws://$ipAddress:81');
      
      // Create WebSocket connection with proper configuration
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: _pingInterval,
        connectTimeout: _connectionTimeout,
      );
      
      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Setup message handling
      _setupConnectionMonitoring();
      
      _isConnected = true;
      _statusController.add('Connected to $ipAddress');
      
      // Start ping timer
      _startPingTimer();
      
    } on SocketException catch (e) {
      _isConnected = false;
      _statusController.add('Connection failed: Device not reachable');
      throw SocketException('Failed to connect to $ipAddress: ${e.message}');
    } on TimeoutException {
      _isConnected = false;
      _statusController.add('Connection failed: Timeout');
      throw TimeoutException('Failed to connect to $ipAddress: Connection timed out');
    } catch (e) {
      _isConnected = false;
      _statusController.add('Connection error: ${e.toString()}');
      rethrow;
    }
  }

  /// Sets up WebSocket connection monitoring
  void _setupConnectionMonitoring() {
    _channel?.stream.listen(
      (dynamic message) {
        try {
          _handleMessage(message);
        } catch (e) {
          print('Error handling message: $e');
        }
      },
      onError: (Object error) {
        print('WebSocket error: $error');
        _statusController.add('Connection error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('WebSocket connection closed');
        _statusController.add('Connection closed');
        _handleConnectionError();
      },
      cancelOnError: false,
    );
  }

  /// Handles incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      print('Received raw message: $message'); // Debug log
      
      if (message == 'pong' || message == '') return;
      
      if (message is! String) {
        throw const FormatException('Message must be a string');
      }

      final data = json.decode(message) as Map<String, dynamic>;
      
      // Try different possible data formats
      double? value;
      if (data.containsKey('heartRate')) {
        value = double.tryParse(data['heartRate'].toString());
      } else if (data.containsKey('value')) {
        value = double.tryParse(data['value'].toString());
      } else if (data.containsKey('data')) {
        value = double.tryParse(data['data'].toString());
      }

      if (value == null) {
        throw const FormatException('Invalid or missing sensor value');
      }

      _messageController.add(SensorDataModel(
        value: value,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('Error processing message: $e'); // Debug log
      _statusController.add('Error processing message: ${e.toString()}');
    }
  }

  /// Starts the ping timer
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (e) {
          print('Error sending ping: $e');
          _handleConnectionError();
        }
      }
    });
  }

  /// Handles connection errors and attempts reconnection
  void _handleConnectionError() {
    if (!_isConnected) return;
    
    _isConnected = false;
    _cleanupConnection();
    
    if (_lastConnectedIp != null) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () async {
        if (!_isConnected && !_isReconnecting) {
          _isReconnecting = true;
          _statusController.add('Attempting to reconnect...');
          try {
            await connect(_lastConnectedIp!);
          } catch (e) {
            _statusController.add('Reconnection failed: ${e.toString()}');
          } finally {
            _isReconnecting = false;
          }
        }
      });
    }
  }

  /// Cleans up the current connection
  Future<void> _cleanupConnection() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// Disconnects from the WebSocket server
  Future<void> disconnect() async {
    _lastConnectedIp = null; // Prevent auto-reconnect
    await _cleanupConnection();
    _statusController.add('Disconnected');
  }

  /// Disposes of the service
  void dispose() {
    _cleanupConnection();
    _messageController.close();
    _statusController.close();
  }
} 