import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum SessionMode { study, quiz }

class ProgressProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> progress = {};
  bool isGuest = false;

  Future<void> loadProgress(String examId) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      isGuest = true;
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('progress_$examId');
      if (data != null) {
        progress = Map<String, dynamic>.from(await _decode(data));
      } else {
        progress = {};
      }
    } else {
      isGuest = false;
      // Load from cloud and sync with local
      await _loadProgressWithSync(user.uid, examId);
    }
    notifyListeners();
  }

  // Load progress with cloud-local sync
  Future<void> _loadProgressWithSync(String userId, String examId) async {
    try {
      // Get cloud progress
      final cloudDoc = await _firestore
          .collection('user_progress')
          .doc(userId)
          .collection('exams')
          .doc(examId)
          .get();

      // Get local progress
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('progress_$examId');
      Map<String, dynamic> localProgress = {};
      if (localData != null) {
        localProgress = Map<String, dynamic>.from(await _decode(localData));
      }

      if (cloudDoc.exists) {
        final cloudProgress = cloudDoc.data()!;

        // Merge cloud and local progress, prioritizing cloud data
        final mergedProgress = <String, dynamic>{};

        // Add cloud progress first (takes priority)
        mergedProgress.addAll(cloudProgress);

        // Add local progress for fields not in cloud
        for (final entry in localProgress.entries) {
          if (!mergedProgress.containsKey(entry.key)) {
            mergedProgress[entry.key] = entry.value;
          }
        }

        progress = mergedProgress;

        // Upload merged progress back to cloud
        await _firestore
            .collection('user_progress')
            .doc(userId)
            .collection('exams')
            .doc(examId)
            .set(mergedProgress);

        // Update local storage
        await prefs.setString(
          'progress_$examId',
          await _encode(mergedProgress),
        );
      } else {
        // No cloud data, use local data and upload to cloud
        progress = localProgress;
        if (localProgress.isNotEmpty) {
          await _firestore
              .collection('user_progress')
              .doc(userId)
              .collection('exams')
              .doc(examId)
              .set(localProgress);
        }
      }
    } catch (e) {
      print('Error syncing progress: $e');
      // Fallback to local only
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('progress_$examId');
      if (localData != null) {
        progress = Map<String, dynamic>.from(await _decode(localData));
      } else {
        progress = {};
      }
    }
  }

  Future<void> saveProgress(String examId) async {
    final user = _auth.currentUser;

    // Always save to local storage for backup
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('progress_$examId', await _encode(progress));

    // If authenticated, also save to cloud
    if (user != null && !user.isAnonymous) {
      try {
        await _firestore
            .collection('user_progress')
            .doc(user.uid)
            .collection('exams')
            .doc(examId)
            .set(progress);
      } catch (e) {
        print('Error saving progress to cloud: $e');
        // Continue with local save only
      }
    }

    notifyListeners();
  }

  void updateProgress({
    required String examId,
    List<String>? masteredQuestions,
    Map<String, bool>? repeatFlags,
    List<int>? quizScores,
    String? currentSet,
    Map<String, dynamic>? lastSession,
    List<String>? mistakeQuestions,
    List<String>? correctlyAnsweredQuestions,
    Map<String, int>? masteryAttempts,
    Map<String, int>? correctAnswerCounts,
  }) {
    if (masteredQuestions != null) {
      progress['masteredQuestions'] = masteredQuestions;
    }
    if (repeatFlags != null) progress['repeatFlags'] = repeatFlags;
    if (quizScores != null) progress['quizScores'] = quizScores;
    if (currentSet != null) progress['currentSet'] = currentSet;
    if (lastSession != null) progress['lastSession'] = lastSession;
    if (mistakeQuestions != null) {
      progress['mistakeQuestions'] = mistakeQuestions;
    }
    if (correctlyAnsweredQuestions != null) {
      progress['correctlyAnsweredQuestions'] = correctlyAnsweredQuestions;
    }
    if (masteryAttempts != null) {
      progress['masteryAttempts'] = masteryAttempts;
    }
    if (correctAnswerCounts != null) {
      progress['correctAnswerCounts'] = correctAnswerCounts;
    }
    notifyListeners();
  }

  Future<String> _encode(Map<String, dynamic> data) async {
    return Future.value(jsonEncode(data));
  }

  Future<Map<String, dynamic>> _decode(String data) async {
    return Future.value(jsonDecode(data) as Map<String, dynamic>);
  }
}
