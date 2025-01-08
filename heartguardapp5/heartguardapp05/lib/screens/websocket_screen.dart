import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON parsing
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart'; // For Line Chart

class WebSocketScreen extends StatefulWidget {
  static const String routeName = '/websocket';

  @override
  _WebSocketScreenState createState() => _WebSocketScreenState();
}

class _WebSocketScreenState extends State<WebSocketScreen> {
  final TextEditingController ipController = TextEditingController();
  WebSocketChannel? channel;
  String sensorValue = "No data received yet.";
  bool isConnected = false;
  List<FlSpot> sensorData = []; // List to hold chart data
  int time = 0; // Time counter for X-axis
  double minY = 0; // Minimum value for the Y-axis
  double maxY = 100; // Maximum value for the Y-axis

  void connectToSocket(String ipAddress) {
    try {
      // Initialize WebSocket connection
      setState(() {
        channel = IOWebSocketChannel.connect('ws://$ipAddress:81');
        isConnected = true;
        sensorValue = "Connected to $ipAddress";
      });

      channel!.stream.listen((message) {
        setState(() {
          // Parse the received JSON
          try {
            final data = json.decode(message); // Decode JSON
            if (data.containsKey('sensor')) {
              final double value = double.parse(data['sensor'].toString());
              sensorValue = "Sensor Value: $value";

              // Update chart data
              if (sensorData.length > 50) {
                sensorData.removeAt(0); // Keep only last 50 data points
              }
              sensorData.add(FlSpot(time.toDouble(), value));
              time++; // Increment time for X-axis

              // Dynamically update the Y-axis bounds
              minY = sensorData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 10;
              maxY = sensorData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 10;
            } else {
              sensorValue = "Unexpected data: $message";
            }
          } catch (e) {
            sensorValue = "Error parsing data: $message";
            print("Parsing error: $e");
          }
        });
      }, onError: (error) {
        setState(() {
          sensorValue = "Connection error: $error";
          isConnected = false;
          print("WebSocket error: $error");
        });
      }, onDone: () {
        setState(() {
          sensorValue = "Connection closed.";
          isConnected = false;
        });
      });
    } catch (e) {
      setState(() {
        sensorValue = "Failed to connect: $e";
        isConnected = false;
      });
      print("Connection exception: $e");
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32 WebSocket'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: screenSize.height * 0.02
          ),
          child: Column(
            children: [
              SizedBox(
                width: screenSize.width * 0.9,
                child: TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    labelText: "ESP32 IP Address",
                    hintText: "e.g., 192.168.1.100",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              SizedBox(
                width: screenSize.width * 0.4,
                child: ElevatedButton(
                  onPressed: () {
                    final ipAddress = ipController.text.trim();
                    if (ipAddress.isNotEmpty) {
                      connectToSocket(ipAddress);
                    } else {
                      setState(() {
                        sensorValue = "Please enter a valid IP address.";
                      });
                    }
                  },
                  child: Text(isConnected ? "Reconnect" : "Connect"),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              Text(
                "Connection Status: ${isConnected ? "Connected" : "Disconnected"}",
                style: TextStyle(
                  fontSize: screenSize.width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              Text(
                sensorValue,
                style: TextStyle(
                  fontSize: screenSize.width * 0.05,
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenSize.height * 0.02),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(screenSize.width * 0.02),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: sensorData.isNotEmpty
                      ? LineChart(
                          LineChartData(
                            minX: sensorData.first.x,
                            maxX: sensorData.last.x,
                            minY: minY,
                            maxY: maxY,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: screenSize.width * 0.08,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: screenSize.height * 0.04,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            gridData: FlGridData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: sensorData,
                                isCurved: false,
                                color: Colors.blue,
                                barWidth: screenSize.width * 0.005,
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Text(
                            "Waiting for sensor data...",
                            style: TextStyle(fontSize: screenSize.width * 0.04),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
