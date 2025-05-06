import 'package:flutter/foundation.dart';

/// A simple logger service that supports different log levels
class Logger {
  static final Logger _instance = Logger._internal();
  
  factory Logger() => _instance;
  
  Logger._internal();
  
  // Log levels
  static const int verbose = 0;
  static const int debug = 1;
  static const int info = 2;
  static const int warning = 3;
  static const int errorLevel = 4;
  
  // Current log level - adjust as needed
  static int _currentLogLevel = kDebugMode ? verbose : info;
  
  static void setLogLevel(int level) {
    _currentLogLevel = level;
  }
  
  // Log with tag methods
  void logV(String tag, String message) {
    if (_currentLogLevel <= verbose) {
      _log('VERBOSE', tag, message);
    }
  }
  
  void logD(String tag, String message) {
    if (_currentLogLevel <= debug) {
      _log('DEBUG', tag, message);
    }
  }
  
  void logI(String tag, String message) {
    if (_currentLogLevel <= info) {
      _log('INFO', tag, message);
    }
  }
  
  void logW(String tag, String message) {
    if (_currentLogLevel <= warning) {
      _log('WARNING', tag, message);
    }
  }
  
  void logE(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLogLevel <= errorLevel) {
      _log('ERROR', tag, message);
      if (error != null) {
        debugPrint('ERROR: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
  
  // Simple log methods without tag
  void v(String message, [Object? error]) {
    if (_currentLogLevel <= verbose) {
      _log('VERBOSE', 'Default', message);
    }
  }
  
  void d(String message, [Object? error]) {
    if (_currentLogLevel <= debug) {
      _log('DEBUG', 'Default', message);
      if (error != null) {
        debugPrint('ERROR: $error');
      }
    }
  }
  
  void i(String message, [Object? error]) {
    if (_currentLogLevel <= info) {
      _log('INFO', 'Default', message);
      if (error != null) {
        debugPrint('ERROR: $error');
      }
    }
  }
  
  void w(String message, [Object? error]) {
    if (_currentLogLevel <= warning) {
      _log('WARNING', 'Default', message);
      if (error != null) {
        debugPrint('ERROR: $error');
      }
    }
  }
  
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLogLevel <= errorLevel) {
      _log('ERROR', 'Default', message);
      if (error != null) {
        debugPrint('ERROR: $error');
      }
    }
  }
  
  // Helper method to log the message
  void _log(String level, String tag, String message) {
    debugPrint('[$level] $tag: $message');
  }
}

class LoggerService {
  final Logger _logger = Logger();

  void v(String message, [Object? error]) {
    _logger.v(message, error);
  }

  void d(String message, [Object? error]) {
    _logger.d(message, error);
  }

  void i(String message, [Object? error]) {
    _logger.i(message, error);
  }

  void w(String message, [Object? error]) {
    _logger.w(message, error);
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
  }
} 