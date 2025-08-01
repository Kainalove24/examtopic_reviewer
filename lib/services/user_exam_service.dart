import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exam_question.dart';

class UserExamService {
  static const String _userExamsKey = 'user_unlocked_exams';
  static const String _userImportedExamsKey = 'user_imported_exams';

  // Firebase instances
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all exams user has access to (built-in + unlocked + imported)
  static Future<List<Map<String, dynamic>>> getUserExams() async {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      // Guest mode - use local storage only
      print('Debug: getUserExams - Guest mode, using local storage');
      return _getLocalUserExams();
    } else {
      // Authenticated user - sync with cloud and merge with local
      print('Debug: getUserExams - Authenticated user, syncing with cloud storage');
      return await _getCloudUserExamsWithLocalSync(user.uid);
    }
  }

  // Get exams from local storage (guest mode)
  static Future<List<Map<String, dynamic>>> _getLocalUserExams() async {
    final prefs = await SharedPreferences.getInstance();

    // Get unlocked exams (from vouchers)
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];
    print(
      'Debug: _getLocalUserExams - Found ${unlockedExamsJson.length} unlocked exams in local storage',
    );

    final unlockedExams = unlockedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .where((exam) => !_isExpired(exam)) // Filter out expired exams
        .toList();

    print(
      'Debug: _getLocalUserExams - After filtering expired: ${unlockedExams.length} unlocked exams',
    );

    // Get user imported exams
    final userImportedExamsJson =
        prefs.getStringList(_userImportedExamsKey) ?? [];
    final userImportedExams = userImportedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    // Combine all exams
    final allExams = [...unlockedExams, ...userImportedExams];
    print(
      'Debug: _getLocalUserExams - Total exams returned: ${allExams.length}',
    );

    // Debug: Print exam details
    for (final exam in allExams) {
      print(
        'Debug: Exam - ID: ${exam['id']}, Title: ${exam['title']}, Type: ${exam['type']}',
      );
    }

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
      print('Error getting cloud user exams: $e');
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
      print('Debug: Found ${cloudExams.length} exams in cloud storage');

      // Get local exams
      final localExams = await _getLocalUserExams();
      print('Debug: Found ${localExams.length} exams in local storage');

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
          print('Debug: Adding local exam to cloud: ${localExam['title']}');
          // Upload local exam to cloud
          await _uploadLocalExamToCloud(userId, localExam);
          mergedExams.add(localExam);
        }
      }

      print('Debug: Total merged exams: ${mergedExams.length}');
      return mergedExams;
    } catch (e) {
      print('Error syncing cloud and local exams: $e');
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
      print('Error uploading local exam to cloud: $e');
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
      print('Error parsing expiry date: $e');
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
      print('Debug: unlockExam called - examId: $examId');
      print('Debug: examData keys: ${examData.keys.toList()}');
      print('Debug: examData title: ${examData['title']}');
      print(
        'Debug: examData questions count: ${examData['questions']?.length ?? 0}',
      );

      final user = _auth.currentUser;
      final expiryDate = expiryDuration != null
          ? DateTime.now().add(expiryDuration).toIso8601String()
          : null;

      if (user == null || user.isAnonymous) {
        // Guest mode - use local storage
        print('Debug: Using local storage for exam unlock');
        return await _unlockExamLocal(examId, examData, expiryDate);
      } else {
        // Authenticated user - use cloud storage
        print('Debug: Using cloud storage for exam unlock');
        return await _unlockExamCloud(user.uid, examId, examData, expiryDate);
      }
    } catch (e) {
      print('Error unlocking exam: $e');
      return false;
    }
  }

  // Unlock exam in local storage (guest mode)
  static Future<bool> _unlockExamLocal(
    String examId,
    Map<String, dynamic> examData,
    String? expiryDate,
  ) async {
    print('Debug: _unlockExamLocal called - examId: $examId');
    print('Debug: examData keys: ${examData.keys.toList()}');
    print('Debug: examData title: ${examData['title']}');
    print(
      'Debug: examData questions count: ${examData['questions']?.length ?? 0}',
    );

    final prefs = await SharedPreferences.getInstance();
    final unlockedExamsJson = prefs.getStringList(_userExamsKey) ?? [];

    // Check if exam is already unlocked
    final existingExams = unlockedExamsJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    if (existingExams.any((exam) => exam['id'] == examId)) {
      print('Debug: Exam already unlocked: $examId');
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

    print('Debug: Saving exam to local storage: ${examToUnlock['title']}');
    print('Debug: Exam data to save: ${examToUnlock.keys.toList()}');
    print(
      'Debug: Questions data type: ${examToUnlock['questions']?.runtimeType}',
    );
    print('Debug: Questions count: ${examToUnlock['questions']?.length ?? 0}');

    // Debug: Print first question structure
    if (examToUnlock['questions'] != null &&
        (examToUnlock['questions'] as List).isNotEmpty) {
      print(
        'Debug: First question structure: ${(examToUnlock['questions'] as List).first}',
      );
    }

    unlockedExamsJson.add(jsonEncode(examToUnlock));
    await prefs.setStringList(_userExamsKey, unlockedExamsJson);

    print('Debug: Exam successfully unlocked and saved to local storage');
    return true;
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
      print('Error unlocking exam in cloud: $e');
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
      print('Error adding user imported exam: $e');
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
      print('Error adding user imported exam to cloud: $e');
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
      print('Error getting exam questions: $e');
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
      print('Error getting exam questions from cloud: $e');
      return [];
    }
  }

  // Check if user has access to an exam
  static Future<bool> hasAccessToExam(String examId) async {
    try {
      final userExams = await getUserExams();
      return userExams.any((exam) => exam['id'] == examId);
    } catch (e) {
      print('Error checking exam access: $e');
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
      print('Error removing user imported exam: $e');
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
      print('Error removing user imported exam from cloud: $e');
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
      print('Error cleaning up expired exams: $e');
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
      print('Error cleaning up expired exams from cloud: $e');
    }
  }
}
