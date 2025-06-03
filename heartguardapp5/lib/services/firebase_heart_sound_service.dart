import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class FirebaseHeartSoundService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  
  // Stream controllers
  final StreamController<int> _heartSoundValueController = StreamController<int>.broadcast();
  final StreamController<List<int>> _heartSoundBufferController = StreamController<List<int>>.broadcast();
  
  // Subscription to Firebase
  StreamSubscription<DatabaseEvent>? _heartSoundSubscription;
  
  // Buffer for collecting sound values
  final List<int> _soundBuffer = [];
  final int _maxBufferSize = 8000; // ~1 second of sound at 8kHz
  int _inputMaxForNormalization = 4095; // Added for configurable normalization
  
  // Active state
  bool _isActive = false;
  
  // Getters
  Stream<int> get heartSoundValueStream => _heartSoundValueController.stream;
  Stream<List<int>> get heartSoundBufferStream => _heartSoundBufferController.stream;
  List<int> get currentSoundBuffer => List.unmodifiable(_soundBuffer);
  bool get isActive => _isActive;
  
  // Start listening to Firebase heart sound data
  Future<bool> startListening({String soundFieldKey = 'heart_sound_raw', int inputMaxValueForNormalization = 4095}) async {
    if (_isActive) {
      _logger.i('Already listening to heart sound data');
      return true;
    }
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.e('User not logged in. Cannot start listening.');
        return false;
      }
      
      final currentUserEmail = user.email;
      if (currentUserEmail == null || currentUserEmail.isEmpty) {
        _logger.e('User email is not available. Cannot filter data.');
        return false;
      }
      
      _inputMaxForNormalization = inputMaxValueForNormalization; // Store the normalization max value
      _logger.i('Current user email: $currentUserEmail, listening for field: $soundFieldKey, input max for norm: $_inputMaxForNormalization');

      // Clear buffer
      _soundBuffer.clear();
      
      // Subscribe to new child entries at the root
      final DatabaseReference dataRef = _database.ref();
      _heartSoundSubscription = dataRef.onChildAdded.listen((event) {
        final snapshotValue = event.snapshot.value;
        
        if (snapshotValue is! Map) {
          _logger.w('Received non-map data at root child: ${event.snapshot.key}');
          return;
        }
        
        final Map<dynamic, dynamic> entryData = snapshotValue;
        final String? entryEmail = entryData['user_email'] as String?;
        
        if (entryEmail == currentUserEmail) {
          final dynamic soundValue = entryData[soundFieldKey];
          if (soundValue is int) {
            _processHeartSoundValue(soundValue);
          } else {
            _logger.w('Sound value for key "$soundFieldKey" is missing or not an int in entry: ${event.snapshot.key}');
          }
        } else {
          // Optional: Log if an entry does not match the current user's email. This can be noisy.
          // _logger.d('Skipping entry for user: $entryEmail');
        }
      }, onError: (error) {
        _logger.e('Error listening to heart sound data at root', error: error);
        _isActive = false; // Ensure state is updated on error
      });
      
      _isActive = true;
      _logger.i('Started listening to heart sound data at DB root, filtering for email: $currentUserEmail, field: $soundFieldKey');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error starting heart sound listener', error: e, stackTrace: stackTrace);
      return false;
    }
  }
  
  // Process individual heart sound value
  void _processHeartSoundValue(int value) {
    // Normalize value if needed (depending on your sensor's output range)
    // For MAX9814, values are usually 0-1023 from ADC - caller can now specify this via inputMaxValueForNormalization
    final normalizedValue = (value > _inputMaxForNormalization) ? 255 : (value * 255 ~/ _inputMaxForNormalization);
    
    // Add to buffer
    _soundBuffer.add(normalizedValue);
    if (_soundBuffer.length > _maxBufferSize) {
      _soundBuffer.removeAt(0);
    }
    
    // Notify listeners
    _heartSoundValueController.add(normalizedValue);
    
    // Notify buffer listeners every 100 values
    if (_soundBuffer.length % 100 == 0) {
      _heartSoundBufferController.add(List.from(_soundBuffer));
    }
  }
  
  // Get the last N seconds of heart sound data
  List<int> getLastNSeconds(int seconds, {int sampleRate = 8000}) {
    final int samplesToGet = seconds * sampleRate;
    if (_soundBuffer.length <= samplesToGet) {
      return List.from(_soundBuffer);
    }
    
    return _soundBuffer.sublist(_soundBuffer.length - samplesToGet);
  }
  
  // Stop listening
  Future<void> stopListening() async {
    await _heartSoundSubscription?.cancel();
    _heartSoundSubscription = null;
    _isActive = false;
    _logger.i('Stopped listening to heart sound data');
  }
  
  // Clean up resources
  void dispose() {
    stopListening();
    _heartSoundValueController.close();
    _heartSoundBufferController.close();
    _logger.d('Firebase heart sound service disposed');
  }
} 