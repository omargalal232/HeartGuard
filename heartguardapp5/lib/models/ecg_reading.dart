// lib/models/ecg_reading.dart

class EcgReading {
  final String? id; // مفتاح Firebase push ID
  final double? bpm;
  final double? rawValue; // الحقل الموجود في Firebase هو 'raw_value'
  final double? average;
  final int? maxInPeriod; // الحقل الموجود في Firebase هو 'max_in_period'
  // قد يكون ال timestamp `.sv` الذي هو ServerValue.timestamp.
  // سنتركه كـ Object في البداية لمعالجته لاحقًا إذا لزم الأمر
  final Object? timestamp;
  final String? userEmail; // الحقل الموجود في Firebase هو 'user_email'
  final List<double>? values; // قائمة بقيم ECG المتتابعة إذا كانت متوفرة

  EcgReading({
    this.id,
    this.bpm,
    this.rawValue,
    this.average,
    this.maxInPeriod,
    this.timestamp,
    this.userEmail,
    this.values,
  });

  factory EcgReading.fromMap(Map<String, dynamic> map) {
    // Handle raw_value and convert to values list if values is not provided
    List<double>? valuesList;
    if (map['values'] != null) {
      if (map['values'] is List) {
        valuesList = (map['values'] as List)
            .map((value) => (value is num) ? value.toDouble() : 0.0)
            .toList();
      } else if (map['values'] is Map) {
        final valuesMap = map['values'] as Map;
        valuesList = valuesMap.values
            .map((value) => (value is num) ? value.toDouble() : 0.0)
            .toList();
      }
    } else if (map['raw_value'] != null) {
      // If no values list but raw_value exists, create a single-point list
      valuesList = [(map['raw_value'] as num).toDouble()];
    }

    // Ensure BPM is within reasonable range
    double? processedBpm;
    if (map['bpm'] != null) {
      final bpmValue = (map['bpm'] as num).toDouble();
      if (bpmValue >= 30 && bpmValue <= 250) { // Reasonable heart rate range
        processedBpm = bpmValue;
      }
    }

    return EcgReading(
      id: map['id'] as String?,
      bpm: processedBpm,
      rawValue: (map['raw_value'] as num?)?.toDouble(),
      average: (map['average'] as num?)?.toDouble(),
      maxInPeriod: (map['max_in_period'] as num?)?.toInt(),
      timestamp: map['timestamp'],
      userEmail: map['user_email'] as String?,
      values: valuesList,
    );
  }

  bool get hasValidData {
    return values != null && values!.isNotEmpty || rawValue != null;
  }

  DateTime? get dateTime {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    } else if (timestamp is String && timestamp != '.sv') {
      // Try to parse string timestamp
      return DateTime.tryParse(timestamp as String);
    }
    return null;
  }

  @override
  String toString() {
    return 'EcgReading(id: $id, bpm: $bpm, rawValue: $rawValue, average: $average, maxInPeriod: $maxInPeriod, timestamp: $timestamp, userEmail: $userEmail, values: ${values?.length ?? 0} points)';
  }
} 