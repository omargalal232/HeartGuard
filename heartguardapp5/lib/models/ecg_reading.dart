// lib/models/ecg_reading.dart

import 'package:logger/logger.dart';

class EcgReading {
  final String? id; // Firebase push ID
  final double? bpm;
  final double? rawValue; // 'raw_value' in Firebase
  final double? average;
  final int? maxInPeriod; // 'max_in_period' in Firebase
  final Object? timestamp;
  final String? userEmail; // 'user_email' in Firebase
  final List<double>? values; // ECG values sequence if available

  static final Logger _logger = Logger();

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
    try {
      // Alternative fields that might be used for the same data
      Map<String, dynamic> normalizedMap = Map.from(map);
      
      // Normalize different possible field names
      normalizedMap['id'] ??= map['reading_id'] ?? map['key'] ?? map['_id'];
      normalizedMap['bpm'] ??= map['heart_rate'] ?? map['heartRate'] ?? map['pulse'];
      normalizedMap['raw_value'] ??= map['rawValue'] ?? map['raw'] ?? map['value'];
      normalizedMap['average'] ??= map['avg'] ?? map['mean'];
      normalizedMap['max_in_period'] ??= map['maxInPeriod'] ?? map['max'];
      normalizedMap['timestamp'] ??= map['time'] ?? map['date'] ?? map['created_at'] ?? map['createdAt'];
      normalizedMap['user_email'] ??= map['userEmail'] ?? map['email'] ?? map['user'];
      normalizedMap['values'] ??= map['data'] ?? map['ecgValues'] ?? map['readings'];
      
      // Handle raw_value and convert to values list if values is not provided
      List<double>? valuesList;
      
      // Try to parse values in different formats
      if (normalizedMap['values'] != null) {
        final rawValues = normalizedMap['values'];
        
        if (rawValues is List) {
          valuesList = _parseValuesList(rawValues);
        } else if (rawValues is Map) {
          valuesList = _parseValuesMap(rawValues);
        } else if (rawValues is String) {
          // Try parsing comma-separated or space-separated values
          try {
            valuesList = rawValues
                .split(RegExp(r'[,\s]+'))
                .where((s) => s.isNotEmpty)
                .map((s) => double.tryParse(s) ?? 0.0)
                .toList();
          } catch (_) {
            valuesList = null;
          }
        }
      }
      
      // If no values list but raw_value exists, create a single-point list
      if ((valuesList == null || valuesList.isEmpty) && normalizedMap['raw_value'] != null) {
        final rawValue = normalizedMap['raw_value'];
        if (rawValue is num) {
          valuesList = [rawValue.toDouble()];
        } else if (rawValue is String) {
          final parsedValue = double.tryParse(rawValue);
          if (parsedValue != null) {
            valuesList = [parsedValue];
          }
        }
      }

      // Parse BPM value
      double? processedBpm;
      final bpmValue = normalizedMap['bpm'];
      if (bpmValue != null) {
        if (bpmValue is num) {
          final numBpm = bpmValue.toDouble();
          if (numBpm >= 30 && numBpm <= 250) { // Reasonable heart rate range
            processedBpm = numBpm;
          }
        } else if (bpmValue is String) {
          final parsedBpm = double.tryParse(bpmValue);
          if (parsedBpm != null && parsedBpm >= 30 && parsedBpm <= 250) {
            processedBpm = parsedBpm;
          }
        }
      }

      // Parse timestamp into a usable format
      Object? processedTimestamp = normalizedMap['timestamp'];
      if (processedTimestamp is String) {
        // Try to convert string timestamp to int (milliseconds)
        final parsedInt = int.tryParse(processedTimestamp);
        if (parsedInt != null) {
          processedTimestamp = parsedInt;
        }
      }

      return EcgReading(
        id: _safeCast<String?>(normalizedMap['id']),
        bpm: processedBpm,
        rawValue: _safeCastToDouble(normalizedMap['raw_value']),
        average: _safeCastToDouble(normalizedMap['average']),
        maxInPeriod: _safeCastToInt(normalizedMap['max_in_period']),
        timestamp: processedTimestamp,
        userEmail: _safeCast<String?>(normalizedMap['user_email']),
        values: valuesList,
      );
    } catch (e) {
      _logger.w('Error creating EcgReading from map: $e');
      // Return a minimal valid object
      return EcgReading(
        id: map['id'] as String?,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  // Helper method to parse values list
  static List<double> _parseValuesList(List rawValues) {
    return rawValues
        .map((value) {
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        })
        .toList();
  }

  // Helper method to parse values map
  static List<double> _parseValuesMap(Map rawValues) {
    List<double> result = [];
    
    // Sort by keys if possible (to maintain order)
    final sortedKeys = rawValues.keys.toList()
      ..sort((a, b) {
        if (a is int && b is int) return a.compareTo(b);
        if (a is String && b is String) return a.compareTo(b);
        return 0;
      });
    
    for (var key in sortedKeys) {
      final value = rawValues[key];
      if (value is num) {
        result.add(value.toDouble());
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          result.add(parsed);
        }
      }
    }
    
    return result;
  }

  // Safe cast helper
  static T? _safeCast<T>(dynamic value) {
    if (value is T) return value;
    return null;
  }

  // Safe cast to double
  static double? _safeCastToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Safe cast to int
  static int? _safeCastToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get hasValidData {
    return values != null && values!.isNotEmpty || rawValue != null;
  }

  DateTime? get dateTime {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    } else if (timestamp is String) {
      if (timestamp == '.sv') return null;
      
      // Try to parse string as int first (milliseconds)
      final millis = int.tryParse(timestamp as String);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      
      // Then try as ISO date
      return DateTime.tryParse(timestamp as String);
    } else if (timestamp is Map && (timestamp as Map).containsKey('.sv')) {
      // Server-side timestamp, we don't have the actual time yet
      return null;
    }
    return null;
  }

  @override
  String toString() {
    return 'EcgReading(id: $id, bpm: $bpm, rawValue: $rawValue, average: $average, maxInPeriod: $maxInPeriod, timestamp: $timestamp, userEmail: $userEmail, values: ${values?.length ?? 0} points)';
  }
} 