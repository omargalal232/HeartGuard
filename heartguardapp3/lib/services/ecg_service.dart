import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ECGService extends ChangeNotifier {
  bool _isRecording = false;
  Timer? _timer;
  final String _ubidotsApiUrl = 'https://industrial.api.ubidots.com/api/v1.6/devices/';
  final String _ubidotsToken = 'BBUS-dotPnGDytYSjPQNBGKs68MztvEV1uD';
  final String _deviceLabel = 'esp32';
  final String _variableLabel = 'sensor';
  final _firestore = FirebaseFirestore.instance;
  final List<void Function(double)> _ecgListeners = [];
  
  bool get isRecording => _isRecording;

  void startRecording() {
    if (_isRecording) return;
    _isRecording = true;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _fetchECGData());
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void addEcgListener(void Function(double) listener) {
    if (!_ecgListeners.contains(listener)) {
      _ecgListeners.add(listener);
    }
  }

  void removeEcgListener(void Function(double) listener) {
    _ecgListeners.remove(listener);
  }

  @override
  void dispose() {
    stopRecording();
    _ecgListeners.clear();
    super.dispose();
  }

  Future<void> _fetchECGData() async {
    if (!_isRecording) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_ubidotsApiUrl$_deviceLabel/$_variableLabel/lv'),
        headers: {'X-Auth-Token': _ubidotsToken},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['value'] != null) {
          final value = double.parse(data['value'].toString());
          await saveRecording(value);
          for (var listener in _ecgListeners) {
            listener(value);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching ECG data: $e');
      stopRecording();
    }
  }

  Future<void> saveRecording(double value) async {
    if (!_isRecording) return;
    
    try {
      await _firestore.collection('ecg_readings').add({
        'value': value,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      debugPrint('Error saving ECG data: $e');
    }
  }
} 