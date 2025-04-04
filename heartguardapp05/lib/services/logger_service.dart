import 'package:flutter/foundation.dart';

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
  
  void v(String tag, String message) {
    if (_currentLogLevel <= verbose) {
      _log('VERBOSE', tag, message);
    }
  }
  
  void d(String tag, String message) {
    if (_currentLogLevel <= debug) {
      _log('DEBUG', tag, message);
    }
  }
  
  void i(String tag, String message) {
    if (_currentLogLevel <= info) {
      _log('INFO', tag, message);
    }
  }
  
  void w(String tag, String message) {
    if (_currentLogLevel <= warning) {
      _log('WARNING', tag, message);
    }
  }
  
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
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
  
  void _log(String level, String tag, String message) {
    debugPrint('[$level] $tag: $message');
  }
} 