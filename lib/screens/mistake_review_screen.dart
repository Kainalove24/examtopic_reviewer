import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/progress_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../models/exam_question.dart';
import '../widgets/ai_explanation_card.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../services/image_service.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

class MistakeReviewScreen extends StatefulWidget {
  final String examId;
  final List<ExamQuestion> allQuestions;
  const MistakeReviewScreen({
    super.key,
    required this.examId,
    required this.allQuestions,
  });

  @override
  State<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends State<MistakeReviewScreen> {
  int currentIndex = 0;
  int? selectedOption;
  List<int> selectedOptions = [];
  List<int> hotspotSelectedOrder = [];
  bool submitted = false;
  bool isCorrect = false;
  bool showRemovePrompt = false;
  List<Map<String, dynamic>> mistakeQueue = [];
  late ProgressProvider progressProvider;

  // AI Explanation state variables
  String? _aiExplanation;
  bool _isLoadingExplanation = false;
  int _regenerationAttempts = 0;
  static const int _maxRegenerationAttempts = 2;

  @override
  void initState() {
    super.initState();
    progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    _initializeMistakeQueue();
  }

  Future<void> _initializeMistakeQueue() async {
    await progressProvider.loadProgress(widget.examId);
    final progress = progressProvider.progress;
    final List<String> mistakeIds =
        (progress['mistakeQuestions'] as List?)?.cast<String>() ?? [];

    print('Debug: Loading mistake review for exam: ${widget.examId}');
    print('Debug: Progress data: $progress');
    print('Debug: Mistake IDs found: $mistakeIds');
    print('Debug: Total questions available: ${widget.allQuestions.length}');

    // Convert ExamQuestion to Map and filter by mistake IDs
    final mistakes = widget.allQuestions
        .where((q) => mistakeIds.contains(_getQuestionId(q.toMap())))
        .map((q) => q.toMap())
        .toList();

    print('Debug: Questions matching mistake IDs: ${mistakes.length}');

    // Shuffle the mistakes
    final random = Random();
    mistakes.shuffle(random);

    setState(() {
      mistakeQueue = mistakes;
    });

    print('Debug: Final mistake queue length: ${mistakeQueue.length}');
  }

  String _getQuestionId(Map<String, dynamic> question) {
    // Create a unique ID for the question based on its content using hash codes
    final textHash = question['text']?.hashCode ?? 0;
    final optionsHash = question['options']?.hashCode ?? 0;
    return '${textHash}_${optionsHash}';
  }

  int _getOriginalQuestionNumber(Map<String, dynamic> question) {
    final originalIndex = widget.allQuestions.indexWhere(
      (q) => _getQuestionId(q.toMap()) == _getQuestionId(question),
    );
    return originalIndex + 1; // Convert to 1-based numbering
  }

  bool _isMultiAnswer(Map<String, dynamic> q) {
    final answersRaw = q['answers'] ?? q['answer'];
    if (answersRaw is List && answersRaw.length > 1) return true;
    if (answersRaw is String && answersRaw.contains('|')) return true;
    // Remove the problematic text-based detection that was causing false positives
    // Only rely on the actual answer data structure
    return false;
  }

  bool _isHotspot(Map<String, dynamic> q) {
    return q['type'] == 'hotspot';
  }

  List<Widget> _buildImageWidgets(List images, BuildContext context) {
    final List<Widget> widgets = [];
    for (final imgRaw in images) {
      if (imgRaw is String) {
        final img = imgRaw.trim();
        if (img.isNotEmpty) {
          widgets.add(
            GestureDetector(
              onTap: () {
                showEnhancedImageViewer(context, img, title: 'Question Image');
              },
              child: _buildImageWidget(img),
            ),
          );
        }
      }
    }
    return widgets;
  }

  Widget _buildImageWidget(String imageData) {
    print('Building image widget for: $imageData');

    // Check if it's a base64 image
    if (imageData.startsWith('data:image/')) {
      try {
        // Extract base64 data
        final base64Data = imageData.split(',')[1];
        final imageBytes = base64Decode(base64Data);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading base64 image: $error');
                return _buildErrorImage();
              },
            ),
          ),
        );
      } catch (e) {
        print('Exception loading base64 image: $e');
        return _buildErrorImage();
      }
    }

    // Check if it's a network URL
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      print('Loading network image: $imageData');
      return _buildNetworkImage(imageData);
    }

    // Check if it's a local file path
    if (imageData.startsWith('images/')) {
      print('Loading local image: $imageData');
      return _buildLocalImage(imageData);
    }

    // Assume it's an asset path
    print('Loading asset image: $imageData');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imageData,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading asset image: $error');
            return _buildErrorImage();
          },
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String imageData) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageData,
          height: 120,
          fit: BoxFit.contain,
          // Use ImageService for better mobile web compatibility
          headers: ImageService.getWebHeaders(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 120,
              color: Colors.grey.shade100,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            // For web, try alternative loading methods
            if (kIsWeb) {
              return _buildWebFallbackImage(imageData);
            }
            return _buildErrorImage();
          },
        ),
      ),
    );
  }

  Widget _buildLocalImage(String imageData) {
    return FutureBuilder<String?>(
      future: _getLocalImagePath(imageData),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(snapshot.data!),
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading local image: $error');
                  return _buildErrorImage();
                },
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print('Error loading local image: ${snapshot.error}');
          return _buildErrorImage();
        } else {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Widget _buildWebFallbackImage(String imageData) {
    // For web, try loading with different approaches
    return FutureBuilder<Widget>(
      future: _tryAlternativeImageLoading(imageData),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return _buildMobileWebPlaceholder();
      },
    );
  }

  Future<Widget> _tryAlternativeImageLoading(String imageData) async {
    // Try different approaches for mobile web
    try {
      // Approach 1: Try converting to base64
      final base64Image = await ImageService.convertImageToBase64(imageData);
      if (base64Image != null) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(base64Image.split(',')[1]),
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                throw Exception('Failed to load base64 image');
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Failed to convert image to base64: $e');
    }

    // Approach 2: Try with different headers
    try {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageData,
            height: 120,
            fit: BoxFit.contain,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            errorBuilder: (context, error, stackTrace) {
              throw Exception('Failed with custom headers');
            },
          ),
        ),
      );
    } catch (e) {
      // Approach 3: Try without any headers
      try {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageData,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                throw Exception('Failed without headers');
              },
            ),
          ),
        );
      } catch (e) {
        // Approach 4: Show a placeholder
        return _buildMobileWebPlaceholder();
      }
    }
  }

  Widget _buildMobileWebPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 24, color: Colors.grey[600]),
          SizedBox(height: 4),
          Text(
            'Image not available',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to get the full path for local images
  Future<String?> _getLocalImagePath(String relativePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = path.join(appDir.path, relativePath);

      final file = File(fullPath);
      final exists = await file.exists();

      if (exists) {
        return fullPath;
      } else {
        // Try alternative paths
        final altPaths = [
          path.join(appDir.path, 'images', path.basename(relativePath)),
          path.join(appDir.path, 'assets', relativePath),
          relativePath, // Try as absolute path
        ];

        for (final altPath in altPaths) {
          final altFile = File(altPath);
          if (await altFile.exists()) {
            return altPath;
          }
        }

        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Widget _buildErrorImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      height: 120,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.red, size: 24),
            SizedBox(height: 4),
            Text(
              'Image not found',
              style: TextStyle(fontSize: 10, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _getCorrectIndices(Map<String, dynamic> q) {
    final isHotspot = _isHotspot(q);
    final isMulti = _isMultiAnswer(q);
    final options = q['options'] as List;
    final answersRaw = q['answers'] ?? q['answer'];
    List<int> correctIndices = [];

    if (isHotspot) {
      final answersRaw = q['answers'] ?? q['answer'];
      if (answersRaw is List) {
        // Handle list format (from exam data) - convert option texts to indices
        for (var answerText in answersRaw) {
          final aStr = answerText.toString().trim();
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) {
            correctIndices.add(idx + 1); // Convert to 1-based for comparison
          }
        }
      } else {
        // Fallback to string parsing (older format)
        final answerText = answersRaw?.toString() ?? '';
        final correctOrder = answerText
            .split('|')
            .map((s) => s.trim())
            .toList();
        for (var ans in correctOrder) {
          final aStr = ans.toString().trim();
          int idx;
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            // Convert letter to index (A=0, B=1, etc.)
            idx = aStr.toUpperCase().codeUnitAt(0) - 65;
          } else if (int.tryParse(aStr) != null) {
            // Use number directly (0-based)
            idx = int.tryParse(aStr)!;
          } else {
            // Fallback to text match
            idx = options.indexWhere((o) => o.toString().trim() == aStr);
          }
          correctIndices.add(idx + 1); // Convert to 1-based for comparison
        }
      }
    } else if (answersRaw is List && answersRaw.isNotEmpty) {
      correctIndices = answersRaw.map((a) {
        final aStr = a.toString().trim();
        if (aStr.length == 1 &&
            RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
          return aStr.toUpperCase().codeUnitAt(0) - 65;
        }
        if (int.tryParse(aStr) != null) {
          return int.tryParse(aStr)!;
        }
        return options.indexWhere((o) => o.toString().trim() == aStr);
      }).toList();
    } else if (answersRaw is String && answersRaw.isNotEmpty) {
      if (isMulti) {
        correctIndices = answersRaw.split('|').map((a) {
          final aStr = a.trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase().codeUnitAt(0) - 65;
          }
          if (int.tryParse(aStr) != null) {
            return int.tryParse(aStr)!;
          }
          return options.indexWhere((o) => o.toString().trim() == aStr);
        }).toList();
      } else {
        final aStr = answersRaw.trim();
        if (aStr.length == 1 &&
            RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
          correctIndices = [aStr.toUpperCase().codeUnitAt(0) - 65];
        } else if (int.tryParse(aStr) != null) {
          correctIndices = [int.tryParse(aStr)!];
        } else {
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) correctIndices = [idx];
        }
      }
    }
    return correctIndices;
  }

  String _getCorrectAnswerText(Map<String, dynamic> q) {
    final isHotspot = _isHotspot(q);
    final isMulti = _isMultiAnswer(q);
    final options = q['options'] as List;

    if (isHotspot) {
      final answersRaw = q['answers'] ?? q['answer'];
      List<String> correctOptions = [];

      if (answersRaw is List) {
        // Handle list format (from exam data)
        correctOptions = answersRaw.map((a) => a.toString().trim()).toList();
      } else {
        // Handle string format (fallback)
        final answerText = answersRaw?.toString() ?? '';
        final correctOrder = answerText
            .split('|')
            .map((s) => s.trim())
            .toList();
        for (var ans in correctOrder) {
          final aStr = ans.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            final idx = aStr.toUpperCase().codeUnitAt(0) - 65;
            if (idx >= 0 && idx < options.length) {
              correctOptions.add(options[idx].toString().trim());
            }
          } else if (int.tryParse(aStr) != null) {
            final idx = int.tryParse(aStr)!;
            if (idx >= 0 && idx < options.length) {
              correctOptions.add(options[idx].toString().trim());
            }
          } else {
            correctOptions.add(aStr);
          }
        }
      }

      return correctOptions.join(', ');
    } else if (isMulti) {
      final answersRaw = q['answers'] ?? q['answer'];
      List<String> correctLetters = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
        correctLetters = answersRaw.map((a) {
          final aStr = a.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase();
          }
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          return idx >= 0 ? String.fromCharCode(65 + idx) : aStr;
        }).toList();
      } else if (answersRaw is String && answersRaw.isNotEmpty) {
        correctLetters = answersRaw.split('|').map((a) {
          final aStr = a.trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase();
          }
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          return idx >= 0 ? String.fromCharCode(65 + idx) : aStr;
        }).toList();
      }
      return 'Correct options: ${correctLetters.join(', ')}.';
    } else {
      final answersRaw = q['answers'] ?? q['answer'];
      List<String> correctLetters = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
        correctLetters = answersRaw.map((a) {
          final aStr = a.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase();
          }
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          return idx >= 0 ? String.fromCharCode(65 + idx) : aStr;
        }).toList();
      } else if (answersRaw is String && answersRaw.isNotEmpty) {
        final aStr = answersRaw.trim();
        if (aStr.length == 1 &&
            RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
          correctLetters = [aStr.toUpperCase()];
        } else {
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          correctLetters = [idx >= 0 ? String.fromCharCode(65 + idx) : aStr];
        }
      }
      return 'Correct answer: ${correctLetters.join('')}.';
    }
  }

  void _submit() {
    final q = mistakeQueue[currentIndex];
    final isHotspot = _isHotspot(q);
    final isMulti = _isMultiAnswer(q);
    bool correct = false;

    if (isHotspot) {
      final correctIndices = _getCorrectIndices(q);
      print('Debug MistakeReview: Hotspot question');
      print('Debug MistakeReview: User answer: $hotspotSelectedOrder');
      print('Debug MistakeReview: Correct indices: $correctIndices');
      print('Debug MistakeReview: Options: ${q['options']}');
      print('Debug MistakeReview: Answers raw: ${q['answers']}');

      correct =
          hotspotSelectedOrder.length == correctIndices.length &&
          List.generate(
            correctIndices.length,
            (i) => hotspotSelectedOrder[i] == correctIndices[i],
          ).every((v) => v);

      print('Debug MistakeReview: Is correct: $correct');
    } else if (isMulti) {
      final correctIndices = _getCorrectIndices(q);
      final selectedSet = selectedOptions.toSet();
      final correctSet = correctIndices.toSet();
      correct =
          selectedSet.length == correctSet.length &&
          selectedSet.difference(correctSet).isEmpty;
    } else {
      if (selectedOption == null) return;
      final correctIndices = _getCorrectIndices(q);
      correct = correctIndices.contains(selectedOption);
    }

    setState(() {
      submitted = true;
      isCorrect = correct;
      showRemovePrompt = false;
      // Reset AI explanation when submitting new answer
      _aiExplanation = null;
      _isLoadingExplanation = false;
      _regenerationAttempts = 0;
    });

    if (correct) {
      setState(() {
        showRemovePrompt = true;
      });
    }
  }

  void _removeFromMistakes(bool remove) {
    final q = mistakeQueue[currentIndex];
    final questionId = _getQuestionId(q);

    if (remove) {
      // Mark as mastered and remove from mistakes
      final progress = progressProvider.progress;
      final masteredList =
          (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];
      final mistakesList =
          (progress['mistakeQuestions'] as List?)?.cast<String>() ?? [];

      if (!masteredList.contains(questionId)) {
        masteredList.add(questionId);
      }
      mistakesList.remove(questionId);

      progressProvider.updateProgress(
        examId: widget.examId,
        masteredQuestions: masteredList,
        mistakeQuestions: mistakesList,
      );
      progressProvider.saveProgress(widget.examId);

      // Remove from current queue
      setState(() {
        mistakeQueue.removeAt(currentIndex);
        if (currentIndex >= mistakeQueue.length && mistakeQueue.isNotEmpty) {
          currentIndex = mistakeQueue.length - 1;
        }
      });
    }

    setState(() {
      showRemovePrompt = false;
      submitted = false;
      selectedOption = null;
      selectedOptions.clear();
      hotspotSelectedOrder.clear();
    });

    if (mistakeQueue.isEmpty) {
      // All mistakes reviewed
      context.go('/exam/${widget.examId}');
    }
  }

  void _next() {
    setState(() {
      if (currentIndex < mistakeQueue.length - 1) {
        currentIndex++;
        _resetAnswerStates();
      }
    });
  }

  void _resetAnswerStates() {
    selectedOption = null;
    selectedOptions.clear();
    hotspotSelectedOrder.clear();
    submitted = false;
    isCorrect = false;
    showRemovePrompt = false;
    _aiExplanation = null;
    _isLoadingExplanation = false;
    _regenerationAttempts = 0;
  }

  Future<void> _saveAIExplanation(
    Map<String, dynamic> question,
    String explanation,
  ) async {
    try {
      // Save to the question data
      question['ai_explanation'] = explanation;

      // Save to ExamProvider for persistence across screens
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final originalQuestionIndex = widget.allQuestions.indexWhere(
        (q) => _getQuestionId(q.toMap()) == _getQuestionId(question),
      );
      if (originalQuestionIndex != -1) {
        await examProvider.updateQuestionAIExplanation(
          widget.examId,
          originalQuestionIndex,
          explanation,
        );
      }

      print(
        'AI explanation saved for question: ${question['text']?.substring(0, 50)}...',
      );
    } catch (e) {
      print('Error saving AI explanation: $e');
    }
  }

  void _showAIExplanation(
    BuildContext context,
    Map<String, dynamic> question,
    int questionIndex,
  ) async {
    if (_isLoadingExplanation) return;

    // Check if we already have an explanation for this question
    final existingExplanation =
        question['ai_explanation'] ?? question['explanation'];

    // Also check ExamProvider for existing AI explanation
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final originalQuestionIndex = widget.allQuestions.indexWhere(
      (q) => _getQuestionId(q.toMap()) == _getQuestionId(question),
    );
    final savedAIExplanation = originalQuestionIndex != -1
        ? examProvider.getQuestionAIExplanation(
            widget.examId,
            originalQuestionIndex,
          )
        : null;

    if (existingExplanation != null &&
        existingExplanation.toString().isNotEmpty) {
      setState(() {
        _aiExplanation = existingExplanation.toString();
        _regenerationAttempts = 0;
      });
      return;
    }

    // Check if there's a saved AI explanation in ExamProvider
    if (savedAIExplanation != null && savedAIExplanation.isNotEmpty) {
      print(
        'Found saved AI explanation in ExamProvider for question $questionIndex',
      );
      setState(() {
        _aiExplanation = savedAIExplanation;
        _regenerationAttempts = 0;
        // Update the question data to include the AI explanation
        question['ai_explanation'] = savedAIExplanation;
      });
      return;
    }

    // Check regeneration limit
    if (_regenerationAttempts >= _maxRegenerationAttempts) {
      setState(() {
        _aiExplanation =
            'Maximum regeneration attempts reached. Please try again later.';
      });
      return;
    }

    setState(() {
      _isLoadingExplanation = true;
      _aiExplanation = null;
    });

    try {
      // Get the correct answers
      final answersRaw = question['answers'] ?? question['answer'];
      List<String> correctAnswers = [];

      if (answersRaw is List && answersRaw.isNotEmpty) {
        if (int.tryParse(answersRaw[0].toString()) != null) {
          correctAnswers = answersRaw
              .map((a) => String.fromCharCode(65 + int.tryParse(a.toString())!))
              .toList();
        } else {
          correctAnswers = answersRaw
              .map((a) => a.toString().trim().toUpperCase())
              .toList();
        }
      } else if (answersRaw is String && answersRaw.isNotEmpty) {
        if (int.tryParse(answersRaw) != null) {
          correctAnswers = [
            String.fromCharCode(65 + int.tryParse(answersRaw)!),
          ];
        } else {
          correctAnswers = [answersRaw.trim().toUpperCase()];
        }
      }

      // For now, we'll use the first correct answer as the "selected" answer
      final selectedAnswer = correctAnswers.isNotEmpty
          ? correctAnswers.first
          : 'A';

      // Call AI service to get explanation
      final explanation = await AIService.getExplanation(
        questionText: question['text'] ?? '',
        options: List<String>.from(question['options'] ?? []),
        correctAnswers: correctAnswers,
        selectedAnswer: selectedAnswer,
        questionImages: question['question_images'] != null
            ? List<String>.from(question['question_images'])
            : null,
        answerImages: question['answer_images'] != null
            ? List<String>.from(question['answer_images'])
            : null,
        existingExplanation: existingExplanation,
      );

      // Save the explanation to the question
      await _saveAIExplanation(question, explanation);

      setState(() {
        _aiExplanation = explanation;
        _isLoadingExplanation = false;
        _regenerationAttempts++;
      });
    } catch (e) {
      setState(() {
        _aiExplanation = 'Error: ${e.toString()}';
        _isLoadingExplanation = false;
        _regenerationAttempts++;
      });
    }
  }

  void _showApiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Explanations Ready'),
        content: const Text(
          'AI explanations are enabled and ready to use with the embedded API key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownText(String text) {
    final List<TextSpan> spans = [];
    // Updated regex to handle edge cases and ensure proper matching
    final RegExp boldPattern = RegExp(
      r'\*\*(.*?)\*\*',
      multiLine: true,
      dotAll: true,
    );
    int currentIndex = 0;

    // Debug: Print the text to see what we're working with
    print('Debug: Processing text: $text');
    print(
      'Debug: Bold pattern matches: ${boldPattern.allMatches(text).length}',
    );

    for (final Match match in boldPattern.allMatches(text)) {
      print(
        'Debug: Found bold match: "${match.group(0)}" -> "${match.group(1)}"',
      );

      // Add text before the bold part
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        );
      }

      // Add the bold text
      spans.add(
        TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      );
    }

    // If no bold patterns found, return regular text
    if (spans.isEmpty) {
      print('Debug: No bold patterns found, returning regular text');
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }

    print('Debug: Returning RichText with ${spans.length} spans');
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    if (mistakeQueue.isEmpty) {
      return _buildEmptyState();
    }

    final q = mistakeQueue[currentIndex];
    final options = q['options'] as List;
    final isHotspot = _isHotspot(q);
    final isMulti = _isMultiAnswer(q);
    final isLastQuestion = currentIndex == mistakeQueue.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review Practice',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: BackButton(
          onPressed: () => context.go('/exam/${widget.examId}'),
          style: ButtonStyle(
            iconColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(),
            const SizedBox(height: 24),
            _buildQuestionCard(q, options, isHotspot, isMulti),
            const SizedBox(height: 24),
            _buildActionButtons(isHotspot, isMulti, isLastQuestion),
            if (submitted) ...[
              const SizedBox(height: 16),
              _buildAIExplanationSection(q),
              if (showRemovePrompt) ...[
                const SizedBox(height: 16),
                _buildRemovePrompt(),
              ],
              if (isHotspot &&
                  q['answer_images'] != null &&
                  q['answer_images'] is List &&
                  q['answer_images'].isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAnswerImages(q['answer_images']),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review Practice',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: BackButton(
          onPressed: () => context.go('/exam/${widget.examId}'),
          style: ButtonStyle(
            iconColor: WidgetStateProperty.all(theme.colorScheme.onSurface),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Questions to Review! 🎉',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Great job! You have no questions to review.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Keep up the excellent work!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () => context.go('/exam/${widget.examId}'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Exam'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final theme = Theme.of(context);
    final progress = (currentIndex + 1) / mistakeQueue.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.onErrorContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviewing Questions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Question ${currentIndex + 1} of ${mistakeQueue.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.error,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> q,
    List options,
    bool isHotspot,
    bool isMulti,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${_getOriginalQuestionNumber(q)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q['text'] ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          // Question Images
          if (q['question_images'] != null &&
              q['question_images'] is List &&
              q['question_images'].isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildQuestionImages(q['question_images']),
          ],

          const SizedBox(height: 20),

          // Options
          Text(
            'Options',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          if (isHotspot)
            _buildHotspotOptions(options, q)
          else if (isMulti)
            _buildMultiChoiceOptions(options, q)
          else
            _buildSingleChoiceOptions(options, q),
        ],
      ),
    );
  }

  Widget _buildQuestionImages(List images) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question Images',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildImageWidgets(images, context),
        ),
      ],
    );
  }

  Widget _buildAnswerImages(List images) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image_rounded,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Answer Images',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildImageWidgets(images, context),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotOptions(List options, Map<String, dynamic> q) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(options.length, (i) {
            List<int> indices = [];
            for (int j = 0; j < hotspotSelectedOrder.length; j++) {
              if (hotspotSelectedOrder[j] == i + 1) indices.add(j);
            }

            return GestureDetector(
              onTap: submitted
                  ? null
                  : () {
                      setState(() {
                        hotspotSelectedOrder.add(i + 1);
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: indices.isNotEmpty
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(
                          0.3,
                        ),
                  border: Border.all(
                    color: indices.isNotEmpty
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: indices.isNotEmpty ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i + 1}. ${options[i]}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: indices.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: indices.isNotEmpty
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (indices.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ...indices.map(
                        (orderIdx) => Container(
                          margin: const EdgeInsets.only(left: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (orderIdx + 1).toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (!submitted) ...[
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: hotspotSelectedOrder.isEmpty
                    ? null
                    : () => setState(() => hotspotSelectedOrder.removeLast()),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Undo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: hotspotSelectedOrder.isEmpty
                    ? null
                    : () => setState(() => hotspotSelectedOrder.clear()),
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Your answer: ${hotspotSelectedOrder.join(' → ')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: submitted
                      ? (isCorrect
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (submitted) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getCorrectAnswerText(q),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiChoiceOptions(List options, Map<String, dynamic> q) {
    final theme = Theme.of(context);

    return Column(
      children: List.generate(options.length, (i) {
        String optionText = options[i].toString().replaceFirst(
          RegExp(r'^[A-Z]\.\s*'),
          '',
        );

        final correctIndices = submitted ? _getCorrectIndices(q) : [];
        final isSelected = selectedOptions.contains(i);
        final isCorrect = correctIndices.contains(i);

        Color? checkboxColor;
        Color? textColor;
        IconData? icon;
        Color? iconColor;

        if (submitted) {
          if (isSelected && isCorrect) {
            checkboxColor = Colors.green;
            textColor = Colors.green;
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
          } else if (isSelected && !isCorrect) {
            checkboxColor = theme.colorScheme.error;
            textColor = theme.colorScheme.error;
            icon = Icons.cancel_rounded;
            iconColor = theme.colorScheme.error;
          } else if (!isSelected && isCorrect) {
            checkboxColor = Colors.green;
            textColor = Colors.green;
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
          }
        } else if (isSelected) {
          checkboxColor = theme.colorScheme.primary;
          textColor = theme.colorScheme.primary;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: submitted
                    ? null
                    : (value) {
                        setState(() {
                          if (value == true) {
                            selectedOptions.add(i);
                          } else {
                            selectedOptions.remove(i);
                          }
                        });
                      },
                activeColor: checkboxColor ?? theme.colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${String.fromCharCode(65 + i)}. $optionText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor ?? theme.colorScheme.onSurface,
                    fontWeight: textColor != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 20),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSingleChoiceOptions(List options, Map<String, dynamic> q) {
    final theme = Theme.of(context);

    return Column(
      children: List.generate(options.length, (i) {
        String optionText = options[i].toString().replaceFirst(
          RegExp(r'^[A-Z]\.\s*'),
          '',
        );

        final correctIndices = submitted ? _getCorrectIndices(q) : [];
        final isSelected = selectedOption == i;
        final isCorrect = correctIndices.contains(i);

        Color? radioColor;
        Color? textColor;
        IconData? icon;
        Color? iconColor;

        if (submitted) {
          if (isSelected && isCorrect) {
            radioColor = Colors.green;
            textColor = Colors.green;
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
          } else if (isSelected && !isCorrect) {
            radioColor = theme.colorScheme.error;
            textColor = theme.colorScheme.error;
            icon = Icons.cancel_rounded;
            iconColor = theme.colorScheme.error;
          } else if (!isSelected && isCorrect) {
            radioColor = Colors.green;
            textColor = Colors.green;
            icon = Icons.check_circle_rounded;
            iconColor = Colors.green;
          }
        } else if (isSelected) {
          radioColor = theme.colorScheme.primary;
          textColor = theme.colorScheme.primary;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Radio<int>(
                value: i,
                groupValue: selectedOption,
                onChanged: submitted
                    ? null
                    : (value) => setState(() => selectedOption = value),
                activeColor: radioColor ?? theme.colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${String.fromCharCode(65 + i)}. $optionText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor ?? theme.colorScheme.onSurface,
                    fontWeight: textColor != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 20),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons(
    bool isHotspot,
    bool isMulti,
    bool isLastQuestion,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (!submitted)
          Expanded(
            child: ElevatedButton.icon(
              onPressed:
                  ((isHotspot && hotspotSelectedOrder.isNotEmpty) ||
                      (isMulti && selectedOptions.isNotEmpty) ||
                      (!isMulti && !isHotspot && selectedOption != null))
                  ? _submit
                  : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Answer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (submitted) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLastQuestion ? () => _next() : _next,
              icon: Icon(
                isLastQuestion
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(isLastQuestion ? 'Finish Review' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastQuestion
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.error,
                foregroundColor: isLastQuestion
                    ? theme.colorScheme.onSecondary
                    : theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAIExplanationSection(Map<String, dynamic> q) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        if (!settings.aiExplanationsEnabled) {
          return const SizedBox.shrink();
        }

        return AIExplanationCard(
          explanation: _aiExplanation,
          isLoading: _isLoadingExplanation,
          regenerationAttempts: _regenerationAttempts,
          maxRegenerationAttempts: _maxRegenerationAttempts,
          onGetExplanation: () => _showAIExplanation(context, q, currentIndex),
          onRegenerate: () => _showAIExplanation(context, q, currentIndex),
          isApiKeyConfigured: settings.isApiKeyConfigured,
          onShowApiKeyDialog: () => _showApiKeyDialog(context),
        );
      },
    );
  }

  Widget _buildRemovePrompt() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Master this Question?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You answered this question correctly. Would you like to mark it as mastered?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _removeFromMistakes(false),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Keep for Review'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _removeFromMistakes(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark Mastered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
