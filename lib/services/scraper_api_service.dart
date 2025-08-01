import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exam_question.dart';

class ScraperApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get available categories
  static Future<Map<String, String>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, String>.from(data['categories']);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Get exams for a category
  static Future<List<String>> getExamsForCategory(String category) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/exams/$category'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['exams']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Start scraping job
  static Future<Map<String, dynamic>> startScraping(
    String category,
    String examCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scrape'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'category': category, 'exam_code': examCode}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        return {'error': error['error']};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // Get job status
  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/job/$jobId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        return {'error': error['error']};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // List all jobs
  static Future<List<Map<String, dynamic>>> listJobs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/jobs'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['jobs']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Download CSV for completed job
  static Future<String?> downloadCsv(String jobId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/download/$jobId'));
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Clean up job
  static Future<bool> cleanupJob(String jobId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/cleanup/$jobId'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Convert CSV content to ExamQuestion list
  static List<ExamQuestion> parseCsvContent(String csvContent) {
    final lines = csvContent.split('\n');
    if (lines.length < 2) return [];

    final headers = lines[0].split(',');
    final questions = <ExamQuestion>[];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = lines[i].split(',');
      if (values.length < headers.length) continue;

      final Map<String, String> row = {};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j];
      }

      try {
        final question = ExamQuestion.fromCsv(row);
        questions.add(question);
      } catch (e) {
        print('Error parsing question: $e');
      }
    }

    return questions;
  }

  // Complete workflow: start scraping and wait for completion
  static Future<List<ExamQuestion>> scrapeExamData(
    String category,
    String examCode,
  ) async {
    // Step 1: Start scraping job
    final startResult = await startScraping(category, examCode);
    if (startResult.containsKey('error')) {
      throw Exception(startResult['error']);
    }

    final jobId = startResult['job_id'];

    // Step 2: Poll for completion
    while (true) {
      await Future.delayed(Duration(seconds: 2));

      final status = await getJobStatus(jobId);
      if (status.containsKey('error')) {
        throw Exception(status['error']);
      }

      if (status['status'] == 'completed') {
        // Step 3: Get CSV content
        final csvContent = status['result']['csv_content'];
        if (csvContent != null) {
          return parseCsvContent(csvContent);
        } else {
          throw Exception('No CSV content received');
        }
      } else if (status['status'] == 'failed') {
        throw Exception(status['error'] ?? 'Scraping failed');
      }

      // Continue polling
    }
  }
}
