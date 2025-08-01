import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_question.dart';

class CloudExamService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference get _examsCollection =>
      _firestore.collection('exams');

  /// Upload an exam to the cloud
  static Future<String> uploadExam({
    required String title,
    required String category,
    required String examCode,
    required List<ExamQuestion> questions,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final examData = {
        'title': title,
        'category': category,
        'examCode': examCode,
        'questionCount': questions.length,
        'questions': questions.map((q) => q.toMap()).toList(),
        'description': description,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      };

      final docRef = await _examsCollection.add(examData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to upload exam to cloud: $e');
    }
  }

  /// Download an exam from the cloud
  static Future<Map<String, dynamic>?> downloadExam(String examId) async {
    try {
      final doc = await _examsCollection.doc(examId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      print('Error downloading exam from cloud: $e');
      return null;
    }
  }

  /// Get all exams from the cloud
  static Future<List<Map<String, dynamic>>> getAllExams() async {
    try {
      final querySnapshot = await _examsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error getting all exams from cloud: $e');
      return [];
    }
  }

  /// Search exams by category
  static Future<List<Map<String, dynamic>>> searchExamsByCategory(
    String category,
  ) async {
    try {
      final querySnapshot = await _examsCollection
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error searching exams by category: $e');
      return [];
    }
  }

  /// Update an exam in the cloud
  static Future<bool> updateExam(
    String examId, {
    String? title,
    String? category,
    String? examCode,
    List<ExamQuestion>? questions,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updateData['title'] = title;
      if (category != null) updateData['category'] = category;
      if (examCode != null) updateData['examCode'] = examCode;
      if (questions != null) {
        updateData['questions'] = questions.map((q) => q.toMap()).toList();
        updateData['questionCount'] = questions.length;
      }
      if (description != null) updateData['description'] = description;
      if (metadata != null) updateData['metadata'] = metadata;

      await _examsCollection.doc(examId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating exam in cloud: $e');
      return false;
    }
  }

  /// Delete an exam from the cloud
  static Future<bool> deleteExam(String examId) async {
    try {
      await _examsCollection.doc(examId).delete();
      return true;
    } catch (e) {
      print('Error deleting exam from cloud: $e');
      return false;
    }
  }

  /// Get exam statistics
  static Future<Map<String, int>> getExamStats() async {
    try {
      final totalExams = await _examsCollection.count().get();

      // Get unique categories
      final categoriesSnapshot = await _examsCollection.get();
      final categories = <String>{};
      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        categories.add(data['category'] ?? 'Unknown');
      }

      return {'total': totalExams.count ?? 0, 'categories': categories.length};
    } catch (e) {
      print('Error getting exam stats: $e');
      return {'total': 0, 'categories': 0};
    }
  }

  /// Convert exam data to ExamQuestion objects
  static List<ExamQuestion> parseExamQuestions(Map<String, dynamic> examData) {
    try {
      final questionsList = examData['questions'] as List<dynamic>? ?? [];
      return questionsList
          .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList();
    } catch (e) {
      print('Error parsing exam questions: $e');
      return [];
    }
  }

  /// Validate exam data structure
  static bool validateExamData(Map<String, dynamic> examData) {
    try {
      final requiredFields = ['title', 'category', 'examCode', 'questions'];
      for (final field in requiredFields) {
        if (!examData.containsKey(field)) {
          return false;
        }
      }

      final questions = examData['questions'] as List<dynamic>?;
      if (questions == null || questions.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
