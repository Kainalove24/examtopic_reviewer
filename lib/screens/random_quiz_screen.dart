import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/ai_explanation_card.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../services/image_service.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

class RandomQuizScreen extends StatefulWidget {
  final String examTitle;
  final String examId;
  final int start;
  final int end;
  final List<Map<String, dynamic>> questions;

  const RandomQuizScreen({
    super.key,
    required this.examTitle,
    required this.examId,
    required this.start,
    required this.end,
    required this.questions,
  });

  @override
  State<RandomQuizScreen> createState() => _RandomQuizScreenState();
}

class _RandomQuizScreenState extends State<RandomQuizScreen>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  int? selectedOption;
  List<int> selectedOptions = [];
  List<int> hotspotSelectedOrder = [];
  bool submitted = false;
  bool isCorrect = false;
  bool showRepeatPrompt = false;

  // New queue management system
  List<Map<String, dynamic>> queue = [];
  Map<String, int> questionRepeatCount =
      {}; // Tracks how many times each question has been repeated
  Set<String> masteredQuestions = {}; // Questions marked as mastered
  Set<String> mistakeQuestions = {}; // Questions in mistake list
  Set<String> correctlyAnsweredQuestions =
      {}; // Questions answered correctly at least once
  Map<String, int> masteryAttempts =
      {}; // Tracks correct answers per question (threshold: 3)
  int totalQuestionsToProcess =
      0; // Total questions that will be processed in this session
  int processedQuestions = 0; // Questions that have been processed

  // Progress tracking
  late ProgressProvider progressProvider;

  // Session persistence
  bool _hasActiveSession = false;
  Map<String, dynamic>? _savedSessionData;

  List<Map<String, dynamic>> get quizQuestions => queue;

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
    WidgetsBinding.instance.addObserver(this);
    progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    _loadSessionData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save session data when leaving the screen
    _saveSessionData();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Save session data when app is paused
      _saveSessionData();
    }
  }

  Future<void> _initializeQueue() async {
    // Reset all answer states first
    _resetAnswerStates();

    // Reset quiz state for new range
    currentIndex = 0;
    processedQuestions = 0;
    questionRepeatCount.clear(); // Reset repeat counts for new range

    // Load existing progress
    await progressProvider.loadProgress(widget.examId);

    // Get mastered and mistake questions from progress
    final progress = progressProvider.progress;
    final masteredList =
        (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];
    final mistakesList =
        (progress['mistakeQuestions'] as List?)?.cast<String>() ?? [];
    final correctlyAnsweredList =
        (progress['correctlyAnsweredQuestions'] as List?)?.cast<String>() ?? [];
    final masteryAttemptsData =
        (progress['masteryAttempts'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as int),
        ) ??
        {};

    setState(() {
      masteredQuestions = masteredList.toSet();
      mistakeQuestions = mistakesList.toSet();
      correctlyAnsweredQuestions = correctlyAnsweredList.toSet();
      masteryAttempts = masteryAttemptsData;
    });

    // Get initial questions from the selected range
    final initialQuestions = widget.questions.sublist(
      widget.start - 1,
      widget.end,
    );

    // Filter out already mastered questions, but include mistake questions
    // BUT only include mistake questions that are within the selected range
    final questionsToStudy = initialQuestions.where((q) {
      final questionId = _getQuestionId(q);
      return !masteredQuestions.contains(questionId);
    }).toList();

    // Add mistake questions ONLY from the selected range (not entire exam)
    final mistakeQuestionsToAdd = initialQuestions.where((q) {
      final questionId = _getQuestionId(q);
      return mistakeQuestions.contains(questionId);
    }).toList();

    // Combine questions to study with mistake questions
    final combinedQuestions = [...questionsToStudy, ...mistakeQuestionsToAdd];

    // Shuffle the questions
    final random = Random();
    combinedQuestions.shuffle(random);

    setState(() {
      queue = combinedQuestions;
      totalQuestionsToProcess = combinedQuestions.length; // Initialize total
      // Initialize repeat count for new questions
      for (final q in combinedQuestions) {
        final questionId = _getQuestionId(q);
        if (!questionRepeatCount.containsKey(questionId)) {
          questionRepeatCount[questionId] = 0;
        }
      }
    });
  }

  String _getQuestionId(Map<String, dynamic> question) {
    // Create a unique ID for the question based on its content using hash codes
    final textHash = question['text']?.hashCode ?? 0;
    final optionsHash = question['options']?.hashCode ?? 0;
    return '${textHash}_${optionsHash}';
  }

  int _getOriginalQuestionNumber(Map<String, dynamic> question) {
    // Find the original index of this question in the full questions list
    final originalIndex = widget.questions.indexWhere(
      (q) => _getQuestionId(q) == _getQuestionId(question),
    );
    return originalIndex + 1; // Convert to 1-based numbering
  }

  void _addToMistakes(String questionId) {
    setState(() {
      mistakeQuestions.add(questionId);
    });
    // Save to progress
    _saveProgress();
  }

  void _reinsertQuestionRandomly(Map<String, dynamic> question) {
    final questionId = _getQuestionId(question);
    final currentAttempts = masteryAttempts[questionId] ?? 0;

    // Only reinsert if mastery threshold (3 correct answers) hasn't been reached
    if (currentAttempts < 3) {
      // Reinsert randomly in the queue, but ensure it's far from current position
      final random = Random();

      // Calculate a minimum distance from current position (at least 3 questions away)
      final minDistance = 3;
      final currentPos = currentIndex;
      final queueLength = queue.length;

      // Find a suitable insertion point that's far from current position
      int insertIndex;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        insertIndex = random.nextInt(queueLength + 1);
        attempts++;

        // If we can't find a good position after max attempts, just insert at the end
        if (attempts >= maxAttempts) {
          insertIndex = queueLength;
          break;
        }
      } while ((insertIndex - currentPos).abs() < minDistance &&
          attempts < maxAttempts);

      // Create a deep copy of the question to avoid reference issues
      final questionCopy = Map<String, dynamic>.from(question);

      // Ensure the question type and structure are preserved
      if (questionCopy['type'] == null) {
        questionCopy['type'] = 'mcq'; // Default type
      }

      // Ensure options are properly copied
      if (questionCopy['options'] != null) {
        questionCopy['options'] = List.from(questionCopy['options']);
      }

      // Ensure answers are properly copied
      if (questionCopy['answers'] != null) {
        if (questionCopy['answers'] is List) {
          questionCopy['answers'] = List.from(questionCopy['answers']);
        }
      }

      setState(() {
        queue.insert(insertIndex, questionCopy);
        // Update total questions to process (add one more for this repeat)
        totalQuestionsToProcess++;
      });

      print(
        'Debug: Question reinserted at position $insertIndex. Queue length: ${queue.length}',
      );
      print('Debug: Reinserted question type: ${questionCopy['type']}');
      print('Debug: Reinserted question options: ${questionCopy['options']}');
      print('Debug: Reinserted question answers: ${questionCopy['answers']}');
      print('Debug: Current mastery attempts for question: $currentAttempts');
    }
    // If mastery threshold reached (3 correct answers), don't reinsert
  }

  void _markAsMastered(String questionId) {
    setState(() {
      masteredQuestions.add(questionId);
      mistakeQuestions.remove(questionId);
    });
    // Save to progress
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    progressProvider.updateProgress(
      examId: widget.examId,
      masteredQuestions: masteredQuestions.toList(),
      mistakeQuestions: mistakeQuestions.toList(),
      correctlyAnsweredQuestions: correctlyAnsweredQuestions.toList(),
      masteryAttempts: masteryAttempts,
    );
    await progressProvider.saveProgress(widget.examId);
  }

  Future<void> _saveSessionData() async {
    if (queue.isNotEmpty) {
      final sessionData = {
        'examId': widget.examId,
        'examTitle': widget.examTitle,
        'start': widget.start,
        'end': widget.end,
        'currentIndex': currentIndex,
        'processedQuestions': processedQuestions,
        'totalQuestionsToProcess': totalQuestionsToProcess,
        'queue': queue,
        'masteryAttempts': masteryAttempts,
        'correctlyAnsweredQuestions': correctlyAnsweredQuestions.toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      progressProvider.updateProgress(
        examId: widget.examId,
        lastSession: sessionData,
      );
      await progressProvider.saveProgress(widget.examId);

      setState(() {
        _hasActiveSession = true;
        _savedSessionData = sessionData;
      });

      print('Debug: Session data saved');
    }
  }

  Future<void> _loadSessionData() async {
    final progress = progressProvider.progress;
    final lastSession = progress['lastSession'] as Map<String, dynamic>?;

    if (lastSession != null && lastSession['examId'] == widget.examId) {
      // Check if session is from today (within 72 hours)
      final sessionTimestamp = lastSession['timestamp'] as int? ?? 0;
      final sessionTime = DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);
      final now = DateTime.now();
      final difference = now.difference(sessionTime);

      if (difference.inHours < 72) {
        // Show resume dialog
        final shouldResume = await _showResumeDialog(lastSession);

        if (shouldResume) {
          setState(() {
            currentIndex = lastSession['currentIndex'] ?? 0;
            processedQuestions = lastSession['processedQuestions'] ?? 0;
            totalQuestionsToProcess =
                lastSession['totalQuestionsToProcess'] ?? 0;
            queue = List<Map<String, dynamic>>.from(lastSession['queue'] ?? []);
            masteryAttempts = Map<String, int>.from(
              lastSession['masteryAttempts'] ?? {},
            );
            correctlyAnsweredQuestions = Set<String>.from(
              lastSession['correctlyAnsweredQuestions'] ?? [],
            );
            _hasActiveSession = true;
            _savedSessionData = lastSession;
          });

          print('Debug: Session resumed - ${queue.length} questions remaining');
          return;
        } else {
          // User chose to start fresh, clear session data
          await _clearSessionData();
        }
      }
    }

    // No valid session data or user chose to start fresh
    await _initializeQueue();
  }

  Future<bool> _showResumeDialog(Map<String, dynamic> sessionData) async {
    final theme = Theme.of(context);
    final remainingQuestions = (sessionData['queue'] as List?)?.length ?? 0;
    final processedQuestions = sessionData['processedQuestions'] ?? 0;
    final totalQuestions = sessionData['totalQuestionsToProcess'] ?? 0;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.restore_rounded,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Resume Session?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have an unfinished study session:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions ${sessionData['start']}-${sessionData['end']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remaining: $remainingQuestions questions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Progress: $processedQuestions/$totalQuestions processed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Start Fresh'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                ),
                child: const Text('Resume'),
              ),
            ],
          ),
        ) ??
        false;
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
      final originalQuestionIndex = widget.questions.indexOf(question);
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

  void _submit() {
    // Safety check: ensure we have questions and current index is valid
    if (queue.isEmpty || currentIndex >= queue.length) {
      print(
        'Debug: Queue is empty or invalid currentIndex: $currentIndex, queue length: ${queue.length}',
      );
      return;
    }

    final q = queue[currentIndex];
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);

    // Additional safety check for hotspot questions
    if (isHotspot && hotspotSelectedOrder.isEmpty) {
      print('Debug: Hotspot question but no selection made');
      return;
    }

    bool correct = false;

    if (isHotspot) {
      final correctIndices = _getCorrectIndices(q);
      print('Debug RandomQuiz: Hotspot question');
      print('Debug RandomQuiz: Question type: ${q['type']}');
      print('Debug RandomQuiz: User answer: $hotspotSelectedOrder');
      print('Debug RandomQuiz: Correct indices: $correctIndices');
      print('Debug RandomQuiz: Options: ${q['options']}');
      print('Debug RandomQuiz: Answers raw: ${q['answers']}');
      print('Debug RandomQuiz: Question ID: ${_getQuestionId(q)}');
      print(
        'Debug RandomQuiz: Repeat count: ${questionRepeatCount[_getQuestionId(q)] ?? 0}',
      );

      // Check if user has made any selection
      if (hotspotSelectedOrder.isEmpty) {
        print('Debug RandomQuiz: No user selection made');
        correct = false;
      } else if (correctIndices.isEmpty) {
        print('Debug RandomQuiz: No correct indices found');
        correct = false;
      } else {
        // Compare the selected order with correct order
        print(
          'Debug RandomQuiz: Comparing lengths - User: ${hotspotSelectedOrder.length}, Correct: ${correctIndices.length}',
        );
        print('Debug RandomQuiz: User order: $hotspotSelectedOrder');
        print('Debug RandomQuiz: Correct order: $correctIndices');

        if (hotspotSelectedOrder.length == correctIndices.length) {
          bool allMatch = true;
          for (int i = 0; i < correctIndices.length; i++) {
            if (hotspotSelectedOrder[i] != correctIndices[i]) {
              print(
                'Debug RandomQuiz: Mismatch at position $i - User: ${hotspotSelectedOrder[i]}, Correct: ${correctIndices[i]}',
              );
              allMatch = false;
              break;
            }
          }
          correct = allMatch;
        } else {
          print('Debug RandomQuiz: Length mismatch');
          correct = false;
        }
      }

      print('Debug RandomQuiz: Is correct: $correct');
    } else if (isMulti) {
      final options = q['options'] as List;
      final answersRaw = q['answers'] ?? q['answer'];
      List<int> correctIndices = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
        // Try to match by letter if possible
        correctIndices = answersRaw.map((a) {
          final aStr = a.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase().codeUnitAt(0) - 65;
          }
          // fallback to numeric or text match
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
          // fallback to numeric or text match
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
        // Try to match by letter if possible
        correctIndices = answersRaw.map((a) {
          final aStr = a.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase().codeUnitAt(0) - 65;
          }
          // fallback to numeric or text match
          if (int.tryParse(aStr) != null) {
            return int.tryParse(aStr)!;
          }
          return options.indexWhere((o) => o.toString().trim() == aStr);
        }).toList();
      } else if (answersRaw is String && answersRaw.isNotEmpty) {
        // Try to match by letter if possible
        final aStr = answersRaw.trim();
        if (aStr.length == 1 &&
            RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
          correctIndices = [aStr.toUpperCase().codeUnitAt(0) - 65];
        } else if (int.tryParse(aStr) != null) {
          // fallback to numeric
          correctIndices = [int.tryParse(aStr)!];
        } else {
          // fallback to text match
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) correctIndices = [idx];
        }
      }
      correct = correctIndices.contains(selectedOption);
    }

    print(
      'Debug: Submit - currentIndex: $currentIndex, queue length: ${queue.length}, correct: $correct',
    );

    setState(() {
      submitted = true;
      isCorrect = correct;
      showRepeatPrompt = false;
    });

    final questionId = _getQuestionId(q);

    if (correct) {
      // Check if this question was previously answered incorrectly
      final wasPreviouslyIncorrect = mistakeQuestions.contains(questionId);
      final currentAttempts = masteryAttempts[questionId] ?? 0;
      final newAttempts = currentAttempts + 1;

      // Update mastery attempts
      setState(() {
        masteryAttempts[questionId] = newAttempts;
        correctlyAnsweredQuestions.add(questionId);
      });

      if (wasPreviouslyIncorrect) {
        // Previously incorrect, now correct - check if mastery threshold reached
        if (newAttempts >= 3) {
          // Mastery threshold reached - mark as mastered
          _markAsMastered(questionId);
          _next();
        } else {
          // Not yet mastered - show mastery options
          setState(() {
            showRepeatPrompt = true;
          });
        }
      } else {
        // First time answering this question correctly - check mastery threshold
        if (newAttempts >= 3) {
          // Mastery threshold reached - mark as mastered
          _markAsMastered(questionId);
          _next();
        } else {
          // Not yet mastered - show mastery options
          setState(() {
            showRepeatPrompt = true;
          });
        }
      }
    } else {
      // Incorrect answer - add to mistakes and reinsert into queue
      _addToMistakes(questionId);
      _reinsertQuestionRandomly(q);

      // Don't automatically move to next question for incorrect answers
      // Let the user see the feedback and manually proceed
      // The question will be reinserted into the queue for later review
    }

    // Increment processed questions count
    setState(() {
      processedQuestions++;
    });
  }

  void _repeat(bool repeat) {
    // Safety check: ensure we have questions and current index is valid
    if (queue.isEmpty || currentIndex >= queue.length) {
      print(
        'Debug: Queue is empty or invalid currentIndex in _repeat: $currentIndex, queue length: ${queue.length}',
      );
      return;
    }

    final q = queue[currentIndex];
    final questionId = _getQuestionId(q);

    setState(() {
      showRepeatPrompt = false;
    });

    // User chooses to review later - add to mistakes and reinsert
    _addToMistakes(questionId);
    _reinsertQuestionRandomly(q);
    print('Debug: Question added to mistakes and reinserted for review');

    // Don't automatically move to next question - let user manually click "Next Question"
    // The button will be enabled now that showRepeatPrompt is false
  }

  void _resetAnswerStates() {
    selectedOption = null;
    selectedOptions.clear();
    hotspotSelectedOrder.clear();
    submitted = false;
    isCorrect = false;
    showRepeatPrompt = false;
    _aiExplanation = null;
    _isLoadingExplanation = false;
    _regenerationAttempts = 0;
  }

  void _next() {
    print(
      'Debug: _next - before: currentIndex: $currentIndex, queue length: ${queue.length}',
    );

    setState(() {
      // Remove the current question from the queue since it's been processed
      if (currentIndex < queue.length) {
        final removedQuestion = queue.removeAt(currentIndex);
        print(
          'Debug: _next - removed question: ${removedQuestion['text']?.substring(0, 50)}...',
        );
      }

      // Check if we have more questions to process
      if (queue.isNotEmpty) {
        // Stay at the same index (which now points to the next question)
        // Reset ALL answer states to prevent bleeding between questions
        _resetAnswerStates();
        print(
          'Debug: _next - after: currentIndex: $currentIndex, queue length: ${queue.length}',
        );
        print(
          'Debug: _next - next question: ${queue[currentIndex]['text']?.substring(0, 50)}...',
        );
      } else {
        // No more questions in queue - session is complete
        print('Debug: _next - queue empty, finishing session');
        _finish();
      }
    });
  }

  void _finish() {
    setState(() {
      // Mark as finished
      submitted = true;
      showRepeatPrompt = false;
    });

    // Clear session data since session is complete
    _clearSessionData();

    // Save final progress
    _saveProgress();
  }

  Future<void> _clearSessionData() async {
    progressProvider.updateProgress(examId: widget.examId, lastSession: null);
    await progressProvider.saveProgress(widget.examId);

    setState(() {
      _hasActiveSession = false;
      _savedSessionData = null;
    });

    print('Debug: Session data cleared');
  }

  String? _aiExplanation;
  bool _isLoadingExplanation = false;
  int _regenerationAttempts = 0;
  static const int _maxRegenerationAttempts = 2;

  void _showAIExplanation(
    BuildContext context,
    Map<String, dynamic> question,
    int questionIndex,
  ) async {
    // Safety check: ensure we have questions and current index is valid
    if (queue.isEmpty || currentIndex >= queue.length) {
      print(
        'Debug: Queue is empty or invalid currentIndex in _showAIExplanation: $currentIndex, queue length: ${queue.length}',
      );
      return;
    }
    if (_isLoadingExplanation) return;

    // Check if we already have an explanation for this question
    final existingExplanation =
        question['ai_explanation'] ?? question['explanation'];

    // Also check ExamProvider for existing AI explanation
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final originalQuestionIndex = widget.questions.indexOf(question);
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: theme.colorScheme.onSecondaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Explanations Ready',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
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
                  'AI explanations are enabled and ready to use with the embedded API key.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
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

  void _startNew() {
    final theme = Theme.of(context);
    int startQ = 1;
    int endQ = widget.questions.length;
    int minQ = 1;
    int maxQ = widget.questions.length;

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
                      Icons.play_arrow_rounded,
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
                            'Select a range of questions to study ($minQ-$maxQ)',
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
                              controller: TextEditingController(
                                text: startQ.toString(),
                              ),
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
                              controller: TextEditingController(
                                text: endQ.toString(),
                              ),
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
                          '/randomquiz/${widget.examId}/$startQ/$endQ';
                      print('Navigating to: $route');
                      try {
                        context.go(route);
                      } catch (e) {
                        print('Navigation error: $e');
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
        // Handle list format (from exam data) - convert option texts to indices
        List<int> correctIndices = [];
        for (var answerText in answersRaw) {
          final aStr = answerText.toString().trim();
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) {
            correctIndices.add(idx + 1); // Convert to 1-based for comparison
          }
        }
        return correctIndices;
      } else {
        // Fallback to string parsing (older format)
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
        return correctIndices;
      }
    } else {
      final answersRaw = q['answers'] ?? q['answer'];
      List<int> correctIndices = [];
      if (answersRaw is List && answersRaw.isNotEmpty) {
        // Try to match by letter if possible
        correctIndices = answersRaw.map((a) {
          final aStr = a.toString().trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            return aStr.toUpperCase().codeUnitAt(0) - 65;
          }
          // fallback to numeric or text match
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
            // fallback to numeric or text match
            if (int.tryParse(aStr) != null) {
              return int.tryParse(aStr)!;
            }
            return options.indexWhere((o) => o.toString().trim() == aStr);
          }).toList();
        } else {
          // Try to match by letter if possible
          final aStr = answersRaw.trim();
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            correctIndices = [aStr.toUpperCase().codeUnitAt(0) - 65];
          } else if (int.tryParse(aStr) != null) {
            // fallback to numeric
            correctIndices = [int.tryParse(aStr)!];
          } else {
            // fallback to text match
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

  @override
  Widget build(BuildContext context) {
    // Check if session is finished (submitted = true and queue is empty)
    if (submitted && queue.isEmpty) {
      return _buildSessionCompleteState();
    }

    // Check if queue is empty (all questions in range are mastered)
    if (queue.isEmpty) {
      return _buildEmptyState();
    }

    // Safety check: ensure we have questions and current index is valid
    if (currentIndex >= queue.length) {
      return _buildSessionCompleteState();
    }

    final q = queue[currentIndex];
    final options = q['options'] as List;
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);
    int masteredCount = masteredQuestions.length;
    final isLastQuestion = currentIndex == queue.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Random Quiz',
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
              if (showRepeatPrompt) ...[
                _buildRepeatPrompt(),
                const SizedBox(height: 16),
              ],
              _buildAIExplanationSection(q),
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
          'Random Quiz',
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
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'All Questions Mastered! 🎉',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'All questions in the selected range (${widget.start}-${widget.end}) are already mastered.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Great job! You can select a different range or review your mistakes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
                    onPressed: _startNew,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('New Range'),
                    style: ElevatedButton.styleFrom(
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

  Widget _buildSessionCompleteState() {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Random Quiz',
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
                'Session Complete! 🏆',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'All questions have been processed successfully.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
                    onPressed: _startNew,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Start New'),
                    style: ElevatedButton.styleFrom(
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

  Widget _buildProgressSection() {
    final theme = Theme.of(context);
    final progress = queue.isNotEmpty ? (currentIndex + 1) / queue.length : 0.0;

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
                      'Question ${currentIndex + 1} of ${queue.length}',
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total to process: $totalQuestionsToProcess',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Processed: $processedQuestions',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_hasActiveSession) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restore_rounded,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Resumed Session',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          Text(
            q['text'] ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Answer Images',
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
              onPressed: showRepeatPrompt
                  ? null // Disable button when repeat prompt is shown
                  : (isLastQuestion ? _finish : _next),
              icon: Icon(
                isLastQuestion
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(isLastQuestion ? 'Finish Session' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: showRepeatPrompt
                    ? theme.colorScheme.surfaceContainerHighest
                    : (isLastQuestion
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary),
                foregroundColor: showRepeatPrompt
                    ? theme.colorScheme.onSurfaceVariant
                    : (isLastQuestion
                          ? theme.colorScheme.onSecondary
                          : theme.colorScheme.onPrimary),
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

  Widget _buildAIExplanationControls(
    Map<String, dynamic> q,
    ThemeData theme,
    SettingsProvider settings,
  ) {
    if (_aiExplanation == null && !_isLoadingExplanation) {
      return IconButton(
        icon: Icon(
          Icons.help_outline_rounded,
          color: theme.colorScheme.secondary,
          size: 20,
        ),
        onPressed: settings.isApiKeyConfigured
            ? () => _showAIExplanation(context, q, currentIndex)
            : () => _showApiKeyDialog(context),
        tooltip: 'Get AI Explanation',
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(
            0.3,
          ),
          padding: const EdgeInsets.all(8),
        ),
      );
    }

    if (_aiExplanation != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_regenerationAttempts < _maxRegenerationAttempts)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              onPressed: settings.isApiKeyConfigured
                  ? () => _showAIExplanation(context, q, currentIndex)
                  : () => _showApiKeyDialog(context),
              tooltip: 'Refresh AI Explanation',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer
                    .withOpacity(0.3),
                padding: const EdgeInsets.all(8),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: theme.colorScheme.outline,
                size: 20,
              ),
              onPressed: null,
              tooltip: 'Maximum regeneration attempts reached',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
                padding: const EdgeInsets.all(8),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _regenerationAttempts >= _maxRegenerationAttempts
                  ? theme.colorScheme.outline.withOpacity(0.2)
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_maxRegenerationAttempts - _regenerationAttempts}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _regenerationAttempts >= _maxRegenerationAttempts
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRepeatPrompt() {
    final theme = Theme.of(context);
    final q = queue[currentIndex];
    final questionId = _getQuestionId(q);
    final currentAttempts = masteryAttempts[questionId] ?? 0;
    final attemptsNeeded = 3 - currentAttempts;

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
                  Icons.repeat_rounded,
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
                      'Mastery Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currentAttempts/3 correct answers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You need $attemptsNeeded more correct answer${attemptsNeeded == 1 ? '' : 's'} to master this question. What would you like to do?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _repeat(true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Review Later'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markAsMasteredAndContinue(questionId),
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Mark Mastered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _markAsMasteredAndContinue(String questionId) {
    setState(() {
      showRepeatPrompt = false;
    });

    // Mark as mastered immediately
    _markAsMastered(questionId);

    // Move to next question
    _next();
  }
}
