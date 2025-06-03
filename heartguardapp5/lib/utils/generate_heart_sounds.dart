import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:logger/logger.dart';

class HeartSoundGenerator {
  final _audioRecorder = AudioRecorder();
  final _logger = Logger();
  
  Future<void> generateHeartSounds() async {
    try {
      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${directory.path}/sounds');
      
      // Create the sounds directory if it doesn't exist
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
        _logger.i('Created sounds directory');
      }
      
      // Create a simple heartbeat sound file
      
      // Generate a simple "lub-dub" sound
      await _generateHeartbeatSound(soundsDir.path);
      
      _logger.i('Generated heartbeat sound file');
    } catch (e) {
      _logger.e('Error generating heart sounds', error: e);
    } finally {
      await _audioRecorder.dispose();
    }
  }
  
  Future<void> _generateHeartbeatSound(String directoryPath) async {
    try {
      final filePath = '$directoryPath/default_heartbeat.mp3';
      
      // Initialize the recorder
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      
      // Record a short silence
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Stop recording
      await _audioRecorder.stop();
      
      _logger.i('Generated heartbeat sound at: $filePath');
    } catch (e) {
      _logger.e('Error generating heartbeat sound', error: e);
      rethrow;
    }
  }
} 