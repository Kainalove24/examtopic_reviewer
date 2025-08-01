import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voucher.dart';
import '../models/exam_question.dart';
import '../services/user_exam_service.dart';
import '../services/firebase_voucher_service.dart';

class AdminService {
  // Voucher Management - Now only uses Firebase
  static Future<List<Voucher>> getVouchers() async {
    try {
      return await FirebaseVoucherService.getAllCloudVouchers();
    } catch (e) {
      print('Error getting vouchers: $e');
      return [];
    }
  }

  static Future<Voucher?> generateVoucher({
    String? name,
    String? examId,
    Duration? examExpiryDuration,
  }) async {
    try {
      print('Debug: generateVoucher called - name: $name, examId: $examId');

      // If examId is provided, verify it exists in Firebase
      if (examId != null) {
        print('Debug: Generating voucher for examId: $examId');

        // Check if exam exists in Firebase
        final examData = await FirebaseVoucherService.getExamFromCloud(examId);
        if (examData == null) {
          print('Debug: Exam not found in Firebase: $examId');
          return null;
        }

        print(
          'Debug: Exam found in Firebase - Title: ${examData['title']}, Questions: ${examData['questions']?.length ?? 0}',
        );
      } else {
        print('Debug: Generating general voucher (no examId)');
      }

      // Generate voucher with just the exam ID reference (no embedded data)
      final voucher = await FirebaseVoucherService.generateCloudVoucher(
        name: name,
        examId: examId, // Just the reference
        examData: null, // No embedded data
        examExpiryDuration: examExpiryDuration,
      );

      print(
        'Debug: Generated voucher - Code: ${voucher.code}, examId: ${voucher.examId}',
      );
      return voucher;
    } catch (e) {
      print('Error generating voucher: $e');
      return null;
    }
  }

  static Future<bool> validateVoucher(String code) async {
    try {
      final voucher = await FirebaseVoucherService.validateCloudVoucher(code);
      return voucher != null;
    } catch (e) {
      print('Error validating voucher: $e');
      return false;
    }
  }

  static Future<bool> useVoucher(String code, String userId) async {
    try {
      // Try cloud redemption
      final success = await FirebaseVoucherService.redeemCloudVoucher(
        code,
        userId,
      );

      if (success) {
        print(
          'Debug: Voucher redeemed successfully, getting voucher details...',
        );
        // Get voucher details to unlock exam if needed
        final voucher = await FirebaseVoucherService.getVoucherForUnlock(code);
        print('Debug: Voucher details - examId: ${voucher?.examId}');
        print('Debug: Voucher is null: ${voucher == null}');

        if (voucher != null && voucher.examId != null) {
          // Fetch exam data from Firebase using examId
          print(
            'Debug: Fetching exam data from Firebase for examId: ${voucher.examId}',
          );
          final examData = await FirebaseVoucherService.getExamFromCloud(
            voucher.examId!,
          );

          if (examData != null) {
            print(
              'Debug: Exam data fetched from Firebase - Title: ${examData['title']}, Questions: ${examData['questions']?.length ?? 0}',
            );

            // Unlock the exam using the fetched data
            final unlockResult = await UserExamService.unlockExam(
              voucher.examId!,
              examData,
              expiryDuration: voucher.examExpiryDuration,
            );
            print('Debug: Exam unlock result: $unlockResult');
          } else {
            print(
              'Debug: Failed to fetch exam data from Firebase for examId: ${voucher.examId}',
            );
          }
        } else {
          print('Debug: No examId found in voucher');
          print('Debug: Voucher examId: ${voucher?.examId}');
        }
      }

      return success;
    } catch (e) {
      print('Error using voucher: $e');
      return false;
    }
  }

  static Future<bool> deleteVoucher(String voucherId) async {
    try {
      return await FirebaseVoucherService.deleteCloudVoucher(voucherId);
    } catch (e) {
      print('Error deleting voucher: $e');
      return false;
    }
  }

  static Future<bool> updateVoucher(String voucherId, {String? name}) async {
    try {
      final vouchers = await getVouchers();
      final voucher = vouchers.firstWhere((v) => v.id == voucherId);

      final updatedVoucher = voucher.copyWith(name: name);
      return await FirebaseVoucherService.updateCloudVoucher(updatedVoucher);
    } catch (e) {
      print('Error updating voucher: $e');
      return false;
    }
  }

  // Share voucher for cross-browser/device access via URL
  static Future<String?> shareVoucher(String voucherId) async {
    try {
      final vouchers = await getVouchers();
      final voucher = vouchers.firstWhere(
        (v) => v.id == voucherId,
        orElse: () => Voucher(
          id: '',
          code: '',
          name: '',
          examId: null,
          createdDate: DateTime.now(),
          expiryDate: DateTime.now(),
        ),
      );

      if (voucher.id.isEmpty) return null;

      // Create a shareable URL with embedded voucher data
      final voucherData = {
        'voucher': voucher.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Encode the voucher data as base64 to make it URL-safe
      final jsonString = jsonEncode(voucherData);
      final base64Data = base64Encode(utf8.encode(jsonString));

      // Create the shareable URL
      final currentUrl = Uri.base.toString();
      final baseUrl = currentUrl.split(
        '?',
      )[0]; // Remove any existing query params
      final shareableUrl = '$baseUrl?voucher=$base64Data';

      print('Voucher ${voucher.code} shared via URL: $shareableUrl');
      return shareableUrl;
    } catch (e) {
      print('Error sharing voucher: $e');
      return null;
    }
  }

  // Check for voucher in URL parameters (for cross-browser/device redemption)
  static Future<Voucher?> getVoucherFromUrl() async {
    try {
      final uri = Uri.base;
      final voucherParam = uri.queryParameters['voucher'];

      if (voucherParam == null) return null;

      // Decode the base64 voucher data
      final decodedBytes = base64Decode(voucherParam);
      final jsonString = utf8.decode(decodedBytes);
      final voucherData = jsonDecode(jsonString) as Map<String, dynamic>;

      final voucher = Voucher.fromJson(voucherData['voucher']);

      // Validate the voucher against cloud
      final isValid = await validateVoucher(voucher.code);
      if (!isValid) {
        print('Voucher is invalid or expired');
        return null;
      }

      print('Found valid voucher in URL: ${voucher.code}');
      return voucher;
    } catch (e) {
      print('Error parsing voucher from URL: $e');
      return null;
    }
  }

  // Exam Management
  static Future<bool> importExam(
    String category,
    String examCode,
    List<ExamQuestion> questions,
  ) async {
    try {
      print('Debug: importExam - Starting import process');

      // Clean up the exam name by removing "CSV Import - " prefix if present
      String cleanExamName = examCode;
      if (examCode.startsWith('CSV Import - ')) {
        cleanExamName = examCode.substring('CSV Import - '.length);
        print('Debug: Cleaned exam name from "$examCode" to "$cleanExamName"');
      }

      // Create exam data structure
      final examData = {
        'id': 'exam_${DateTime.now().millisecondsSinceEpoch}',
        'title': cleanExamName, // Use the cleaned exam name
        'category': category,
        'examCode': examCode,
        'questionCount': questions.length,
        'importDate': DateTime.now().toIso8601String(),
        'questions': questions.map((q) => q.toMap()).toList(),
        'description': '',
        'metadata': {},
      };

      print('Debug: importExam - Storing exam in Firestore');

      // Store exam in Firestore only
      final examId = await FirebaseVoucherService.storeExamInCloud(examData);

      print('Debug: importExam - Exam stored with ID: $examId');
      print('Debug: importExam - Exam import completed successfully');
      return true;
    } catch (e) {
      print('Error importing exam: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getImportedExams() async {
    try {
      print('Debug: Fetching exams from Firestore...');
      // Fetch exams from Firestore only
      final cloudExams = await FirebaseVoucherService.getAllCloudExams();
      print('Debug: Found ${cloudExams.length} exams in Firestore');
      return cloudExams;
    } catch (e) {
      print('Error getting imported exams: $e');
      return [];
    }
  }

  static Future<bool> deleteExam(String examId) async {
    try {
      // Delete from Firestore only
      final cloudDeleteSuccess =
          await FirebaseVoucherService.deleteExamFromCloud(examId);
      return cloudDeleteSuccess;
    } catch (e) {
      print('Error deleting exam: $e');
      return false;
    }
  }

  // Get exam questions for a specific exam
  static Future<List<ExamQuestion>> getExamQuestions(String examId) async {
    // Get from Firestore only
    final cloudExam = await FirebaseVoucherService.getExamFromCloud(examId);
    if (cloudExam != null) {
      final questionsJson = cloudExam['questions'] as List<dynamic>? ?? [];
      return questionsJson
          .map((json) => ExamQuestion.fromMap(Map<String, dynamic>.from(json)))
          .toList();
    }

    return [];
  }

  // Get all available exams for users
  static Future<List<Map<String, dynamic>>> getAvailableExams() async {
    final importedExams = await getImportedExams();
    return importedExams
        .map(
          (exam) => {
            'id': exam['id'],
            'title':
                exam['title'] ??
                '${exam['category']} - ${exam['examCode']}', // Include title
            'category': exam['category'],
            'examCode': exam['examCode'],
            'questionCount': exam['questionCount'],
            'importDate': exam['importDate'],
          },
        )
        .toList();
  }

  // Update existing exam title in Firestore (for fixing old imports)
  static Future<bool> updateExamTitle(String examId, String newTitle) async {
    try {
      print('Debug: Updating exam title for $examId to "$newTitle"');

      // Update in Firestore only
      final success = await FirebaseVoucherService.updateExamInCloud(examId, {
        'title': newTitle,
      });

      if (success) {
        print('Debug: Successfully updated exam title in Firestore');
      }

      return success;
    } catch (e) {
      print('Error updating exam title: $e');
      return false;
    }
  }
}
