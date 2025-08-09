import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exam_question.dart';
import '../utils/logger.dart';
import '../services/admin_auth_service.dart'; // Added import for AdminAuthService

class UserExamService {
  static const String _userExamsKey = 'user_unlocked_exams';
  static const String _userImportedExamsKey = 'user_imported_exams';

  // Firebase instances
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all exams user has access to (built-in + unlocked + imported)
  static Future<List<Map<String, dynamic>>> getUserExams() async {
    final user = _auth.currentUser;

    // Check if user is admin (admin users don't use Firebase Auth)
    bool isAdmin = false;
    try {
      isAdmin = await AdminAuthService.isAuthenticated();
    } catch (e) {
      isAdmin = false;
    }

    if (isAdmin) {
      // Admin mode - use local storage only
      return _getLocalUserExams();
    } else if (user != null && !user.isAnonymous) {
      // Authenticated user - sync with cloud and merge with local
      return await _getCloudUserExamsWithLocalSync(user.uid);
    } else {
      // Guest mode - only show built-in exams (no unlocked exams since guests can't redeem vouchers)
      return _getLocalUserExams();
    }
  }

  // Get exams from local storage (guest mode)
  static Future<List<Map<String, dynamic>>> _getLocalUserExams() async {
    final prefs = await SharedPreferences.getInstance();

    // Get unlocked exams (from vouchers)
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];

    final unlockedExams = unlockedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .where((exam) => !_isExpired(exam)) // Filter out expired exams
        .toList();

    // Get user imported exams
    final userImportedExamsJson =
        prefs.getStringList(_userImportedExamsKey) ?? [];
    final userImportedExams = userImportedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    // Combine all exams
    final allExams = [...unlockedExams, ...userImportedExams];
    return allExams;
  }

  // Get exams from cloud storage (authenticated users)
  static Future<List<Map<String, dynamic>>> _getCloudUserExams(
    String userId,
  ) async {
    try {
      // Get unlocked exams from cloud
      final unlockedSnapshot = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('unlocked')
          .get();

      final unlockedExams = unlockedSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((exam) => !_isExpired(exam)) // Filter out expired exams
          .toList();

      // Get user imported exams from cloud
      final importedSnapshot = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('imported')
          .get();

      final importedExams = importedSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Combine all exams
      final allExams = [...unlockedExams, ...importedExams];
      return allExams;
    } catch (e) {
      Logger.error('Error getting cloud user exams: $e');
      // Fallback to local storage
      return _getLocalUserExams();
    }
  }

  // Get exams from cloud storage with local sync (authenticated users)
  static Future<List<Map<String, dynamic>>> _getCloudUserExamsWithLocalSync(
    String userId,
  ) async {
    try {
      // Get cloud exams
      final cloudExams = await _getCloudUserExams(userId);

      // Get local exams
      final localExams = await _getLocalUserExams();

      // Merge cloud and local exams, prioritizing cloud data
      final mergedExams = <Map<String, dynamic>>[];
      final processedIds = <String>{};

      // Add cloud exams first (they take priority)
      for (final cloudExam in cloudExams) {
        mergedExams.add(cloudExam);
        processedIds.add(cloudExam['id']);
      }

      // Add local exams that aren't in cloud
      for (final localExam in localExams) {
        if (!processedIds.contains(localExam['id'])) {
          // Upload local exam to cloud
          await _uploadLocalExamToCloud(userId, localExam);
          mergedExams.add(localExam);
        }
      }

      return mergedExams;
    } catch (e) {
      Logger.error('Error syncing cloud and local exams: $e');
      // Fallback to local storage
      return _getLocalUserExams();
    }
  }

  // Upload local exam to cloud storage
  static Future<void> _uploadLocalExamToCloud(
    String userId,
    Map<String, dynamic> examData,
  ) async {
    try {
      final examId = examData['id'];
      final examType = examData['type'];

      if (examType == 'unlocked') {
        await _firestore
            .collection('user_exams')
            .doc(userId)
            .collection('unlocked')
            .doc(examId)
            .set(examData);
      } else if (examType == 'user_imported') {
        await _firestore
            .collection('user_exams')
            .doc(userId)
            .collection('imported')
            .doc(examId)
            .set(examData);
      }
    } catch (e) {
      Logger.error('Error uploading local exam to cloud: $e');
    }
  }

  // Check if exam is expired
  static bool _isExpired(Map<String, dynamic> exam) {
    final expiryDate = exam['expiryDate'];
    if (expiryDate == null) return false;

    try {
      final expiry = DateTime.parse(expiryDate);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      Logger.error('Error parsing expiry date: $e');
      return false;
    }
  }

  // Unlock an exam for user (called when voucher is redeemed)
  static Future<bool> unlockExam(
    String examId,
    Map<String, dynamic> examData, {
    Duration? expiryDuration, // Optional expiry duration
  }) async {
    try {
      final user = _auth.currentUser;
      final expiryDate = expiryDuration != null
          ? DateTime.now().add(expiryDuration).toIso8601String()
          : null;

      // Check if user is admin (admin users don't use Firebase Auth)
      bool isAdmin = false;
      try {
        isAdmin = await AdminAuthService.isAuthenticated();
      } catch (e) {
        isAdmin = false;
      }

      // Note: Guest users can no longer redeem vouchers, so we only handle authenticated users and admins
      if (isAdmin) {
        // Admin mode - use local storage
        return await _unlockExamLocal(examId, examData, expiryDate);
      } else if (user != null && !user.isAnonymous) {
        // Authenticated user - use cloud storage
        return await _unlockExamCloud(user.uid, examId, examData, expiryDate);
      } else {
        // This should not happen since guest users are blocked from voucher redemption
        return false;
      }
    } catch (e) {
      Logger.error('Error unlocking exam: $e');
      return false;
    }
  }

  // Unlock exam in local storage (guest mode)
  static Future<bool> _unlockExamLocal(
    String examId,
    Map<String, dynamic> examData,
    String? expiryDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];

    // Check if exam is already unlocked
    final existingExams = unlockedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    if (existingExams.any((exam) => exam['id'] == examId)) {
      return true; // Already unlocked
    }

    // Add exam to unlocked list
    final examToUnlock = {
      'id': examId,
      'type': 'unlocked', // From voucher
      'unlockDate': DateTime.now().toIso8601String(),
      if (expiryDate != null) 'expiryDate': expiryDate,
      ...examData,
    };

    unlockedExamsJson.add(jsonEncode(examToUnlock));

    try {
      await prefs.setStringList(_userExamsKey, unlockedExamsJson);
      return true;
    } catch (e) {
      Logger.error('Error saving to SharedPreferences: $e');
      return false;
    }
  }

  // Unlock exam in cloud storage (authenticated users)
  static Future<bool> _unlockExamCloud(
    String userId,
    String examId,
    Map<String, dynamic> examData,
    String? expiryDate,
  ) async {
    try {
      // Check if exam is already unlocked
      final existingDoc = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('unlocked')
          .doc(examId)
          .get();

      if (existingDoc.exists) {
        return true; // Already unlocked
      }

      // Add exam to cloud storage
      await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('unlocked')
          .doc(examId)
          .set({
            'type': 'unlocked', // From voucher
            'unlockDate': DateTime.now().toIso8601String(),
            if (expiryDate != null) 'expiryDate': expiryDate,
            ...examData,
          });

      return true;
    } catch (e) {
      Logger.error('Error unlocking exam in cloud: $e');
      return false;
    }
  }

  // Add user imported exam
  static Future<bool> addUserImportedExam(Map<String, dynamic> examData) async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.isAnonymous) {
        // Guest mode - use local storage
        return await _addUserImportedExamLocal(examData);
      } else {
        // Authenticated user - use cloud storage
        return await _addUserImportedExamCloud(user.uid, examData);
      }
    } catch (e) {
      Logger.error('Error adding user imported exam: $e');
      return false;
    }
  }

  // Add user imported exam to local storage (guest mode)
  static Future<bool> _addUserImportedExamLocal(
    Map<String, dynamic> examData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userImportedExamsJson =
        prefs.getStringList(_userImportedExamsKey) ?? [];

    // Check if exam already exists
    final existingExams = userImportedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    if (existingExams.any((exam) => exam['id'] == examData['id'])) {
      return false; // Already exists
    }

    // Add exam to user imported list
    final examToAdd = {
      'type': 'user_imported',
      'importDate': DateTime.now().toIso8601String(),
      ...examData,
    };

    userImportedExamsJson.add(jsonEncode(examToAdd));
    await prefs.setStringList(_userImportedExamsKey, userImportedExamsJson);

    return true;
  }

  // Add user imported exam to cloud storage (authenticated users)
  static Future<bool> _addUserImportedExamCloud(
    String userId,
    Map<String, dynamic> examData,
  ) async {
    try {
      // Check if exam already exists
      final existingDoc = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('imported')
          .doc(examData['id'])
          .get();

      if (existingDoc.exists) {
        return false; // Already exists
      }

      // Add exam to cloud storage
      await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('imported')
          .doc(examData['id'])
          .set({
            'type': 'user_imported',
            'importDate': DateTime.now().toIso8601String(),
            ...examData,
          });

      return true;
    } catch (e) {
      Logger.error('Error adding user imported exam to cloud: $e');
      return false;
    }
  }

  // Get exam questions for a specific exam
  static Future<List<ExamQuestion>> getExamQuestions(String examId) async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.isAnonymous) {
        // Guest mode - get from local storage
        return await _getExamQuestionsLocal(examId);
      } else {
        // Authenticated user - get from cloud
        return await _getExamQuestionsCloud(user.uid, examId);
      }
    } catch (e) {
      Logger.error('Error getting exam questions: $e');
      return [];
    }
  }

  // Get exam questions from local storage (guest mode)
  static Future<List<ExamQuestion>> _getExamQuestionsLocal(
    String examId,
  ) async {
    // First check user imported exams
    final prefs = await SharedPreferences.getInstance();
    final userImportedExamsJson =
        prefs.getStringList(_userImportedExamsKey) ?? [];

    for (final examJson in userImportedExamsJson) {
      final exam = Map<String, dynamic>.from(jsonDecode(examJson));
      if (exam['id'] == examId) {
        final questionsJson = exam['questions'] as List<dynamic>? ?? [];
        return questionsJson
            .map(
              (json) => ExamQuestion.fromMap(Map<String, dynamic>.from(json)),
            )
            .toList();
      }
    }

    // Then check unlocked exams (from vouchers)
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];

    for (final examJson in unlockedExamsJson) {
      final exam = Map<String, dynamic>.from(jsonDecode(examJson));
      if (exam['id'] == examId) {
        final questionsJson = exam['questions'] as List<dynamic>? ?? [];
        return questionsJson
            .map(
              (json) => ExamQuestion.fromMap(Map<String, dynamic>.from(json)),
            )
            .toList();
      }
    }

    return [];
  }

  // Get exam questions from cloud storage (authenticated users)
  static Future<List<ExamQuestion>> _getExamQuestionsCloud(
    String userId,
    String examId,
  ) async {
    try {
      // First check user imported exams
      final importedDoc = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('imported')
          .doc(examId)
          .get();

      if (importedDoc.exists) {
        final exam = importedDoc.data()!;
        final questionsJson = exam['questions'] as List<dynamic>? ?? [];
        return questionsJson
            .map(
              (json) => ExamQuestion.fromMap(Map<String, dynamic>.from(json)),
            )
            .toList();
      }

      // Then check unlocked exams (from vouchers)
      final unlockedDoc = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('unlocked')
          .doc(examId)
          .get();

      if (unlockedDoc.exists) {
        final exam = unlockedDoc.data()!;
        final questionsJson = exam['questions'] as List<dynamic>? ?? [];
        return questionsJson
            .map(
              (json) => ExamQuestion.fromMap(Map<String, dynamic>.from(json)),
            )
            .toList();
      }

      return [];
    } catch (e) {
      Logger.error('Error getting exam questions from cloud: $e');
      return [];
    }
  }

  // Check if user has access to an exam
  static Future<bool> hasAccessToExam(String examId) async {
    try {
      final userExams = await getUserExams();
      return userExams.any((exam) => exam['id'] == examId);
    } catch (e) {
      Logger.error('Error checking exam access: $e');
      return false;
    }
  }

  // Remove user imported exam
  static Future<bool> removeUserImportedExam(String examId) async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.isAnonymous) {
        // Guest mode - remove from local storage
        return await _removeUserImportedExamLocal(examId);
      } else {
        // Authenticated user - remove from cloud
        return await _removeUserImportedExamCloud(user.uid, examId);
      }
    } catch (e) {
      Logger.error('Error removing user imported exam: $e');
      return false;
    }
  }

  // Remove user imported exam from local storage (guest mode)
  static Future<bool> _removeUserImportedExamLocal(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    final userImportedExamsJson =
        prefs.getStringList(_userImportedExamsKey) ?? [];

    final updatedExams = userImportedExamsJson.where((examJson) {
      final exam = Map<String, dynamic>.from(jsonDecode(examJson));
      return exam['id'] != examId;
    }).toList();

    await prefs.setStringList(_userImportedExamsKey, updatedExams);
    return true;
  }

  // Remove user imported exam from cloud storage (authenticated users)
  static Future<bool> _removeUserImportedExamCloud(
    String userId,
    String examId,
  ) async {
    try {
      await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('imported')
          .doc(examId)
          .delete();
      return true;
    } catch (e) {
      Logger.error('Error removing user imported exam from cloud: $e');
      return false;
    }
  }

  // Clean up expired exams (called periodically)
  static Future<void> cleanupExpiredExams() async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.isAnonymous) {
        // Guest mode - clean local storage
        await _cleanupExpiredExamsLocal();
      } else {
        // Authenticated user - clean cloud storage
        await _cleanupExpiredExamsCloud(user.uid);
      }
    } catch (e) {
      Logger.error('Error cleaning up expired exams: $e');
    }
  }

  // Clean up expired exams from local storage
  static Future<void> _cleanupExpiredExamsLocal() async {
    final prefs = await SharedPreferences.getInstance();

    // Clean unlocked exams
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];
    final validUnlockedExams = unlockedExamsJson.where((examJson) {
      final exam = Map<String, dynamic>.from(jsonDecode(examJson));
      return !_isExpired(exam);
    }).toList();

    if (validUnlockedExams.length != unlockedExamsJson.length) {
      await prefs.setStringList(_userExamsKey, validUnlockedExams);
    }
  }

  // Clean up expired exams from cloud storage
  static Future<void> _cleanupExpiredExamsCloud(String userId) async {
    try {
      final unlockedSnapshot = await _firestore
          .collection('user_exams')
          .doc(userId)
          .collection('unlocked')
          .get();

      final batch = _firestore.batch();

      for (final doc in unlockedSnapshot.docs) {
        final exam = doc.data();
        if (_isExpired(exam)) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
    } catch (e) {
      Logger.error('Error cleaning up expired exams from cloud: $e');
    }
  }
}
