import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('Testing offline image functionality...');

  // Test data - sample exam questions with images
  final testQuestions = [
    {
      'id': 1,
      'text': 'What is AWS Lambda?',
      'question_images': [
        'https://img.examtopics.com/aws-certified-ai-practitioner-aif-c01/image1.png',
        'https://img.examtopics.com/aws-certified-ai-practitioner-aif-c01/image2.png',
      ],
      'answer_images': [
        'https://img.examtopics.com/aws-certified-ai-practitioner-aif-c01/image3.png',
      ],
      'options': [
        'A. Serverless compute',
        'B. Database service',
        'C. Storage service',
      ],
      'answers': ['A'],
    },
    {
      'id': 2,
      'text': 'What is Amazon S3?',
      'question_images': [
        'https://img.examtopics.com/aws-certified-ai-practitioner-aif-c01/image4.png',
      ],
      'answer_images': [],
      'options': [
        'A. Compute service',
        'B. Object storage',
        'C. Database service',
      ],
      'answers': ['B'],
    },
  ];

  try {
    // Test 1: Check if images can be downloaded
    print('\n📥 Test 1: Downloading images...');
    final allImageUrls = <String>{};

    for (final question in testQuestions) {
      if (question['question_images'] != null) {
        final questionImages = question['question_images'] as List?;
        if (questionImages != null) {
          for (final image in questionImages) {
            if (image is String &&
                image.isNotEmpty &&
                image.startsWith('http')) {
              allImageUrls.add(image);
            }
          }
        }
      }

      if (question['answer_images'] != null) {
        final answerImages = question['answer_images'] as List?;
        if (answerImages != null) {
          for (final image in answerImages) {
            if (image is String &&
                image.isNotEmpty &&
                image.startsWith('http')) {
              allImageUrls.add(image);
            }
          }
        }
      }
    }

    print('Found ${allImageUrls.length} images to download');

    // Test 2: Download each image
    int successCount = 0;
    for (final imageUrl in allImageUrls) {
      try {
        print('⬇️ Downloading: ${path.basename(imageUrl)}');

        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          print(
            '✅ Downloaded: ${path.basename(imageUrl)} (${response.bodyBytes.length} bytes)',
          );
          successCount++;
        } else {
          print(
            '❌ Failed to download: ${path.basename(imageUrl)} (HTTP ${response.statusCode})',
          );
        }
      } catch (e) {
        print('❌ Error downloading ${path.basename(imageUrl)}: $e');
      }
    }

    print('\n📊 Download Results:');
    print('  Total images: ${allImageUrls.length}');
    print('  Successfully downloaded: $successCount');
    print('  Failed: ${allImageUrls.length - successCount}');

    // Test 3: Check local storage
    print('\n📁 Test 3: Checking local storage...');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));

      if (await imagesDir.exists()) {
        final files = await imagesDir.list().toList();
        print('  Local images directory exists');
        print('  Files in directory: ${files.length}');

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            print('    ${path.basename(file.path)}: ${stat.size} bytes');
          }
        }
      } else {
        print('  Local images directory does not exist');
      }
    } catch (e) {
      print('❌ Error checking local storage: $e');
    }

    print('\n✅ Offline image test complete!');
  } catch (e) {
    print('❌ Error in offline image test: $e');
  }
}
