import 'dart:async';
import '../models/exam_question.dart';
import '../providers/exam_provider.dart';
import '../services/user_exam_service.dart';
import '../services/admin_service.dart';
import '../services/library_cache_service.dart';
import '../providers/progress_provider.dart';

class OptimizedLibraryService {
  // Load all library data in parallel with caching
  static Future<Map<String, dynamic>> loadLibraryData({
    bool forceRefresh = false,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Try to get cached data first
      if (useCache && !forceRefresh) {
        final cachedData = await LibraryCacheService.getCachedLibraryData();
        if (cachedData != null) {
          return cachedData;
        }
      }

      // Load all data sources in parallel
      final futures = await Future.wait([
        _loadUserExams(),
        _loadAdminExams(),
        _loadProgressData(),
      ]);

      final userExams = futures[0] as List<Map<String, dynamic>>;
      final adminExams = futures[1] as List<Map<String, dynamic>>;
      final progressData = futures[2] as Map<String, dynamic>;

      // Process and combine all exams
      final allExams = await _processAndCombineExams(
        userExams,
        adminExams,
      );

      // Create result data
      final result = {
        'exams': allExams,
        'userExams': userExams,
        'adminExams': adminExams,
        'progressData': progressData,
        'totalExams': allExams.length,
        'loadTime': stopwatch.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Cache the result
      await LibraryCacheService.cacheLibraryData(result);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Load user exams
  static Future<List<Map<String, dynamic>>> _loadUserExams() async {
    try {
      return await UserExamService.getUserExams();
    } catch (e) {
      return [];
    }
  }

  // Load admin exams
  static Future<List<Map<String, dynamic>>> _loadAdminExams() async {
    try {
      return await AdminService.getImportedExams();
    } catch (e) {
      return [];
    }
  }

  // Load progress data for all exams
  static Future<Map<String, dynamic>> _loadProgressData() async {
    try {
      // This will be populated as exams are processed
      return {};
    } catch (e) {
      return {};
    }
  }

  // Process and combine all exams
  static Future<List<ExamEntry>> _processAndCombineExams(
    List<Map<String, dynamic>> userExams,
    List<Map<String, dynamic>> adminExams,
  ) async {
    final allExams = <ExamEntry>[];

    // Add admin imported exams
    for (final adminExam in adminExams) {
      try {
        final questionsJson = adminExam['questions'] as List<dynamic>? ?? [];
        final questions = questionsJson.map((json) {
          return ExamQuestion.fromMap(Map<String, dynamic>.from(json));
        }).toList();

        allExams.add(
          ExamEntry(
            id: adminExam['id'] as String,
            title: adminExam['title'] as String,
            questions: questions,
          ),
        );
      } catch (e) {
        // Error processing admin exam
      }
    }

    // Add user exams
    for (final userExam in userExams) {
      try {
        final questionsJson = userExam['questions'] as List<dynamic>? ?? [];
        final questions = questionsJson.map((json) {
          return ExamQuestion.fromMap(Map<String, dynamic>.from(json));
        }).toList();

        String title =
            userExam['title'] as String? ??
            '${userExam['category'] ?? 'Unknown'} - ${userExam['examCode'] ?? 'Unknown'}';

        String examId =
            userExam['id'] as String? ??
            'unknown_${DateTime.now().millisecondsSinceEpoch}';

        // Check for duplicates
        final isDuplicate = allExams.any((exam) => exam.id == examId);
        if (!isDuplicate) {
          allExams.add(
            ExamEntry(id: examId, title: title, questions: questions),
          );
        }
      } catch (e) {
        // Error processing user exam
      }
    }

    return allExams;
  }

  // Load progress for specific exam
  static Future<Map<String, dynamic>> loadExamProgress(String examId) async {
    try {
      final progressProvider = ProgressProvider();
      await progressProvider.loadProgress(examId);

      final progress = progressProvider.progress;
      final masteredList =
          (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];

      return {
        'examId': examId,
        'masteredCount': masteredList.length,
        'totalQuestions': 0, // Will be set by caller
        'progress': progress,
      };
    } catch (e) {
      return {
        'examId': examId,
        'masteredCount': 0,
        'totalQuestions': 0,
        'progress': {},
      };
    }
  }

  // Force refresh library data
  static Future<Map<String, dynamic>> forceRefresh() async {
    await LibraryCacheService.invalidateCache();
    return await loadLibraryData(forceRefresh: true);
  }

  // Get cache status
  static Map<String, dynamic> getCacheStatus() {
    final isValid = LibraryCacheService.isCacheValid();
    final age = LibraryCacheService.getCacheAge();

    return {
      'isValid': isValid,
      'age': age?.inSeconds ?? 0,
      'ageMinutes': age?.inMinutes ?? 0,
    };
  }
}
