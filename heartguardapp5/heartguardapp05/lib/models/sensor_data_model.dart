/// Model class representing sensor data with value and timestamp
class SensorDataModel {
  final double value;
  final DateTime timestamp;

  const SensorDataModel({
    required this.value,
    required this.timestamp,
  });

  factory SensorDataModel.fromMap(Map<String, dynamic> map) {
    return SensorDataModel(
      value: double.parse(map['sensor'].toString()),
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sensor': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
} 