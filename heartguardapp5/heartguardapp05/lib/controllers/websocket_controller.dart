import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketController {
  WebSocketChannel? channel;
  bool isConnected = false;

  WebSocketChannel? connectToSocket(String ipAddress) {
    try {
      channel = IOWebSocketChannel.connect('ws://$ipAddress:81');
      isConnected = true;
      return channel;
    } catch (e) {
      isConnected = false;
      throw Exception('Failed to connect: $e');
    }
  }

  void disconnect() {
    channel?.sink.close();
    isConnected = false;
  }

  dynamic parseMessage(String message) {
    try {
      return json.decode(message);
    } catch (e) {
      throw Exception('Error parsing data: $e');
    }
  }
} 