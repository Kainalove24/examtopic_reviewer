import 'package:flutter/foundation.dart';

class Logger {
  static const bool _isDebugMode = kDebugMode;

  // Debug logging - only in debug mode
  static void debug(String message) {
    if (_isDebugMode) {
      print('🔍 DEBUG: $message');
    }
  }

  // Info logging - only in debug mode
  static void info(String message) {
    if (_isDebugMode) {
      print('ℹ️ INFO: $message');
    }
  }

  // Warning logging - always logged
  static void warning(String message) {
    print('⚠️ WARNING: $message');
  }

  // Error logging - always logged
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('❌ ERROR: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }

  // Performance logging - only in debug mode
  static void performance(String operation, Duration duration) {
    if (_isDebugMode) {
      print('⚡ PERFORMANCE: $operation took ${duration.inMilliseconds}ms');
    }
  }

  // Conditional debug logging with expensive operations
  static void debugExpensive(
    String message,
    String Function() expensiveOperation,
  ) {
    if (_isDebugMode) {
      try {
        final result = expensiveOperation();
        print('🔍 DEBUG: $message - $result');
      } catch (e) {
        print('🔍 DEBUG: $message - [Error getting details: $e]');
      }
    }
  }
}
