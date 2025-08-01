import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/ai_service.dart';
import '../widgets/ai_explanation_card.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../services/sound_service.dart';
import '../services/image_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

class QuizModeScreen extends StatefulWidget {
  final String examTitle;
  final String examId;
  final List<Map<String, dynamic>> questions;
  final int setIndex;
  final int itemsPerSet;
  final int? startQuestion;
  final int? endQuestion;

  const QuizModeScreen({
    super.key,
    required this.examTitle,
    required this.examId,
    required this.questions,
    this.setIndex = 0,
    this.itemsPerSet = 20,
    this.startQuestion,
    this.endQuestion,
  });

  @override
  State<QuizModeScreen> createState() => _QuizModeScreenState();
}

class _QuizModeScreenState extends State<QuizModeScreen> {
  int currentIndex = 0;
  int? selectedOption;
  List<int> selectedOptions = [];
  List<int> hotspotSelectedOrder = [];
  bool submitted = false;
  bool isCorrect = false;
  bool finished = false;
  int score = 0;
  List<int> mistakes = [];

  // Quiz questions and state
  List<Map<String, dynamic>> quizQuestions = [];
  List<List<String>> shuffledOptions = [];
  List<int> userAnswers = [];

  // Progress tracking
  late ProgressProvider progressProvider;
  String get examId => widget.examId;

  // AI Explanation state variables
  final Map<int, String?> _aiExplanations = {};
  final Map<int, bool> _isLoadingExplanations = {};
  final Map<int, int> _regenerationAttempts = {};
  static const int _maxRegenerationAttempts = 2;

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
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
            Text('Image not found', style: TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  bool _isMultiAnswer(Map<String, dynamic> q) {
    final answersRaw = q['answers'] ?? q['answer'];
    if (answersRaw is List && answersRaw.length > 1) return true;
    if (answersRaw is String && answersRaw.contains('|')) return true;
    // Remove the problematic text-based detection that was causing false positives
    // Only rely on the actual answer data structure
    return false;
  }

  @override
  void initState() {
    super.initState();
    progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    _initializeQuiz();
  }

  void _initializeQuiz() {
    // Get questions from the selected range
    int start, end;

    // Check if we're using range-based quiz
    if (widget.startQuestion != null && widget.endQuestion != null) {
      // Use the specified range (convert to 0-based indexing)
      start = (widget.startQuestion! - 1).clamp(0, widget.questions.length - 1);
      end = widget.endQuestion!.clamp(1, widget.questions.length);
    } else {
      // Default behavior - use setIndex and itemsPerSet
      start = widget.setIndex * widget.itemsPerSet;
      end = (start + widget.itemsPerSet).clamp(0, widget.questions.length);
    }

    // Get questions and shuffle them
    quizQuestions = List<Map<String, dynamic>>.from(
      widget.questions.sublist(start, end),
    );
    quizQuestions.shuffle();

    // Shuffle options for each question
    shuffledOptions = quizQuestions.map((q) {
      final opts = List<String>.from(q['options']);
      opts.shuffle();
      return opts;
    }).toList();

    // Initialize user answers
    userAnswers = List.filled(quizQuestions.length, -1);
  }

  void _restartQuiz() {
    setState(() {
      currentIndex = 0;
      score = 0;
      finished = false;
      mistakes.clear();
      submitted = false;
      isCorrect = false;
      selectedOption = null;
      selectedOptions.clear();
      hotspotSelectedOrder.clear();
      userAnswers = List.filled(quizQuestions.length, -1);

      // Re-shuffle questions and options
      quizQuestions.shuffle();
      shuffledOptions = quizQuestions.map((q) {
        final opts = List<String>.from(q['options']);
        opts.shuffle();
        return opts;
      }).toList();
    });
  }

  void _submit() {
    final q = quizQuestions[currentIndex];
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);
    bool correct = false;

    if (isHotspot) {
      final correctIndices = _getCorrectIndices(q);
      correct =
          hotspotSelectedOrder.length == correctIndices.length &&
          List.generate(
            correctIndices.length,
            (i) => hotspotSelectedOrder[i] == correctIndices[i],
          ).every((v) => v);
    } else if (isMulti) {
      final options = q['options'] as List;
      final answersRaw = q['answers'] ?? q['answer'];
      List<int> correctIndices = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
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
      }

      final selectedSet = selectedOptions.toSet();
      final correctSet = correctIndices.toSet();
      correct =
          selectedSet.length == correctSet.length &&
          selectedSet.difference(correctSet).isEmpty;
    } else {
      if (selectedOption == null) return;
      final options = q['options'] as List;
      final answersRaw = q['answers'] ?? q['answer'];
      List<int> correctIndices = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
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
      correct = correctIndices.contains(selectedOption);
    }

    setState(() {
      submitted = true;
      isCorrect = correct;
      userAnswers[currentIndex] = isHotspot
          ? hotspotSelectedOrder.isNotEmpty
                ? 1
                : -1
          : isMulti
          ? selectedOptions.isNotEmpty
                ? 1
                : -1
          : selectedOption ?? -1;
    });

    // Play sound effects based on result
    final soundService = SoundService();
    if (correct) {
      score++;
      soundService.playCorrectSound();
    } else {
      mistakes.add(currentIndex);
      soundService.playIncorrectSound();
    }
  }

  void _next() {
    setState(() {
      if (currentIndex < quizQuestions.length - 1) {
        currentIndex++;
        selectedOption = null;
        selectedOptions.clear();
        hotspotSelectedOrder.clear();
        submitted = false;
        isCorrect = false;
      } else {
        finished = true;
        // Play completion sound
        final soundService = SoundService();
        soundService.playCompletionSound();
        // Save score to progress
        _saveScore();
      }
    });
  }

  Future<void> _saveScore() async {
    final percent = (score / quizQuestions.length * 100).toInt();

    // Get existing quiz scores or initialize empty list
    final existingScores =
        (progressProvider.progress['quizScores'] as List?)?.cast<int>() ?? [];

    // Add new score
    existingScores.add(percent);

    // Update progress with new quiz scores
    progressProvider.updateProgress(examId: examId, quizScores: existingScores);

    // Save to storage (only if auto-save is enabled)
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.autoSaveProgress) {
      await progressProvider.saveProgress(examId);
    }
  }

  void _startNew() {
    final theme = Theme.of(context);
    int startQ = 1;
    int endQ = widget.questions.length;
    int minQ = 1;
    int maxQ = widget.questions.length;

    // Create text controllers outside StatefulBuilder to avoid recreation
    final startController = TextEditingController(text: startQ.toString());
    final endController = TextEditingController(text: endQ.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Question Range',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select a range of questions to quiz ($minQ-$maxQ)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Question:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: startController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                startQ = int.tryParse(value) ?? minQ;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Question:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: endController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                endQ = int.tryParse(value) ?? maxQ;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (startQ <= endQ && startQ >= minQ && endQ <= maxQ) {
                      Navigator.pop(context);
                      final route =
                          '/quiz-range/${widget.examId}/$startQ/$endQ';
                      try {
                        context.pushReplacement(route);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Navigation failed: $e'),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please enter a valid range (start ≤ end)',
                          ),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<int> _getCorrectIndices(Map<String, dynamic> q) {
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);
    final options = q['options'] as List;

    if (isHotspot) {
      final answersRaw = q['answers'] ?? q['answer'];
      if (answersRaw is List) {
        List<int> correctIndices = [];
        for (var answerText in answersRaw) {
          final aStr = answerText.toString().trim();
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) {
            correctIndices.add(idx + 1);
          }
        }
        return correctIndices;
      } else {
        final answerText = answersRaw?.toString() ?? '';
        final correctOrder = answerText
            .split('|')
            .map((s) => s.trim())
            .toList();
        List<int> correctIndices = [];
        for (var ans in correctOrder) {
          final aStr = ans.toString().trim();
          int idx;
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            idx = aStr.toUpperCase().codeUnitAt(0) - 65;
          } else if (int.tryParse(aStr) != null) {
            idx = int.tryParse(aStr)!;
          } else {
            idx = options.indexWhere((o) => o.toString().trim() == aStr);
          }
          correctIndices.add(idx + 1);
        }
        return correctIndices;
      }
    } else {
      final answersRaw = q['answers'] ?? q['answer'];
      List<int> correctIndices = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
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
  }

  String _getCorrectAnswerText(Map<String, dynamic> q) {
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);
    final options = q['options'] as List;

    if (isHotspot) {
      final answersRaw = q['answers'] ?? q['answer'];
      List<String> correctOptions = [];

      if (answersRaw is List) {
        correctOptions = answersRaw.map((a) => a.toString().trim()).toList();
      } else {
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

  int _getOriginalQuestionNumber(Map<String, dynamic> question) {
    final originalIndex = widget.questions.indexWhere(
      (q) =>
          q['text'] == question['text'] &&
          q['options'].join('_') == question['options'].join('_'),
    );
    return originalIndex + 1;
  }

  // AI Explanation methods
  Future<void> _getAIExplanation(int questionIndex) async {
    if (_isLoadingExplanations[questionIndex] == true) return;

    final question = quizQuestions[questionIndex];
    final options = question['options'] as List;
    final userAnswer = _getUserAnswerText(questionIndex);

    setState(() {
      _isLoadingExplanations[questionIndex] = true;
    });

    try {
      final explanation = await AIService.getExplanation(
        questionText: question['text'] ?? '',
        options: options.map((o) => o.toString()).toList(),
        correctAnswers: _getCorrectAnswerText(
          question,
        ).split(': ').last.split(',').map((s) => s.trim()).toList(),
        selectedAnswer: userAnswer,
        questionImages: question['question_images']?.cast<String>() ?? [],
        answerImages: question['answer_images']?.cast<String>() ?? [],
        existingExplanation: _aiExplanations[questionIndex],
      );

      setState(() {
        _aiExplanations[questionIndex] = explanation;
        _isLoadingExplanations[questionIndex] = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingExplanations[questionIndex] = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get AI explanation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _regenerateAIExplanation(int questionIndex) async {
    if (_regenerationAttempts[questionIndex] == null) {
      _regenerationAttempts[questionIndex] = 0;
    }

    if (_regenerationAttempts[questionIndex]! >= _maxRegenerationAttempts) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Maximum regeneration attempts reached'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    _regenerationAttempts[questionIndex] =
        _regenerationAttempts[questionIndex]! + 1;
    await _getAIExplanation(questionIndex);
  }

  String _getUserAnswerText(int questionIndex) {
    final question = quizQuestions[questionIndex];
    final isHotspot = question['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(question);
    final options = question['options'] as List;

    if (isHotspot) {
      // For hotspot questions, we need to track the order
      // This is a simplified version - you might want to store the actual order
      return 'Hotspot selection';
    } else if (isMulti) {
      if (userAnswers[questionIndex] == -1) return 'No answer selected';
      final selectedIndices = selectedOptions;
      if (selectedIndices.isEmpty) return 'No answer selected';
      return selectedIndices
          .map((i) => '${String.fromCharCode(65 + i)}. ${options[i]}')
          .join(', ');
    } else {
      if (userAnswers[questionIndex] == -1) return 'No answer selected';
      final selectedIndex = userAnswers[questionIndex];
      if (selectedIndex < 0 || selectedIndex >= options.length) {
        return 'Invalid selection';
      }
      return '${String.fromCharCode(65 + selectedIndex)}. ${options[selectedIndex]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return _buildQuizCompleteScreen();
    }

    if (quizQuestions.isEmpty) {
      return _buildEmptyState();
    }

    final q = quizQuestions[currentIndex];
    final options = q['options'] as List;
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);
    final isLastQuestion = currentIndex == quizQuestions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quiz Mode',
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
            if (submitted &&
                isHotspot &&
                q['answer_images'] != null &&
                q['answer_images'] is List &&
                q['answer_images'].isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAnswerImages(q['answer_images']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCompleteScreen() {
    final theme = Theme.of(context);
    final percent = (score / quizQuestions.length * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quiz Complete',
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
                  Icons.emoji_events_rounded,
                  size: 48,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Quiz Complete! 🏆',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
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
                            Icons.score_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Final Score',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$score out of ${quizQuestions.length} questions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: score / quizQuestions.length,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    if (mistakes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${mistakes.length} mistakes to review',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/exam/${widget.examId}'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Exam'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _restartQuiz,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restart Quiz'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _startNew,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('New Range'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quiz Mode',
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
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Questions Available',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'There are no questions available for the selected range.',
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
    final progress = (currentIndex + 1) / quizQuestions.length;

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
                  Icons.trending_up_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Question ${currentIndex + 1} of ${quizQuestions.length}',
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
                  color: theme.colorScheme.primary,
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
                theme.colorScheme.primary,
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
    final originalQuestionNumber = _getOriginalQuestionNumber(q);

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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$originalQuestionNumber',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
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

          // AI Explanation section
          if (submitted) ...[
            const SizedBox(height: 20),
            _buildAIExplanationSection(currentIndex),
          ],
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

  Widget _buildAIExplanationSection(int questionIndex) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return AIExplanationCard(
      explanation: _aiExplanations[questionIndex],
      isLoading: _isLoadingExplanations[questionIndex] == true,
      regenerationAttempts: _regenerationAttempts[questionIndex] ?? 0,
      maxRegenerationAttempts: _maxRegenerationAttempts,
      onGetExplanation: () => _getAIExplanation(questionIndex),
      onRegenerate: () => _regenerateAIExplanation(questionIndex),
      isApiKeyConfigured: settings.isApiKeyConfigured,
      onShowApiKeyDialog: () => _showApiKeyDialog(context),
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
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
              label: Text(isLastQuestion ? 'Finish Quiz' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastQuestion
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                foregroundColor: isLastQuestion
                    ? theme.colorScheme.onSecondary
                    : theme.colorScheme.onPrimary,
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

  Widget _parseExplanationText(String text) {
    final theme = Theme.of(context);
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(
      r'\*\*(.*?)\*\*',
      multiLine: true,
      dotAll: true,
    );
    int currentIndex = 0;

    for (final Match match in boldPattern.allMatches(text)) {
      // Add text before the bold part
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        );
      }

      // Add the bold text
      spans.add(
        TextSpan(
          text: match.group(1),
          style: theme.textTheme.bodyMedium?.copyWith(
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
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      );
    }

    // If no bold patterns found, return regular text
    if (spans.isEmpty) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showApiKeyDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
          'Please configure your OpenAI API key in settings to use AI explanations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings');
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}
