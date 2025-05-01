// lib/services/ecg_data_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import '../models/ecg_reading.dart';

class EcgDataService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('ecg_data');
  final Logger _logger = Logger();

  Stream<EcgReading?> get latestEcgReadingStream {
    Query query = _dbRef.orderByKey().limitToLast(1);

    return query.onChildAdded.map((event) {
      try {
        if (event.snapshot.exists && event.snapshot.value != null) {
          _logger.d("Raw snapshot data: ${event.snapshot.value}");
          final value = event.snapshot.value;
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            data['id'] = event.snapshot.key;
            _logger.d("Parsed data map: $data");
            
            final reading = EcgReading.fromMap(data);
            if (reading.hasValidData) {
              _logger.i("Successfully parsed valid ECG reading: ${reading.toString()}");
              return reading;
            } else {
              _logger.w("Parsed ECG reading has no valid data");
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
        _logger.e("Error parsing ECG data", error: e, stackTrace: stackTrace);
        return null;
      }
    }).handleError((error, stackTrace) {
      _logger.e("Error in ECG data stream", error: error, stackTrace: stackTrace);
    });
  }

  Future<EcgReading?> getLatestReading() async {
    try {
      _logger.d("Fetching latest ECG reading...");
      
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
        
        final reading = EcgReading.fromMap(data);
        if (reading.hasValidData) {
          _logger.i("Successfully retrieved latest ECG reading: ${reading.toString()}");
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