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
  
  void logE(String tag, String message, [Object? e, StackTrace? stackTrace]) {
    if (_currentLogLevel <= errorLevel) {
      _log('ERROR', tag, message);
      if (e != null) {
        debugPrint('ERROR: $e');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
  
  // Simple log methods without tag
  void v(String message) {
    if (_currentLogLevel <= verbose) {
      _log('VERBOSE', 'Default', message);
    }
  }
  
  void d(String message) {
    if (_currentLogLevel <= debug) {
      _log('DEBUG', 'Default', message);
    }
  }
  
  void i(String message) {
    if (_currentLogLevel <= info) {
      _log('INFO', 'Default', message);
    }
  }
  
  void w(String message) {
    if (_currentLogLevel <= warning) {
      _log('WARNING', 'Default', message);
    }
  }
  
  void e(String message, {Object? e, StackTrace? stackTrace}) {
    if (_currentLogLevel <= errorLevel) {
      _log('ERROR', 'Default', message);
      if (e != null) {
        debugPrint('ERROR: $e');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
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

  void d(String message) {
    _logger.d(message);
  }

  void i(String message) {
    _logger.i(message);
  }

  void w(String message) {
    _logger.w(message);
  }

  void e(String message, {Object? e, StackTrace? stackTrace}) {
    _logger.e(message, e: e, stackTrace: stackTrace);
  }
} 