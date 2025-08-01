import 'dart:async';
import 'package:flutter/material.dart';
import 'user_exam_service.dart';

class ExpiryCleanupService {
  static Timer? _cleanupTimer;
  static const Duration _cleanupInterval = Duration(
    hours: 24,
  ); // Run once per day

  // Start periodic cleanup
  static void startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _performCleanup();
    });
  }

  // Stop periodic cleanup
  static void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  // Perform cleanup
  static Future<void> _performCleanup() async {
    try {
      await UserExamService.cleanupExpiredExams();
      debugPrint('Expired exams cleanup completed');
    } catch (e) {
      debugPrint('Error during expired exams cleanup: $e');
    }
  }

  // Get formatted expiry date string
  static String getExpiryDateString(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} remaining';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} remaining';
    }
  }

  // Check if exam is expired
  static bool isExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate);
  }

  // Get expiry status color
  static Color getExpiryStatusColor(DateTime? expiryDate) {
    if (expiryDate == null) return Colors.grey;

    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return Colors.red; // Expired
    } else if (difference.inDays <= 7) {
      return Colors.orange; // Expiring soon
    } else {
      return Colors.green; // Valid
    }
  }
}
