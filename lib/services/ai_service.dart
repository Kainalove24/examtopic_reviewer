import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import '../config/api_config.dart';

class AIService {
  // Use embedded API key from ApiConfig
  static String get apiKey {
    if (ApiConfig.isApiKeyConfigured) return ApiConfig.openaiApiKey;
    throw Exception(
      'OpenAI API key not configured. Please update the API key in lib/config/api_config.dart\n'
      'Get your API key from: https://platform.openai.com/account/api-keys',
    );
  }

  /// Get AI explanation for a question
  static Future<String> getExplanation({
    required String questionText,
    required List<String> options,
    required List<String> correctAnswers,
    required String selectedAnswer,
    List<String>? questionImages,
    List<String>? answerImages,
    String? existingExplanation,
  }) async {
    final currentApiKey = apiKey;

    try {
      final hasImages =
          (questionImages?.isNotEmpty == true) ||
          (answerImages?.isNotEmpty == true);

      // Choose model based on whether images are present
      final model = hasImages ? ApiConfig.gpt4oModel : ApiConfig.gpt4MiniModel;

      // Prepare the prompt
      final prompt = _buildPrompt(
        questionText: questionText,
        options: options,
        correctAnswers: correctAnswers,
        selectedAnswer: selectedAnswer,
        existingExplanation: existingExplanation,
        hasImages: hasImages,
      );

      if (hasImages) {
        // Use GPT-4o with image processing
        return await _getExplanationWithImages(
          model: model,
          prompt: prompt,
          questionImages: questionImages ?? [],
          answerImages: answerImages ?? [],
          apiKey: currentApiKey,
        );
      } else {
        // Use GPT-4o-mini for text-only
        return await _getTextOnlyExplanation(
          model: model,
          prompt: prompt,
          apiKey: currentApiKey,
        );
      }
    } catch (e) {
      throw Exception('Failed to get AI explanation: $e');
    }
  }

  static String _buildPrompt({
    required String questionText,
    required List<String> options,
    required List<String> correctAnswers,
    required String selectedAnswer,
    String? existingExplanation,
    bool hasImages = false,
  }) {
    final isCorrect = correctAnswers.contains(selectedAnswer);

    String imageNote = '';
    if (hasImages) {
      imageNote = '''
IMPORTANT: First read and understand the question text above, then analyze the images that follow.
The images provide additional context to help you understand the question better.
Please reference specific details from the images in your explanation when relevant.
''';
    }

    return '''
You are an expert tutor helping a student understand multiple-choice questions. Your role is to provide accurate explanations based on the question content and your knowledge.

Question:
$questionText

Choices:
${options.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}').join('\n')}

Student's Answer: $selectedAnswer

$imageNote

**Your Task:**
1. 🔍 **Carefully analyze** the question content and all provided information
2. ✅ **Identify the correct answer** based on the question's context and your knowledge
3. 🤔 **Consider all options** and explain why the correct one is right
4. 💡 **Provide clear explanation** that helps the student understand

**Response Format:**
✅ **Correct Answer**: [The correct option] - Brief explanation of why it's right (1-2 sentences)
❌ **Why others are wrong**: Quick explanation for each incorrect option (1 sentence each), in bullet form.

Use **bold** for emphasis, add relevant emojis, and keep it concise. Maximum 3-4 sentences total.

**Important Guidelines:**
- Base your analysis on the question content and your knowledge
- Be confident but accurate in your assessment
- If you're uncertain about any aspect, acknowledge the limitation and now refer to the emebedded answer
- Focus on helping the student understand, not on proving answers wrong
''';
  }

  static Future<String> _getTextOnlyExplanation({
    required String model,
    required String prompt,
    required String apiKey,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.openaiBaseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a helpful educational tutor specializing in exam preparation. Provide clear, concise explanations that help students understand concepts deeply.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<String> _getExplanationWithImages({
    required String model,
    required String prompt,
    required List<String> questionImages,
    required List<String> answerImages,
    required String apiKey,
  }) async {
    // Prepare content with text first, then images
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];

    // Add question images first (they provide context for the question)
    for (final imagePath in questionImages) {
      try {
        final imageData = await _processImageForAPI(imagePath);
        if (imageData != null) {
          content.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageData'},
          });
        }
      } catch (e) {
        print('Failed to process question image $imagePath: $e');
      }
    }

    // Add answer images after question images
    for (final imagePath in answerImages) {
      try {
        final imageData = await _processImageForAPI(imagePath);
        if (imageData != null) {
          content.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageData'},
          });
        }
      } catch (e) {
        print('Failed to process answer image $imagePath: $e');
      }
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.openaiBaseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a helpful educational tutor specializing in exam preparation. You can analyze images and provide clear, concise explanations that help students understand concepts deeply. When analyzing questions with images, first understand the text, then examine the images for additional context.',
          },
          {'role': 'user', 'content': content},
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<String?> _processImageForAPI(String imagePath) async {
    try {
      // For Flutter assets, we need to load the image and convert to base64
      // This is a simplified implementation - in a real app, you might want to
      // cache the processed images or handle them more efficiently

      // Load the image from assets
      final ByteData data = await rootBundle.load(imagePath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        print('Failed to decode image: $imagePath');
        return null;
      }

      // Resize image if it's too large (OpenAI has size limits)
      img.Image resizedImage = image;
      if (image.width > 1024 || image.height > 1024) {
        resizedImage = img.copyResize(image, width: 1024, height: 1024);
      }

      // Convert to JPEG format
      final Uint8List jpegBytes = img.encodeJpg(resizedImage, quality: 85);

      // Convert to base64
      final String base64String = base64Encode(jpegBytes);

      print('Successfully processed image: $imagePath');
      return base64String;
    } catch (e) {
      print('Error processing image $imagePath: $e');
      return null;
    }
  }
}
