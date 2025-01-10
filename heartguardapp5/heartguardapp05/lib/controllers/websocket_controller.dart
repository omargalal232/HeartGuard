import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketController {
  WebSocketChannel? channel;
  bool isConnected = false;
  Timer? _reconnectTimer;
  final _connectionTimeout = const Duration(seconds: 5);
  final _reconnectDelay = const Duration(seconds: 3);
  StreamController<String>? _statusController;
  
  Stream<String> get connectionStatus => _statusController!.stream;

  WebSocketController() {
    _statusController = StreamController<String>.broadcast();
  }

  /// Connect to the WebSocket server
  Future<void> connectToSocket(String ipAddress) async {
    if (channel != null) {
      await disconnect();
    }

    try {
      // Test TCP connection first
      final socket = await Socket.connect(ipAddress, 81, timeout: _connectionTimeout);
      socket.destroy();

      // Create WebSocket connection
      final String url = 'ws://$ipAddress:81';
      channel = IOWebSocketChannel.connect(
        url,
        connectTimeout: _connectionTimeout,
        pingInterval: const Duration(seconds: 10),
      );
      
      isConnected = true;
      _statusController?.add('Connected to $ipAddress');
      print('Connected to $url');
      return;
    } on SocketException catch (e) {
      isConnected = false;
      _statusController?.add('Connection failed: Device not reachable');
      throw SocketException('Failed to connect: ${e.message}');
    } catch (e) {
      isConnected = false;
      _statusController?.add('Connection error: ${e.toString()}');
      throw Exception('Failed to connect: $e');
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await channel?.sink.close();
    channel = null;
    isConnected = false;
    _statusController?.add('Disconnected');
    print('Disconnected from WebSocket');
  }

  /// Listen to messages from the WebSocket server
  void listenToMessages(Function(Map<String, dynamic>) onMessageReceived) {
    if (channel == null) {
      throw Exception('WebSocket is not connected.');
    }

    channel!.stream.listen(
      (message) {
        try {
          // Parse the incoming JSON message
          if (message is! String) {
            throw FormatException('Expected string message, got ${message.runtimeType}');
          }
          
          final Map<String, dynamic> parsedMessage = json.decode(message) as Map<String, dynamic>;
          print('Message received: $parsedMessage');
          onMessageReceived(parsedMessage);
        } catch (e) {
          print('Error parsing message: $e');
          _statusController?.add('Error parsing message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _statusController?.add('Connection error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('WebSocket connection closed.');
        _statusController?.add('Connection closed');
        _handleConnectionError();
      },
      cancelOnError: false,
    );
  }

  /// Handle connection errors and attempt reconnection
  void _handleConnectionError() {
    isConnected = false;
    
    // Attempt to reconnect after delay
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!isConnected && channel != null) {
        _statusController?.add('Attempting to reconnect...');
        final String? currentUrl = channel?.sink.toString().split(' ').last;
        if (currentUrl != null) {
          final String ipAddress = currentUrl.replaceAll('ws://', '').split(':')[0];
          connectToSocket(ipAddress);
        }
      }
    });
  }

  /// Send a message to the WebSocket server
  void sendMessage(Map<String, dynamic> message) {
    if (channel == null || !isConnected) {
      throw Exception('WebSocket is not connected.');
    }

    try {
      final String jsonMessage = json.encode(message);
      channel!.sink.add(jsonMessage);
      print('Message sent: $jsonMessage');
    } catch (e) {
      print('Error sending message: $e');
      _statusController?.add('Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Dispose of the controller
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    _statusController?.close();
  }
}
