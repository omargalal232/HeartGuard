import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../../models/sensor_data_model.dart';
import '../../services/websocket_service.dart';

/// Screen that displays real-time sensor data through WebSocket connection
class WebSocketScreen extends StatefulWidget {
  static const String routeName = '/websocket';

  const WebSocketScreen({super.key});

  @override
  State<WebSocketScreen> createState() => _WebSocketScreenState();
}

class _WebSocketScreenState extends State<WebSocketScreen> with WidgetsBindingObserver {
  final TextEditingController _ipController = TextEditingController();
  final WebSocketService _webSocketService = WebSocketService();
  final List<FlSpot> _sensorData = [];
  final String _ipAddressKey = 'last_ip_address';
  
  String _status = 'Disconnected';
  bool _isLoading = false;
  bool _autoReconnect = true;
  bool _showGrid = true;
  bool _showArea = true;
  bool _showDots = false;
  bool _isCurved = true;
  double _minY = 0;
  double _maxY = 100;
  int _timeIndex = 0;
  double _maxDataPoints = 50;

  // Statistics
  double _currentValue = 0;
  double _minValue = double.infinity;
  double _maxValue = double.negativeInfinity;
  double _avgValue = 0;
  int _totalReadings = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastIpAddress();
    _loadChartPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ipController.dispose();
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _webSocketService.disconnect();
    } else if (state == AppLifecycleState.resumed && _autoReconnect) {
      if (_ipController.text.isNotEmpty) {
        _connect();
      }
    }
  }

  /// Loads the last used IP address
  Future<void> _loadLastIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIp = prefs.getString(_ipAddressKey);
    if (lastIp != null && mounted) {
      setState(() {
        _ipController.text = lastIp;
      });
    }
  }

  /// Loads chart preferences
  Future<void> _loadChartPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showGrid = prefs.getBool('show_grid') ?? true;
      _showArea = prefs.getBool('show_area') ?? true;
      _showDots = prefs.getBool('show_dots') ?? false;
      _isCurved = prefs.getBool('is_curved') ?? true;
      _maxDataPoints = prefs.getDouble('max_data_points') ?? 50;
    });
  }

  /// Saves chart preferences
  Future<void> _saveChartPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_grid', _showGrid);
    await prefs.setBool('show_area', _showArea);
    await prefs.setBool('show_dots', _showDots);
    await prefs.setBool('is_curved', _isCurved);
    await prefs.setDouble('max_data_points', _maxDataPoints);
  }

  /// Saves the IP address
  Future<void> _saveIpAddress(String ipAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipAddressKey, ipAddress);
  }

  /// Connects to the WebSocket server
  Future<void> _connect() async {
    final ipAddress = _ipController.text.trim();
    if (ipAddress.isEmpty) {
      _showError('Please enter a valid IP address');
      return;
    }

    if (!_isValidIpAddress(ipAddress)) {
      _showError('Please enter a valid IP address format (e.g., 192.168.1.100)');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      await _webSocketService.connect(ipAddress);
      await _saveIpAddress(ipAddress);
      _listenToSensorData();
      
      setState(() {
        _status = 'Connected to $ipAddress';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to connect: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Validates IP address format
  bool _isValidIpAddress(String ipAddress) {
    final regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    );
    return regex.hasMatch(ipAddress);
  }

  /// Listens to incoming sensor data
  void _listenToSensorData() {
    _webSocketService.dataStream.listen(
      (data) => _updateChartData(data),
      onError: (error) => setState(() {
        _status = 'Error: ${error.toString()}';
      }),
    );
  }

  /// Updates the chart with new sensor data
  void _updateChartData(SensorDataModel data) {
    setState(() {
      if (_sensorData.length > _maxDataPoints) {
        _sensorData.removeAt(0);
      }
      
      _sensorData.add(FlSpot(_timeIndex.toDouble(), data.value));
      _timeIndex++;

      // Update statistics
      _currentValue = data.value;
      _minValue = math.min(_minValue, data.value);
      _maxValue = math.max(_maxValue, data.value);
      _totalReadings++;
      _avgValue = (_avgValue * (_totalReadings - 1) + data.value) / _totalReadings;

      if (_sensorData.length > 1) {
        _minY = _sensorData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 10;
        _maxY = _sensorData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 10;
      }

      _status = 'Latest reading: ${data.value.toStringAsFixed(2)}';
    });
  }

  /// Shows error message to user
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Shows chart settings dialog
  Future<void> _showChartSettings() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chart Settings'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Show Grid'),
                value: _showGrid,
                onChanged: (value) => setState(() => _showGrid = value),
              ),
              SwitchListTile(
                title: const Text('Show Area'),
                value: _showArea,
                onChanged: (value) => setState(() => _showArea = value),
              ),
              SwitchListTile(
                title: const Text('Show Data Points'),
                value: _showDots,
                onChanged: (value) => setState(() => _showDots = value),
              ),
              SwitchListTile(
                title: const Text('Smooth Curve'),
                value: _isCurved,
                onChanged: (value) => setState(() => _isCurved = value),
              ),
              ListTile(
                title: const Text('Data Points'),
                subtitle: Slider(
                  value: _maxDataPoints,
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: _maxDataPoints.toStringAsFixed(0),
                  onChanged: (value) => setState(() => _maxDataPoints = value),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _saveChartPreferences();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Shows statistics dialog
  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensor Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Current Value'),
              trailing: Text(_currentValue.toStringAsFixed(2)),
            ),
            ListTile(
              title: const Text('Minimum Value'),
              trailing: Text(_minValue == double.infinity ? 'N/A' : _minValue.toStringAsFixed(2)),
            ),
            ListTile(
              title: const Text('Maximum Value'),
              trailing: Text(_maxValue == double.negativeInfinity ? 'N/A' : _maxValue.toStringAsFixed(2)),
            ),
            ListTile(
              title: const Text('Average Value'),
              trailing: Text(_avgValue.toStringAsFixed(2)),
            ),
            ListTile(
              title: const Text('Total Readings'),
              trailing: Text(_totalReadings.toString()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Monitor'),
        actions: [
          if (_webSocketService.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _connect,
              tooltip: 'Reconnect',
            ),
          IconButton(
            icon: Icon(_autoReconnect ? Icons.sync : Icons.sync_disabled),
            onPressed: () => setState(() => _autoReconnect = !_autoReconnect),
            tooltip: _autoReconnect ? 'Auto-reconnect enabled' : 'Auto-reconnect disabled',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showStatistics,
            tooltip: 'Show Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showChartSettings,
            tooltip: 'Chart Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'ESP32 IP Address',
                  hintText: 'e.g., 192.168.1.100',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _webSocketService.isConnected 
                        ? Icons.link 
                        : Icons.link_off,
                      color: _webSocketService.isConnected 
                        ? Colors.green 
                        : Colors.red,
                    ),
                    onPressed: _webSocketService.isConnected 
                      ? _webSocketService.disconnect 
                      : _connect,
                  ),
                ),
                enabled: !_isLoading,
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _webSocketService.isConnected 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _sensorData.isNotEmpty
                    ? LineChart(
                        LineChartData(
                          minX: _sensorData.first.x,
                          maxX: _sensorData.last.x,
                          minY: _minY,
                          maxY: _maxY,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          gridData: FlGridData(show: _showGrid),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _sensorData,
                              isCurved: _isCurved,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 2,
                              dotData: FlDotData(show: _showDots),
                              belowBarData: BarAreaData(
                                show: _showArea,
                                color: Theme.of(context).colorScheme.primary
                                  .withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sensor data available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            if (!_webSocketService.isConnected) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Connect to start monitoring',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
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