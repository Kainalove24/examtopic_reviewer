import 'package:flutter/material.dart';
import '../models/exam_question.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExamEntry {
  final String id;
  final String title;
  final List<ExamQuestion> questions;
  ExamEntry({required this.id, required this.title, required this.questions});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory ExamEntry.fromMap(Map<String, dynamic> map) {
    return ExamEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      questions: (map['questions'] as List)
          .map((q) => ExamQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExamProvider extends ChangeNotifier {
  final List<ExamEntry> _exams = [];

  List<ExamEntry> get exams => List.unmodifiable(_exams);

  void addExam(ExamEntry exam) {
    _exams.add(exam);
    notifyListeners();
  }

  void setExams(List<ExamEntry> exams) {
    _exams.clear();
    _exams.addAll(exams);
    notifyListeners();
  }

  ExamEntry? getExamById(String id) {
    for (final e in _exams) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> updateExamQuestions(
    String examId,
    List<Map<String, dynamic>> questions,
  ) async {
    final examIndex = _exams.indexWhere((e) => e.id == examId);
    if (examIndex != -1) {
      final exam = _exams[examIndex];
      final updatedQuestions = questions
          .map((q) => ExamQuestion.fromMap(q))
          .toList();
      _exams[examIndex] = ExamEntry(
        id: exam.id,
        title: exam.title,
        questions: updatedQuestions,
      );
      notifyListeners();
      await saveAllExams();
    }
  }

  // Update AI explanation for a specific question
  Future<void> updateQuestionAIExplanation(
    String examId,
    int questionIndex,
    String aiExplanation,
  ) async {
    final examIndex = _exams.indexWhere((e) => e.id == examId);
    if (examIndex != -1) {
      final exam = _exams[examIndex];
      if (questionIndex >= 0 && questionIndex < exam.questions.length) {
        final updatedQuestions = List<ExamQuestion>.from(exam.questions);
        updatedQuestions[questionIndex] = updatedQuestions[questionIndex]
            .copyWith(aiExplanation: aiExplanation);

        _exams[examIndex] = ExamEntry(
          id: exam.id,
          title: exam.title,
          questions: updatedQuestions,
        );
        notifyListeners();
        await saveAllExams();

        print(
          'AI explanation saved for question $questionIndex in exam $examId',
        );
      }
    }
  }

  // Get AI explanation for a specific question
  String? getQuestionAIExplanation(String examId, int questionIndex) {
    final exam = getExamById(examId);
    if (exam != null &&
        questionIndex >= 0 &&
        questionIndex < exam.questions.length) {
      return exam.questions[questionIndex].aiExplanation;
    }
    return null;
  }

  // Persistent storage for all exams
  static const String _storageKey = 'persisted_exams';

  Future<void> saveAllExams() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _exams.map((e) => e.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> loadAllExams() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final List data = jsonDecode(raw);
    setExams(data.map((e) => ExamEntry.fromMap(e)).toList());
  }
}
