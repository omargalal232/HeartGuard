class HeartSoundRecording {
  final String id;
  final String filePath;
  final Duration duration;
  final DateTime timestamp;
  final String source; // 'external' or 'microphone'
  final double? heartRate; // Optional: detected heart rate

  HeartSoundRecording({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.timestamp,
    required this.source,
    this.heartRate,
  });

  // Add fromMap and toMap methods if needed for persistence
} 