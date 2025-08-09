import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/exam_question.dart';
import '../models/imported_exam.dart';
import '../data/imported_exam_storage.dart';
import '../services/admin_service.dart';
import '../services/user_exam_service.dart';
import '../config/server_config.dart';

class CsvImportService {
  // Support both scraper format and custom format
  static const List<String> _scraperRequiredColumns = [
    'id',
    'type',
    'text',
    'question_images',
    'answer_images',
    'options',
    'answers',
    'explanation',
  ];

  static const List<String> _customRequiredColumns = [
    'id',
    'type',
    'text',
    'question_images',
    'answer_images',
    'options',
    'answers',
    'explanation',
  ];

  /// Pick and parse a CSV file
  static Future<Map<String, dynamic>> pickAndParseCsv() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null) {
        return {'success': false, 'error': 'No file selected'};
      }

      // Handle web platform differently
      String csvContent;
      if (result.files.single.bytes != null) {
        // Web platform - use bytes
        csvContent = utf8.decode(result.files.single.bytes!);
      } else {
        // Desktop/mobile platform - use file path
        final file = File(result.files.single.path!);
        csvContent = await file.readAsString();
      }

      return await parseCsvContent(csvContent);
    } catch (e) {
      return {'success': false, 'error': 'Error reading file: $e'};
    }
  }

  /// Parse CSV content and validate structure
  static Future<Map<String, dynamic>> parseCsvContent(String csvContent) async {
    try {
      final lines = csvContent.split('\n');
      if (lines.isEmpty) {
        return {'success': false, 'error': 'Empty CSV file'};
      }

      // Parse header
      final header = lines[0]
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();

      // Detect format (scraper vs custom)
      final isScraperFormat = _scraperRequiredColumns.every(
        (col) => header.contains(col),
      );
      final isCustomFormat = _customRequiredColumns.every(
        (col) => header.contains(col),
      );

      if (!isScraperFormat && !isCustomFormat) {
        return {
          'success': false,
          'error':
              'Invalid CSV format. Expected scraper format or custom format.',
          'scraper_required': _scraperRequiredColumns,
          'custom_required': _customRequiredColumns,
          'found_headers': header,
        };
      }

      // Parse data rows
      final questions = <ExamQuestion>[];
      final errors = <String>[];
      final imageConversionResults = <String>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final result = isScraperFormat
              ? await _parseScraperQuestionRow(line, header, i + 1)
              : await _parseCustomQuestionRow(line, header, i + 1);

          if (result['question'] != null) {
            questions.add(result['question']);
            if (result['image_conversions'] != null) {
              imageConversionResults.addAll(result['image_conversions']);
            }
          }
        } catch (e) {
          errors.add('Row ${i + 1}: $e');
        }
      }

      if (questions.isEmpty) {
        return {'success': false, 'error': 'No valid questions found in CSV'};
      }

      return {
        'success': true,
        'questions': questions,
        'total_rows': lines.length - 1,
        'valid_questions': questions.length,
        'errors': errors,
        'header': header,
        'format': isScraperFormat ? 'scraper' : 'custom',
        'image_conversions': imageConversionResults,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error parsing CSV: $e'};
    }
  }

  /// Parse a scraper format question row
  static Future<Map<String, dynamic>> _parseScraperQuestionRow(
    String line,
    List<String> header,
    int rowNumber,
  ) async {
    // Handle CSV with commas in quoted fields
    final values = _parseCsvLine(line);

    if (values.length < header.length) {
      throw 'Insufficient columns (expected ${header.length}, got ${values.length})';
    }

    // Create map of column name to value
    final rowData = <String, String>{};
    for (int i = 0; i < header.length && i < values.length; i++) {
      rowData[header[i]] = values[i].trim();
    }

    // Extract fields
    final id = int.tryParse(rowData['id'] ?? '') ?? rowNumber;
    final type = rowData['type'] ?? 'mcq';
    final text = rowData['text'] ?? '';
    final questionImagesStr = rowData['question_images'] ?? '';
    final answerImagesStr = rowData['answer_images'] ?? '';
    final optionsStr = rowData['options'] ?? '';
    final answersStr = rowData['answers'] ?? '';
    final explanation = rowData['explanation'] ?? '';

    // Validate required fields
    if (text.isEmpty) {
      throw 'Question text is required';
    }

    // Parse images and convert URLs to Base64
    final questionImages = <String>[];
    final answerImages = <String>[];
    final imageConversions = <String>[];

    // Process question images
    if (questionImagesStr.isNotEmpty) {
      print('Processing question images: $questionImagesStr');
      final urls = questionImagesStr
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      print('Found ${urls.length} image URLs to process');
      for (final url in urls) {
        print('Processing image URL: $url');
        if (url.startsWith('http')) {
          // Convert URL to Base64
          final base64Result = await _convertImageUrlToBase64(url);
          if (base64Result['success']) {
            questionImages.add(base64Result['base64']);
            imageConversions.add('Converted: $url');
            print('Successfully converted image: $url');
          } else {
            // Keep original URL if conversion fails - this will work as a network image
            questionImages.add(url);
            imageConversions.add(
              'Failed to convert: $url (${base64Result['error']}) - keeping as network URL',
            );
            print(
              'Failed to convert image: $url - ${base64Result['error']} - keeping as network URL',
            );
          }
        } else if (url.startsWith('data:image')) {
          // Already Base64
          questionImages.add(url);
          print('Image already in Base64 format: $url');
        } else {
          // Local file or other format
          questionImages.add(url);
          print('Added local image: $url');
        }
      }
    }

    // Process answer images
    if (answerImagesStr.isNotEmpty) {
      final urls = answerImagesStr
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final url in urls) {
        if (url.startsWith('http')) {
          // Convert URL to Base64
          final base64Result = await _convertImageUrlToBase64(url);
          if (base64Result['success']) {
            answerImages.add(base64Result['base64']);
            imageConversions.add('Converted: $url');
          } else {
            // Keep original URL if conversion fails
            answerImages.add(url);
            imageConversions.add(
              'Failed to convert: $url (${base64Result['error']})',
            );
          }
        } else if (url.startsWith('data:image')) {
          // Already Base64
          answerImages.add(url);
        } else {
          // Local file or other format
          answerImages.add(url);
        }
      }
    }

    // Parse options
    final options = optionsStr
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Parse answers and convert letter answers to full text
    final rawAnswers = answersStr
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Convert letter answers (A, B, C, D) to full option text
    final answers = <String>[];
    for (final answer in rawAnswers) {
      // Handle multiple letter answers separated by | (e.g., "A|B")
      if (answer.contains('|')) {
        final letterAnswers = answer.split('|');
        for (final letterAnswer in letterAnswers) {
          final trimmedLetter = letterAnswer.trim();
          if (trimmedLetter.length == 1 &&
              RegExp(r'^[A-Z]$').hasMatch(trimmedLetter)) {
            // This is a letter answer, find the corresponding option
            final optionIndex = trimmedLetter.codeUnitAt(0) - 'A'.codeUnitAt(0);
            if (optionIndex >= 0 && optionIndex < options.length) {
              answers.add(options[optionIndex]);
            } else {
              // If option not found, keep the letter
              answers.add(trimmedLetter);
            }
          } else {
            // This is already full text, keep as is
            answers.add(trimmedLetter);
          }
        }
      } else if (answer.length == 1 && RegExp(r'^[A-Z]$').hasMatch(answer)) {
        // Single letter answer
        final optionIndex = answer.codeUnitAt(0) - 'A'.codeUnitAt(0);
        if (optionIndex >= 0 && optionIndex < options.length) {
          answers.add(options[optionIndex]);
        } else {
          // If option not found, keep the letter
          answers.add(answer);
        }
      } else if (answer.length > 1 && RegExp(r'^[A-Z]+$').hasMatch(answer)) {
        // Multiple letters without separator (e.g., "DCA")
        for (int i = 0; i < answer.length; i++) {
          final letter = answer[i];
          final optionIndex = letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
          if (optionIndex >= 0 && optionIndex < options.length) {
            answers.add(options[optionIndex]);
          } else {
            // If option not found, keep the letter
            answers.add(letter);
          }
        }
      } else {
        // This is already full text, keep as is
        answers.add(answer);
      }
    }

    return {
      'question': ExamQuestion(
        id: id,
        type: type,
        text: text,
        questionImages: questionImages,
        answerImages: answerImages,
        options: options,
        answers: answers,
        explanation: explanation.isEmpty ? null : explanation,
      ),
      'image_conversions': imageConversions,
    };
  }

  /// Parse a custom format question row (now same as scraper format)
  static Future<Map<String, dynamic>> _parseCustomQuestionRow(
    String line,
    List<String> header,
    int rowNumber,
  ) async {
    // Use the same parsing logic as scraper format
    return await _parseScraperQuestionRow(line, header, rowNumber);
  }

  /// Convert image URL using the image processing server
  static Future<Map<String, dynamic>> _convertImageUrlToBase64(
    String imageUrl,
  ) async {
    try {
      print('Processing image URL through server: $imageUrl');

      // Use the image processing server
      final response = await http
          .post(
            Uri.parse(ServerConfig.processImagesUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imageUrls': [imageUrl],
            }),
          )
          .timeout(ServerConfig.requestTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;

        if (result['success'] == true && result['processedImages'] != null) {
          final processedImages = result['processedImages'] as List;
          if (processedImages.isNotEmpty) {
            final processedUrl = ServerConfig.getProcessedImageUrl(
              processedImages.first,
            );
            print('Successfully processed image: $processedUrl');
            return {'success': true, 'base64': processedUrl, 'size_bytes': 0};
          }
        }

        // If server processing failed, return error
        final errors = result['errors'] as List? ?? [];
        final errorMsg = errors.isNotEmpty
            ? errors.first
            : 'Unknown server error';
        print('Server processing failed: $errorMsg');
        return {'success': false, 'error': errorMsg};
      } else {
        print('Failed to process image: HTTP ${response.statusCode}');
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('Error processing image URL: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse CSV line handling quoted fields with commas
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    String current = '';
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }

    result.add(current);
    return result;
  }

  /// Import questions to exam storage
  static Future<Map<String, dynamic>> importQuestionsToExam(
    String examName,
    String category,
    List<ExamQuestion> questions,
  ) async {
    try {
      // Create imported exam object
      final importedExam = ImportedExam(
        id: 'csv_${DateTime.now().millisecondsSinceEpoch}',
        title: examName,
        filename: 'csv_import_${DateTime.now().millisecondsSinceEpoch}.csv',
        importedAt: DateTime.now(),
      );

      // Import to storage
      await ImportedExamStorage.addExam(importedExam);

      // Also save to AdminService for admin portal access
      await AdminService.importExam(
        category,
        examName, // Use the custom exam name instead of the generated ID
        questions,
      );

      // Also save to UserExamService for user access
      final examData = {
        'id': importedExam.id,
        'title': examName,
        'questions': questions.map((q) => q.toMap()).toList(),
        'questionCount': questions.length,
        'category': category,
        'importDate': DateTime.now().toIso8601String(),
      };

      await UserExamService.addUserImportedExam(examData);

      return {
        'success': true,
        'message': 'Successfully imported ${questions.length} questions',
        'exam': importedExam,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error importing exam: $e'};
    }
  }

  /// Get CSV template for download
  static String getCsvTemplate() {
    final headers = [..._scraperRequiredColumns];
    final template = [
      headers.join(','),
      '1,mcq,"What is the capital of France?",,,A. Paris|B. London|C. Berlin|D. Madrid,A,Paris is the capital of France',
      '2,hotspot,"HOTSPOT - Select the correct answer",https://example.com/image1.png,https://example.com/image2.png,Option A|Option B|Option C|Option D,A|B,Explanation here',
    ].join('\n');

    return template;
  }

  /// Validate CSV structure without importing
  static Future<Map<String, dynamic>> validateCsvStructure(
    String csvContent,
  ) async {
    final result = await parseCsvContent(csvContent);

    if (!result['success']) {
      return result;
    }

    final questions = result['questions'] as List<ExamQuestion>;
    final errors = result['errors'] as List<String>;
    final imageConversions = result['image_conversions'] as List<String>? ?? [];

    return {
      'success': true,
      'valid_questions': questions.length,
      'total_errors': errors.length,
      'errors': errors,
      'image_conversions': imageConversions,
      'sample_question': questions.isNotEmpty ? questions.first : null,
      'format': result['format'],
    };
  }
}
