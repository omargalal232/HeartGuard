class AlertModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;

  AlertModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  // Method to convert AlertModel to a Map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Factory constructor to create AlertModel from a Map
  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}