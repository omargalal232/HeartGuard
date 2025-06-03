import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../models/heart_sound_recording.dart';

class HeartSoundService {
  final _logger = Logger();
  AudioPlayer _audioPlayer = AudioPlayer();
  static const String _heartSoundPath = 'sounds/heartbeat.mp3';
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isInitialized = false;
  DateTime? _lastPlayTime;
  static const Duration _minPlayInterval = Duration(milliseconds: 500);
  static const Duration _initTimeout = Duration(seconds: 5);

  final List<HeartSoundRecording> _recordingHistory = [];
 final StreamController<int?> _heartBpmController = StreamController<int?>.broadcast();
 final StreamController<int> _externalSoundController = StreamController<int>.broadcast();

  HeartSoundService() {
    _initializeAudioPlayer();
  }

  Future<void> init() async {
    _logger.i('HeartSoundService init called');
    await _initializeAudioPlayer();
  }

  double get volume => _volume;

  Stream<int?> get heartBpmStream => _heartBpmController.stream;

  Stream<int> get externalSoundStream => _externalSoundController.stream;

  void addHeartSoundValue(double? value) {
    if (value != null) {
      // _logger.d('Heart sound value added: $value');
      // Potentially process this value for BPM estimation or visualization
    }
  }

  Future<void> playRecordingById(String id) async {
    _logger.i('Playing recording by ID: $id');
    // Find recording in history and play using _audioPlayer
    // Example: final recording = _recordingHistory.firstWhere((rec) => rec.id == id);
    // await _audioPlayer.play(DeviceFileSource(recording.filePath));
    // _isPlaying = true;
  }

  Future<void> stopPlayback() async {
    _logger.i('Stopping playback');
    await stopHeartSound(); // Assuming this existing method is for general stop
  }

  List<HeartSoundRecording> get recordingHistory => _recordingHistory;

  Future<double> increaseVolume() async {
    _volume = (_volume + 0.1).clamp(0.0, 1.0);
    await setVolume(_volume);
    _logger.i('Volume increased to: $_volume');
    return _volume;
  }

  Future<double> decreaseVolume() async {
    _volume = (_volume - 0.1).clamp(0.0, 1.0);
    await setVolume(_volume);
    _logger.i('Volume decreased to: $_volume');
    return _volume;
  }

  void startExternalRecording() {
    _logger.i('Starting external recording');
    // Logic to start listening to an external sound source (e.g., ESP32)
    // and push data to _externalSoundController
  }

  Future<HeartSoundRecording?> stopExternalRecording() async {
    _logger.i('Stopping external recording');
    // Logic to stop external recording and save it
    // Return a HeartSoundRecording object or null
    // Example:
    // final recording = HeartSoundRecording(
    //   id: DateTime.now().millisecondsSinceEpoch.toString(),
    //   filePath: 'path/to/external_recording.wav',
    //   duration: Duration(seconds: 10),
    //   timestamp: DateTime.now(),
    //   source: 'external'
    // );
    // _recordingHistory.add(recording);
    // return recording;
    return null;
  }

  Future<void> _initializeAudioPlayer() async {
    if (_isInitialized) return;
    
    try {
      // Set up error handling first
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed) {
          _logger.i('Heart sound completed');
          _isPlaying = false;
        }
      });
      
      // Initialize with timeout
      await Future.any([
        _audioPlayer.setReleaseMode(ReleaseMode.loop),
        Future.delayed(_initTimeout).then((_) => throw TimeoutException('Audio player initialization timed out'))
      ]);
      
      await _audioPlayer.setVolume(_volume);
      _isInitialized = true;
      _logger.i('Audio player initialized successfully');
    } catch (e) {
      _logger.e('Error initializing audio player: $e');
      _isInitialized = false;
      // Try to recover
      await _audioPlayer.dispose();
      _audioPlayer = AudioPlayer();
    }
  }

  Future<void> playHeartSound(bool isNormal) async {
    if (!_isInitialized) {
      await _initializeAudioPlayer();
      if (!_isInitialized) {
        _logger.e('Cannot play heart sound - audio player not initialized');
        return;
      }
    }

    try {
      // Check if we should play based on time interval
      final now = DateTime.now();
      if (_lastPlayTime != null && 
          now.difference(_lastPlayTime!) < _minPlayInterval) {
        return;
      }
      _lastPlayTime = now;

      if (_isPlaying) {
        await stopHeartSound();
      }

      // Adjust volume based on heart condition
      final targetVolume = isNormal ? _volume : _volume * 0.7;
      await _audioPlayer.setVolume(targetVolume);

      // Play with error handling and timeout
      await Future.any([
        _audioPlayer.play(AssetSource(_heartSoundPath)),
        Future.delayed(_initTimeout).then((_) => throw TimeoutException('Playing heart sound timed out'))
      ]);
      
      _isPlaying = true;
      _logger.i('Playing heart sound at volume: $targetVolume');
    } catch (e) {
      _logger.e('Error playing heart sound: $e');
      _isPlaying = false;
      // Try to recover
      if (e is TimeoutException) {
        await _audioPlayer.dispose();
        _audioPlayer = AudioPlayer();
        _isInitialized = false;
      }
    }
  }

  Future<void> stopHeartSound() async {
    if (!_isInitialized) return;
    
    try {
      await Future.any([
        _audioPlayer.stop(),
        Future.delayed(_initTimeout).then((_) => throw TimeoutException('Stopping heart sound timed out'))
      ]);
      _isPlaying = false;
      _logger.i('Heart sound stopped');
    } catch (e) {
      _logger.e('Error stopping heart sound: $e');
      // Try to recover
      if (e is TimeoutException) {
        await _audioPlayer.dispose();
        _audioPlayer = AudioPlayer();
        _isInitialized = false;
      }
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;
    
    try {
      _volume = volume.clamp(0.0, 1.0);
      if (_isPlaying) {
        await Future.any([
          _audioPlayer.setVolume(_volume),
          Future.delayed(_initTimeout).then((_) => throw TimeoutException('Setting volume timed out'))
        ]);
        _logger.i('Heart sound volume set to: $_volume');
      }
    } catch (e) {
      _logger.e('Error setting heart sound volume: $e');
      // Try to recover
      if (e is TimeoutException) {
        await _audioPlayer.dispose();
        _audioPlayer = AudioPlayer();
        _isInitialized = false;
      }
    }
  }

  void dispose() {
    stopHeartSound();
    _audioPlayer.dispose();
    _heartBpmController.close();
    _externalSoundController.close();
    _isInitialized = false;
    _logger.i('Heart sound service disposed');
  }
} 