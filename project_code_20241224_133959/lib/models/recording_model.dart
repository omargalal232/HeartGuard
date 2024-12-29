class RecordingModel {
  final String userId;
  final String recordingId;
  final String ecgData;
  final DateTime timestamp;
  final String status;

  RecordingModel({
    required this.userId,
    required this.recordingId,
    required this.ecgData,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ecgData': ecgData,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory RecordingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RecordingModel(
      userId: map['userId'],
      recordingId: documentId,
      ecgData: map['ecgData'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
    );
  }
}