import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Simple test script to debug voucher workflow
void main() async {
  print('🔍 Testing Voucher Workflow...');

  // Test 1: Check if exams are properly imported
  await testExamImport();

  // Test 2: Check if vouchers are generated with exam data
  await testVoucherGeneration();

  // Test 3: Check if exams are unlocked properly
  await testExamUnlock();

  // Test 4: Check data format compatibility
  await testDataFormatCompatibility();

  print('✅ Voucher workflow test completed');
}

Future<void> testExamImport() async {
  print('\n📚 Test 1: Exam Import');

  final prefs = await SharedPreferences.getInstance();
  final importedExamsJson = prefs.getStringList('admin_imported_exams') ?? [];

  print('Found ${importedExamsJson.length} imported exams');

  for (final examJson in importedExamsJson) {
    final exam = Map<String, dynamic>.from(jsonDecode(examJson));
    print(
      'Exam: ${exam['id']} - ${exam['title'] ?? 'No title'} - Questions: ${exam['questions']?.length ?? 0}',
    );

    // Check question format
    if (exam['questions'] != null && (exam['questions'] as List).isNotEmpty) {
      final firstQuestion = (exam['questions'] as List).first;
      print('  First question type: ${firstQuestion.runtimeType}');
      if (firstQuestion is Map<String, dynamic>) {
        print('  First question keys: ${firstQuestion.keys.toList()}');
      }
    }
  }
}

Future<void> testVoucherGeneration() async {
  print('\n🎫 Test 2: Voucher Generation');

  final prefs = await SharedPreferences.getInstance();
  final vouchersJson = prefs.getStringList('vouchers') ?? [];

  print('Found ${vouchersJson.length} vouchers in local storage');

  // Note: Cloud vouchers are stored in Firebase, not local storage
  print('Note: Cloud vouchers are stored in Firebase Firestore');
}

Future<void> testExamUnlock() async {
  print('\n🔓 Test 3: Exam Unlock');

  final prefs = await SharedPreferences.getInstance();
  final unlockedExamsJson = prefs.getStringList('user_unlocked_exams') ?? [];

  print('Found ${unlockedExamsJson.length} unlocked exams');

  for (final examJson in unlockedExamsJson) {
    final exam = Map<String, dynamic>.from(jsonDecode(examJson));
    print(
      'Unlocked Exam: ${exam['id']} - ${exam['title'] ?? 'No title'} - Type: ${exam['type']}',
    );

    // Check question format
    if (exam['questions'] != null && (exam['questions'] as List).isNotEmpty) {
      final firstQuestion = (exam['questions'] as List).first;
      print('  First question type: ${firstQuestion.runtimeType}');
      if (firstQuestion is Map<String, dynamic>) {
        print('  First question keys: ${firstQuestion.keys.toList()}');
      }
    }
  }
}

Future<void> testDataFormatCompatibility() async {
  print('\n🔧 Test 4: Data Format Compatibility');

  // Test the ExamQuestion.fromMap method with sample data
  final sampleQuestion = {
    'id': 1,
    'type': 'multiple_choice',
    'text': 'What is AWS?',
    'question_images': [],
    'answer_images': [],
    'options': ['A', 'B', 'C', 'D'],
    'answers': ['A'],
    'explanation': 'AWS is Amazon Web Services',
    'ai_explanation': null,
  };

  try {
    // Import the ExamQuestion model for testing
    // This would need to be done in a proper test environment
    print('Sample question structure: $sampleQuestion');
    print('Sample question keys: ${sampleQuestion.keys.toList()}');
  } catch (e) {
    print('Error testing data format: $e');
  }
}
