// lib/services/ecg_data_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import '../models/ecg_reading.dart';

/// Service for real-time ECG data streaming and fetching the latest reading.
class EcgDataService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('ecg_data');
  final Logger _logger = Logger();
  final List<double> _ecgSampleBuffer = [];
  static const int _bufferSize = 200; // Desired number of samples per EcgReading

  /// Returns a stream of the latest ECG reading (or null if invalid).
  Stream<EcgReading?> get latestEcgReadingStream {
    // Listen to all new children added, not just the last one.
    // Order by key to process in rough chronological order.
    return _dbRef.orderByKey().onChildAdded.asyncMap((event) async { // Use asyncMap for potential future async operations
      try {
        if (event.snapshot.exists && event.snapshot.value != null) {
          _logger.d("Raw snapshot data: ${event.snapshot.value}");
          final value = event.snapshot.value;
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            final rawValue = EcgReading.fromMap(data).rawValue; // Get rawValue using existing parser logic briefly

            if (rawValue != null) {
              _ecgSampleBuffer.add(rawValue);

              if (_ecgSampleBuffer.length >= _bufferSize) {
                // Buffer is full, create and emit an EcgReading
                final Map<String, dynamic> readingData = {
                  'id': event.snapshot.key, // Use the key of the last snapshot in the buffer batch
                  'values': List<double>.from(_ecgSampleBuffer), // Use the buffered samples
                  'rawValue': _ecgSampleBuffer.isNotEmpty ? _ecgSampleBuffer.last : null, // Populate rawValue
                  'timestamp': data['timestamp'] ?? ServerValue.timestamp, // Use timestamp from last sample
                  'bpm': data['bpm'], // Use bpm from last sample, or calculate average if preferred
                  // Add other relevant fields from 'data' if needed
                  'user_email': data['user_email'],
                  'average': data['average'], // This might need re-evaluation based on buffered data
                  'max_in_period': data['max_in_period'], // This might need re-evaluation
                };
                
                final reading = EcgReading.fromMap(readingData);
                _logger.i("Successfully created buffered ECG reading: ${reading.toString()} with ${_ecgSampleBuffer.length} values.");
                _ecgSampleBuffer.clear(); // Clear buffer for next batch

                if (reading.hasValidData && reading.timestampMs != null) {
                  return reading;
                } else {
                  _logger.w("Buffered ECG reading has no valid data or timestamp");
                  return null;
                }
              } else {
                // Buffer not yet full, do not emit
                _logger.d("ECG sample buffer size: ${_ecgSampleBuffer.length}/$_bufferSize");
                return null; 
              }
            } else {
              _logger.w("Parsed rawValue is null from snapshot: $data");
              return null;
            }
          } else {
            _logger.w("Snapshot value is not a Map: ${value.runtimeType}");
            return null;
          }
        } else {
          _logger.w("Snapshot does not exist or has null value");
          return null;
        }
      } catch (e, stackTrace) {
        _logger.e("Error processing ECG data for buffering", error: e, stackTrace: stackTrace);
        return null;
      }
    }).where((reading) => reading != null) // Filter out nulls before they reach the subscriber
    .handleError((error, stackTrace) {
      _logger.e("Error in ECG data stream after buffering logic", error: error, stackTrace: stackTrace);
      // Optionally, emit a special error EcgReading or just let the error propagate
    });
  }

  Future<EcgReading?> getLatestReading() async {
    try {
      _logger.d("Fetching latest ECG reading (Note: getLatestReading provides a single snapshot, not buffered data)...");
      
      final snapshot = await _dbRef.orderByKey().limitToLast(1).get();
      
      if (!snapshot.exists || snapshot.children.isEmpty) {
        _logger.w("No ECG readings available");
        return null;
      }
      
      final childSnapshot = snapshot.children.first;
      final value = childSnapshot.value;
      
      if (value is Map) {
        final data = Map<String, dynamic>.from(value);
        data['id'] = childSnapshot.key;
        
        // For getLatestReading, we still return a single point reading as before,
        // as the primary stream is now for buffered data.
        // Or, you might decide to change this to fetch _bufferSize items and return the latest buffered one.
        // For simplicity now, it mirrors old behavior but uses the fromMap that can handle list of values.
        if (data['raw_value'] != null && data['values'] == null) {
           data['values'] = [ (data['raw_value'] is num) ? (data['raw_value'] as num).toDouble() : double.tryParse(data['raw_value'].toString()) ?? 0.0];
        }

        final reading = EcgReading.fromMap(data);
        if (reading.hasValidData) {
          _logger.i("Successfully retrieved latest single ECG reading: ${reading.toString()}");
          return reading;
        } else {
          _logger.w("Retrieved ECG reading has no valid data");
          return null;
        }
      } else {
        _logger.w("Reading data is not in expected format: ${value.runtimeType}");
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e("Error fetching latest ECG reading", error: e, stackTrace: stackTrace);
      return null;
    }
  }
} 