import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing hosted image processing server...');

  final serverUrl = 'https://image-processing-server-0ski.onrender.com';
  final testImageUrl =
      'https://img.examtopics.com/aws-certified-ai-practitioner-aif-c01/image1.png';

  try {
    // Test health check
    print('Testing health check...');
    final healthResponse = await http
        .get(Uri.parse('$serverUrl/api/health'))
        .timeout(const Duration(seconds: 10));

    if (healthResponse.statusCode == 200) {
      print('✅ Health check passed');
      print('Response: ${healthResponse.body}');
    } else {
      print('❌ Health check failed: ${healthResponse.statusCode}');
      return;
    }

    // Test image processing
    print('\nTesting image processing...');
    final processResponse = await http
        .post(
          Uri.parse('$serverUrl/api/process-images'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'imageUrls': [testImageUrl],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (processResponse.statusCode == 200) {
      final result = jsonDecode(processResponse.body) as Map<String, dynamic>;
      print('✅ Image processing successful');
      print('Response: ${processResponse.body}');

      if (result['success'] == true && result['processedImages'] != null) {
        final processedImages = result['processedImages'] as List;
        if (processedImages.isNotEmpty) {
          final processedUrl = '$serverUrl${processedImages.first}';
          print('✅ Processed image URL: $processedUrl');

          // Test if the processed image is accessible
          final imageResponse = await http.get(Uri.parse(processedUrl));
          if (imageResponse.statusCode == 200) {
            print('✅ Processed image is accessible');
          } else {
            print(
              '❌ Processed image not accessible: ${imageResponse.statusCode}',
            );
          }
        } else {
          print('❌ No processed images returned');
        }
      } else {
        print(
          '❌ Image processing failed: ${result['errors'] ?? 'Unknown error'}',
        );
      }
    } else {
      print('❌ Image processing request failed: ${processResponse.statusCode}');
      print('Response: ${processResponse.body}');
    }
  } catch (e) {
    print('❌ Error testing server: $e');
  }
}
