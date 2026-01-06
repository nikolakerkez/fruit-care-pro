import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized error logging utility
/// Logs errors to console (debug) and Crashlytics (production)
class ErrorLogger {
  /// Logs error to Crashlytics and console
  static Future<void> logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    String? screen,
    Map<String, dynamic>? additionalData,
    bool fatal = false,
  }) async {
    // Always print to console in debug mode
    if (kDebugMode) {
      debugPrint('❌ Error${screen != null ? ' in $screen' : ''}: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
      if (additionalData != null) {
        debugPrint('Additional data: $additionalData');
      }
    }

    try {
      // Set custom keys for better debugging in Crashlytics
      if (screen != null) {
        await FirebaseCrashlytics.instance.setCustomKey('screen', screen);
      }
      
      if (additionalData != null) {
        for (var entry in additionalData.entries) {
          await FirebaseCrashlytics.instance.setCustomKey(
            entry.key,
            entry.value.toString(),
          );
        }
      }

      // Record error to Crashlytics
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      // Fallback if Crashlytics fails
      debugPrint('⚠️ Failed to log to Crashlytics: $e');
    }
  }

  /// Logs a custom message/event to Crashlytics
  static Future<void> logMessage(String message) async {
    if (kDebugMode) {
      debugPrint('📝 Log: $message');
    }
    
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('⚠️ Failed to log message: $e');
    }
  }

  /// Sets user identifier for Crashlytics (useful for tracking issues per user)
  static Future<void> setUserId(String userId) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('⚠️ Failed to set user ID: $e');
    }
  }
}