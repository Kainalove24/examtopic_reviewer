import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/ai_explanation_card.dart';
import '../widgets/enhanced_image_viewer.dart';

import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/optimized_image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool showMasteryPrompt = false;
  bool showCorrectAnswerPrompt = false; // New state for showing correct answer
  bool isCorrectAnswerPrompt =
      false; // Track if prompt is for correct answer in queue phase
  String? _aiExplanation;
  bool _isLoadingExplanation = false;
  int _regenerationAttempts = 0;
  static const int _maxRegenerationAttempts = 2;

  // Simplified Question Management System
  List<Map<String, dynamic>> questionList = []; // Initial questions from range
  List<Map<String, dynamic>> queueList =
      []; // Questions that need 3 correct answers
  Set<String> masteredQuestions = {}; // Questions marked as mastered
  Set<String> mistakeQuestions = {}; // Questions in mistake list

  // Streak tracking for Queue List questions
  Map<String, int> questionStreaks =
      {}; // Tracks consecutive correct answers per question

  // Session state
  bool isInQueuePhase = false; // Whether we're currently in Queue List phase
  int totalQuestionsToProcess = 0;
  int processedQuestions = 0;

  // Session persistence
  bool _isSessionLoaded = false;
  static const String _sessionKey = 'random_quiz_session';

  // Progress tracking
  late ProgressProvider progressProvider;

  List<Map<String, dynamic>> get currentQuestions =>
      isInQueuePhase ? queueList : questionList;
  Map<String, dynamic>? get currentQuestion =>
      currentIndex < currentQuestions.length
      ? currentQuestions[currentIndex]
      : null;

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
        child: FutureBuilder<String?>(
          future: OptimizedImageService.loadImage(imageData),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 120,
                color: Colors.grey.shade100,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              print(
                'Error loading image through OptimizedImageService: ${snapshot.error}',
              );
              return _buildErrorImage();
            }

            final processedUrl = snapshot.data ?? imageData;

            return Image.network(
              processedUrl,
              height: 120,
              fit: BoxFit.contain,
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
                return _buildErrorImage();
              },
            );
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
    // Check for existing session and let user choose
    _checkForExistingSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save session when disposing
    _saveSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Save session data when app is paused
      _saveSession();
    }
  }

  // Save current session state
  Future<void> _saveSession() async {
    try {
      final sessionData = {
        'examId': widget.examId,
        'start': widget.start,
        'end': widget.end,
        'questionList': questionList,
        'queueList': queueList,
        'masteredQuestions': masteredQuestions.toList(),
        'mistakeQuestions': mistakeQuestions.toList(),
        'questionStreaks': questionStreaks,
        'isInQueuePhase': isInQueuePhase,
        'currentIndex': currentIndex,
        'totalQuestionsToProcess': totalQuestionsToProcess,
        'processedQuestions': processedQuestions,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(sessionData));
      print('Debug: Session saved successfully');
    } catch (e) {
      print('Debug: Error saving session: $e');
    }
  }

  // Load existing session state
  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionString = prefs.getString(_sessionKey);

      if (sessionString != null) {
        final sessionData = jsonDecode(sessionString) as Map<String, dynamic>;

        // Check if this session is for the same exam and range
        if (sessionData['examId'] == widget.examId &&
            sessionData['start'] == widget.start &&
            sessionData['end'] == widget.end) {
          // Check if session is not too old (72 hours)
          final timestamp = sessionData['timestamp'] as int;
          final sessionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final difference = now.difference(sessionTime);

          if (difference.inHours < 72) {
            // Load session data
            setState(() {
              questionList = List<Map<String, dynamic>>.from(
                sessionData['questionList'] ?? [],
              );
              queueList = List<Map<String, dynamic>>.from(
                sessionData['queueList'] ?? [],
              );
              masteredQuestions = Set<String>.from(
                sessionData['masteredQuestions'] ?? [],
              );
              mistakeQuestions = Set<String>.from(
                sessionData['mistakeQuestions'] ?? [],
              );
              questionStreaks = Map<String, int>.from(
                sessionData['questionStreaks'] ?? {},
              );
              isInQueuePhase = sessionData['isInQueuePhase'] ?? false;
              currentIndex = sessionData['currentIndex'] ?? 0;
              totalQuestionsToProcess =
                  sessionData['totalQuestionsToProcess'] ?? 0;
              processedQuestions = sessionData['processedQuestions'] ?? 0;
              _isSessionLoaded = true;
            });

            print('Debug: Session loaded successfully');
            print('Debug: Question List: ${questionList.length} questions');
            print('Debug: Queue List: ${queueList.length} questions');
            print(
              'Debug: Current phase: ${isInQueuePhase ? "Queue List" : "Question List"}',
            );
            print('Debug: Current index: $currentIndex');
            return;
          } else {
            print(
              'Debug: Session expired (older than 72 hours), starting fresh',
            );
          }
        } else {
          print('Debug: Session is for different exam/range, starting fresh');
        }
      }

      // No valid session found, start fresh
      _initializeQueue();
    } catch (e) {
      print('Debug: Error loading session: $e');
      // Start fresh if loading fails
      _initializeQueue();
    }
  }

  // Clear session data
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('Debug: Session cleared');
    } catch (e) {
      print('Debug: Error clearing session: $e');
    }
  }

  Future<void> _initializeQueue() async {
    print(
      'Debug: Initializing session for range ${widget.start}-${widget.end}',
    );

    // Load existing progress
    await progressProvider.loadProgress(widget.examId);

    // Get mastered and mistake questions from progress
    final progress = progressProvider.progress;
    final masteredList =
        (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];
    final mistakesList =
        (progress['mistakeQuestions'] as List?)?.cast<String>() ?? [];

    print(
      'Debug: Loading progress - Mistake questions from provider: ${mistakesList.length}',
    );
    print('Debug: Loading progress - Mistake questions: $mistakesList');

    setState(() {
      masteredQuestions = masteredList.toSet();
      mistakeQuestions = mistakesList.toSet();
    });

    print(
      'Debug: Progress loaded - Mistake questions in state: ${mistakeQuestions.length}',
    );

    // Get initial questions from the selected range
    final initialQuestions = widget.questions.sublist(
      widget.start - 1,
      widget.end,
    );

    // Filter questions to include in Question List:
    // 1. Questions that are NOT mastered
    // 2. Questions within the selected range
    final questionsToInclude = initialQuestions.where((q) {
      final questionId = _getQuestionId(q);

      // Exclude mastered questions
      if (masteredQuestions.contains(questionId)) {
        print('Debug: Excluding question $questionId - already mastered');
        return false;
      }

      // Include all non-mastered questions from the range
      print(
        'Debug: Including question $questionId - in range and not mastered',
      );
      return true;
    }).toList();

    // Check if all questions in the range are mastered
    if (questionsToInclude.isEmpty) {
      print(
        'Debug: All questions in range ${widget.start}-${widget.end} are mastered',
      );
      setState(() {
        questionList = [];
        queueList = [];
        totalQuestionsToProcess = 0;
      });
      return;
    }

    // Shuffle the questions for Question List
    final random = Random();
    questionsToInclude.shuffle(random);

    setState(() {
      questionList = questionsToInclude;
      queueList = []; // Start with empty Queue List
      totalQuestionsToProcess = questionsToInclude.length;
      isInQueuePhase = false; // Start in Question List phase
      currentIndex = 0;

      // Initialize streaks for questions
      for (final q in questionsToInclude) {
        final questionId = _getQuestionId(q);
        questionStreaks[questionId] = 0;
      }
    });

    // Reset answer states to ensure clean start
    _resetAnswerStates();
    print('Debug: Answer states reset after session initialization');

    print(
      'Debug: Session initialized with ${questionsToInclude.length} questions in Question List',
    );
    print('Debug: Questions in range: ${initialQuestions.length}');
    print(
      'Debug: Mastered questions in range: ${initialQuestions.where((q) => masteredQuestions.contains(_getQuestionId(q))).length}',
    );
  }

  String _getQuestionId(Map<String, dynamic> question) {
    // Create a unique ID for the question based on its content using hash codes
    final textHash = question['text']?.hashCode ?? 0;
    final optionsHash = question['options']?.hashCode ?? 0;
    return '${textHash}_$optionsHash';
  }

  void _addToMistakes(String questionId) {
    // Only add if not already in mistakes list (avoid duplicates)
    if (!mistakeQuestions.contains(questionId)) {
      setState(() {
        mistakeQuestions.add(questionId);
      });
      print('Debug: Question $questionId added to mistakes list');
    } else {
      print(
        'Debug: Question $questionId already in mistakes list (no duplicate)',
      );
    }
    print('Debug: Total mistakes: ${mistakeQuestions.length}');

    // Save to progress immediately
    _saveProgress();
  }

  void _addToQueueList(Map<String, dynamic> question) {
    final questionId = _getQuestionId(question);

    // Check if question is already in Queue List
    final existingIndex = queueList.indexWhere(
      (q) => _getQuestionId(q) == questionId,
    );

    if (existingIndex == -1) {
      // Add to Queue List if not already there
      setState(() {
        queueList.add(question);
        // Shuffle the Queue List after adding to ensure randomization
        final random = Random();
        queueList.shuffle(random);
      });
      print('Debug: Question $questionId added to Queue List and shuffled');
    } else {
      print('Debug: Question $questionId already in Queue List');
    }

    // Initialize streak if not exists
    if (!questionStreaks.containsKey(questionId)) {
      questionStreaks[questionId] = 0;
    }
  }

  void _markAsMastered(String questionId) {
    setState(() {
      masteredQuestions.add(questionId);
      mistakeQuestions.remove(questionId);
    });
    // Save to progress
    _saveProgress();
  }

  void _removeFromQueue(String questionId) {
    // Remove from queue list when mastered in Queue List phase
    setState(() {
      final initialLength = queueList.length;
      queueList.removeWhere((q) => _getQuestionId(q) == questionId);
      questionStreaks.remove(questionId);
      print(
        'Debug: Queue List - removed question $questionId, queue length: ${queueList.length} (was $initialLength)',
      );
    });
    print(
      'Debug: Question $questionId removed from Queue List after 3 correct answers',
    );
  }

  Future<void> _saveProgress() async {
    print(
      'Debug: Saving progress - Mistake questions to save: ${mistakeQuestions.length}',
    );
    print('Debug: Saving progress - Mistake questions: $mistakeQuestions');

    progressProvider.updateProgress(
      examId: widget.examId,
      masteredQuestions: masteredQuestions.toList(),
      mistakeQuestions: mistakeQuestions.toList(),
    );
    await progressProvider.saveProgress(widget.examId);

    print('Debug: Progress saved successfully');
  }

  void _showAIExplanation(
    BuildContext context,
    Map<String, dynamic> question,
    int questionIndex,
  ) async {
    // Safety check: ensure we have questions and current index is valid
    if (queueList.isEmpty || currentIndex >= queueList.length) {
      print(
        'Debug: Queue is empty or invalid currentIndex in _showAIExplanation: $currentIndex, queue length: ${queueList.length}',
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
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
                          .withValues(alpha: 0.3),
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
      List<int> correctIndices = [];

      if (answersRaw is List) {
        // Handle list format (from exam data)
        correctOptions = answersRaw.map((a) => a.toString().trim()).toList();
        // Find indices for sequence
        for (var ans in correctOptions) {
          final idx = options.indexWhere((o) => o.toString().trim() == ans);
          if (idx >= 0) {
            correctIndices.add(idx);
          }
        }
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
              correctIndices.add(idx);
            }
          } else if (int.tryParse(aStr) != null) {
            final idx = int.tryParse(aStr)!;
            if (idx >= 0 && idx < options.length) {
              correctOptions.add(options[idx].toString().trim());
              correctIndices.add(idx);
            }
          } else {
            correctOptions.add(aStr);
            final idx = options.indexWhere((o) => o.toString().trim() == aStr);
            if (idx >= 0) {
              correctIndices.add(idx);
            }
          }
        }
      }

      // Create sequence string
      final sequence = correctIndices.map((i) => i + 1).join(' → ');
      return '$sequence: ${correctOptions.join(', ')}';
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
    // Check if session is finished (no more questions in either phase)
    if (questionList.isEmpty && queueList.isEmpty) {
      return _buildSessionCompleteState();
    }

    // Check if all questions in range are mastered
    if (questionList.isEmpty && queueList.isEmpty) {
      return _buildEmptyState();
    }

    // Safety check: ensure we have questions and current index is valid
    if (currentQuestion == null) {
      return _buildSessionCompleteState();
    }

    final q = currentQuestion!;
    final options = q['options'] as List;
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);

    final isLastQuestion = currentIndex == currentQuestions.length - 1;

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
        actions: [
          // Session management button
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _manualSaveSession();
                  break;
                case 'clear':
                  _showClearSessionDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(
                      Icons.save_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Text('Save Session'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Clear Session',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(),
            const SizedBox(height: 16),
            _buildQuestionCard(q, options, isHotspot, isMulti),
            const SizedBox(height: 12),
            _buildActionButtons(isHotspot, isMulti, isLastQuestion),
            if (submitted) ...[
              if (showMasteryPrompt) ...[
                _buildMasteryPrompt(),
                const SizedBox(height: 8),
              ],
              if (showCorrectAnswerPrompt) ...[
                _buildCorrectAnswerPrompt(),
                const SizedBox(height: 8),
              ],
              _buildAIExplanationSection(q),
              if (isHotspot &&
                  q['answer_images'] != null &&
                  q['answer_images'] is List &&
                  q['answer_images'].isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildAnswerImages(q['answer_images']),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showClearSessionDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Clear Session',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'This will clear your current session progress. You will need to start over from the beginning. This action cannot be undone.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearSession();
              _initializeQueue();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Session cleared'),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Clear Session'),
          ),
        ],
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
                    onPressed: _continueSession,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Continue Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
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
    final currentPhase = isInQueuePhase ? 'Queue List' : 'Question List';
    final progress = currentQuestions.isNotEmpty
        ? (currentIndex + 1) / currentQuestions.length
        : 0.0;
    final currentStreak = currentQuestion != null
        ? questionStreaks[_getQuestionId(currentQuestion!)] ?? 0
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
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
                      '$currentPhase - Question ${currentIndex + 1} of ${currentQuestions.length}',
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
                'Question List: ${questionList.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isInQueuePhase) ...[
                Text(
                  'Streak: $currentStreak/3',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Text(
                  'Queue List: ${queueList.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          // Session status indicator
          if (_isSessionLoaded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restore_rounded,
                    size: 12,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Session restored',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      textAlign: TextAlign.start,
                    ),
                    if (indices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: indices
                            .map(
                              (orderIdx) => Container(
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
                            )
                            .toList(),
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
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
                      ? (isCorrect ? Colors.green : theme.colorScheme.error)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (submitted) ...[const SizedBox(height: 8)],
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
        if (submitted && !showMasteryPrompt && !showCorrectAnswerPrompt) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (isLastQuestion ? _finish : _next),
              icon: Icon(
                isLastQuestion
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(isLastQuestion ? 'Finish Session' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: (isLastQuestion
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary),
                foregroundColor: (isLastQuestion
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

  Widget _buildMasteryPrompt() {
    final theme = Theme.of(context);
    final q = currentQuestion;
    if (q == null) return const SizedBox.shrink();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.star_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question Mastery',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Question answered correctly',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Text(
        'You answered this question correctly. You can mark it as mastered or add it to your practice queue for reinforcement.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addToQueueAndContinue(_getQuestionId(q)),
                icon: const Icon(Icons.queue_rounded, size: 16),
                label: const Text('Practice More'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markAsMasteredAndContinue(_getQuestionId(q)),
                icon: const Icon(Icons.star_rounded, size: 16),
                label: const Text('Mark Mastered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addToQueueAndContinue(String questionId) {
    setState(() {
      showMasteryPrompt = false;
    });

    // Get the current question
    final currentQ = currentQuestion;
    if (currentQ != null) {
      // Add to Queue List and Mistake List
      _addToQueueList(currentQ);
      _addToMistakes(questionId);
      print('Debug: Question added to Queue List and Mistake List');
    }

    // Move to next question
    _next();
  }

  void _markAsMasteredAndContinue(String questionId) {
    setState(() {
      showMasteryPrompt = false;
    });

    // Mark as mastered
    _markAsMastered(questionId);
    print('Debug: Question marked as mastered');

    // Move to next question
    _next();
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

  void _handleAnswerSubmission(bool correct) {
    if (currentQuestion == null) {
      print('Debug: No question available for answer submission');
      return;
    }

    final q = currentQuestion!;
    final questionId = _getQuestionId(q);

    if (correct) {
      if (!isInQueuePhase) {
        // Question List Phase: Correct answer
        print(
          'Debug: Question List phase - correct answer, showing mastery prompt',
        );
        setState(() {
          showMasteryPrompt = true;
        });
        // User will choose whether to mark as mastered or add to Queue List
      } else {
        // Queue List Phase: Correct answer
        final currentStreak = questionStreaks[questionId] ?? 0;
        final newStreak = currentStreak + 1;

        setState(() {
          questionStreaks[questionId] = newStreak;
        });

        print('Debug: Queue List phase - correct answer, streak: $newStreak/3');

        if (newStreak >= 3) {
          // Question mastered (3 correct answers in a row)
          print('Debug: Question $questionId mastered (3 correct in a row)');
          setState(() {
            showCorrectAnswerPrompt = true;
            isCorrectAnswerPrompt = true;
          });
          print('Debug: Queue List phase - showing mastery completion prompt');
          // Don't call _next() yet - wait for user to acknowledge
        } else {
          // Show streak update prompt before continuing
          setState(() {
            showCorrectAnswerPrompt = true;
            isCorrectAnswerPrompt = true;
          });
          print('Debug: Queue List phase - showing streak update prompt');
          // Don't call _next() yet - wait for user to acknowledge
        }
      }
    } else {
      // Incorrect answer
      if (!isInQueuePhase) {
        // Question List Phase: Incorrect answer - show correct answer first
        print(
          'Debug: Question List phase - incorrect answer, showing correct answer',
        );
        _addToMistakes(questionId);
        _addToQueueList(q);
        setState(() {
          showCorrectAnswerPrompt = true;
          isCorrectAnswerPrompt = false;
        });
        // Don't call _next() yet - wait for user to acknowledge correct answer
      } else {
        // Queue List Phase: Incorrect answer - reset streak and show correct answer
        setState(() {
          questionStreaks[questionId] = 0;
          showCorrectAnswerPrompt = true;
        });
        print(
          'Debug: Queue List phase - incorrect answer, streak reset to 0, showing correct answer',
        );
        // Don't call _next() yet - wait for user to acknowledge correct answer
      }
    }

    // Increment processed questions count
    setState(() {
      processedQuestions++;
    });

    // Save session after each question
    _saveSession();
  }

  // New method to handle user acknowledgment of correct answer
  void _acknowledgeCorrectAnswer() {
    final q = currentQuestion;
    if (q != null && isInQueuePhase) {
      final questionId = _getQuestionId(q);
      final currentStreak = questionStreaks[questionId] ?? 0;

      // Check if this question just reached 3/3 and should be removed
      if (currentStreak >= 3) {
        print('Debug: Removing mastered question $questionId from Queue List');
        _removeFromQueue(questionId);

        // Check if queue is now empty after removal
        if (queueList.isEmpty) {
          print('Debug: Queue List is now empty, finishing session');
          setState(() {
            showCorrectAnswerPrompt = false;
            isCorrectAnswerPrompt = false;
          });
          _finish();
          return;
        }
      }
    }

    setState(() {
      showCorrectAnswerPrompt = false;
      isCorrectAnswerPrompt = false;
    });
    _next();
  }

  void _submit() {
    // Safety check: ensure we have questions and current index is valid
    if (currentQuestions.isEmpty || currentIndex >= currentQuestions.length) {
      print(
        'Debug: No questions available or invalid currentIndex: $currentIndex, questions length: ${currentQuestions.length}',
      );
      return;
    }

    final q = currentQuestion!;
    final isHotspot = q['type'] == 'hotspot';
    final isMulti = _isMultiAnswer(q);

    // Debug logging to track submission
    print('Debug: _submit called - isHotspot: $isHotspot, isMulti: $isMulti');
    print('Debug: selectedOption: $selectedOption');
    print('Debug: selectedOptions: $selectedOptions');
    print('Debug: hotspotSelectedOrder: $hotspotSelectedOrder');

    // Additional safety check for hotspot questions
    if (isHotspot && hotspotSelectedOrder.isEmpty) {
      print('Debug: Hotspot question but no selection made');
      return;
    }

    // Additional safety check for multi-answer questions (but not hotspot)
    if (isMulti && !isHotspot && selectedOptions.isEmpty) {
      print('Debug: Multi-answer question but no selection made');
      return;
    }

    // Additional safety check for single-answer questions
    if (!isHotspot && !isMulti && selectedOption == null) {
      print('Debug: Single-answer question but no selection made');
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

      print('Debug: Single-answer question checking');
      print('Debug: selectedOption: $selectedOption');
      print('Debug: answersRaw: $answersRaw');
      print('Debug: options: $options');

      if (answersRaw is List && answersRaw.isNotEmpty) {
        // Try to match by letter if possible
        correctIndices = answersRaw.map((a) {
          final aStr = a.toString().trim();
          print('Debug: Processing answer: $aStr');
          if (aStr.length == 1 &&
              RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
            final index = aStr.toUpperCase().codeUnitAt(0) - 65;
            print('Debug: Letter match - $aStr -> index $index');
            return index;
          }
          // fallback to numeric or text match
          if (int.tryParse(aStr) != null) {
            final index = int.tryParse(aStr)!;
            print('Debug: Numeric match - $aStr -> index $index');
            return index;
          }
          final index = options.indexWhere((o) => o.toString().trim() == aStr);
          print('Debug: Text match - $aStr -> index $index');
          return index;
        }).toList();
      } else if (answersRaw is String && answersRaw.isNotEmpty) {
        // Try to match by letter if possible
        final aStr = answersRaw.trim();
        print('Debug: Processing string answer: $aStr');
        if (aStr.length == 1 &&
            RegExp(r'^[A-Z]$', caseSensitive: false).hasMatch(aStr)) {
          correctIndices = [aStr.toUpperCase().codeUnitAt(0) - 65];
          print('Debug: Letter match - $aStr -> index ${correctIndices[0]}');
        } else if (int.tryParse(aStr) != null) {
          // fallback to numeric
          correctIndices = [int.tryParse(aStr)!];
          print('Debug: Numeric match - $aStr -> index ${correctIndices[0]}');
        } else {
          // fallback to text match
          final idx = options.indexWhere((o) => o.toString().trim() == aStr);
          if (idx >= 0) correctIndices = [idx];
          print('Debug: Text match - $aStr -> index $idx');
        }
      }

      print('Debug: Final correctIndices: $correctIndices');
      correct = correctIndices.contains(selectedOption);
      print(
        'Debug: Is correct: $correct (selectedOption: $selectedOption, contains: ${correctIndices.contains(selectedOption)})',
      );
    }

    print(
      'Debug: Submit - currentIndex: $currentIndex, questions length: ${currentQuestions.length}, correct: $correct',
    );

    setState(() {
      submitted = true;
      isCorrect = correct;
      showMasteryPrompt = false;
    });

    _handleAnswerSubmission(correct);
  }

  void _resetAnswerStates() {
    print(
      'Debug: Resetting answer states - selectedOption: $selectedOption, selectedOptions: $selectedOptions, hotspotSelectedOrder: $hotspotSelectedOrder',
    );
    selectedOption = null;
    selectedOptions.clear();
    hotspotSelectedOrder.clear();
    submitted = false;
    isCorrect = false;
    showMasteryPrompt = false;
    showCorrectAnswerPrompt = false;
    _aiExplanation = null;
    _isLoadingExplanation = false;
    _regenerationAttempts = 0;
    print('Debug: Answer states reset complete');
  }

  void _next() {
    print(
      'Debug: _next - before: currentIndex: $currentIndex, questions length: ${currentQuestions.length}',
    );

    // Reset answer states FIRST to prevent carryover
    _resetAnswerStates();
    print('Debug: _next - answer states reset before moving to next question');

    setState(() {
      if (!isInQueuePhase) {
        // Question List Phase: Remove the current question since it's been processed
        if (currentIndex < currentQuestions.length) {
          final removedQuestion = currentQuestions.removeAt(currentIndex);
          print(
            'Debug: _next - removed question from Question List: ${removedQuestion['text']?.substring(0, 50)}...',
          );
        }
      } else {
        // Queue List Phase: Move to next question (don't remove)
        currentIndex = (currentIndex + 1) % currentQuestions.length;
        print(
          'Debug: _next - moved to next question in Queue List: $currentIndex',
        );
      }

      // Check if we have more questions to process in current phase
      if (currentQuestions.isNotEmpty) {
        print(
          'Debug: _next - after: currentIndex: $currentIndex, questions length: ${currentQuestions.length}',
        );
        print(
          'Debug: _next - next question: ${currentQuestions[currentIndex]['text']?.substring(0, 50)}...',
        );
      } else {
        // No more questions in current phase
        if (!isInQueuePhase && queueList.isNotEmpty) {
          // Switch to Queue List phase and shuffle it
          print('Debug: _next - switching to Queue List phase');
          setState(() {
            isInQueuePhase = true;
            currentIndex = 0;
            // Shuffle the Queue List when switching to Queue List phase
            final random = Random();
            queueList.shuffle(random);
            print(
              'Debug: Queue List shuffled with ${queueList.length} questions',
            );
          });
        } else {
          // No more questions in either phase - session is complete
          print('Debug: _next - no more questions, finishing session');
          _finish();
        }
      }
    });
  }

  void _finish() async {
    setState(() {
      // Mark as finished
      submitted = true;
      showMasteryPrompt = false;
    });

    print(
      'Debug: Session finishing - Total mistakes before save: ${mistakeQuestions.length}',
    );
    print('Debug: Session finishing - Mistake questions: $mistakeQuestions');

    // Save final progress
    await _saveProgress();

    print('Debug: Progress saved - Mistake questions should be preserved');

    // Clear session data since session is complete
    _clearSession();

    print('Debug: Session completed and cleared');
  }

  // Manual session save method (can be called from UI)
  Future<void> _manualSaveSession() async {
    await _saveSession();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Session saved'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCorrectAnswerPrompt() {
    final theme = Theme.of(context);
    final q = currentQuestion;
    if (q == null) return const SizedBox.shrink();

    final isHotspot = q['type'] == 'hotspot';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrectAnswerPrompt
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrectAnswerPrompt
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.colorScheme.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCorrectAnswerPrompt) ...[
            // Streak update for correct answer in queue phase
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Streak Updated',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Great job! Your streak is now ${questionStreaks[_getQuestionId(q)]}/3',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isHotspot) ...[
            // Correct answer display for incorrect answers (hotspot only)
            Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Correct Answer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getCorrectAnswerText(q),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _acknowledgeCorrectAnswer,
              icon: Icon(
                isInQueuePhase && queueList.length == 1
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(
                isInQueuePhase && queueList.length == 1
                    ? 'Finish Session'
                    : 'Continue to Next Question',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInQueuePhase && queueList.length == 1
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                foregroundColor: isInQueuePhase && queueList.length == 1
                    ? theme.colorScheme.onSecondary
                    : theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continueSession() async {
    // Load existing session
    await _loadSession();
    // Continue from the last processed question
    _next();
  }

  Future<void> _checkForExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionString = prefs.getString(_sessionKey);

      if (sessionString != null) {
        final sessionData = jsonDecode(sessionString) as Map<String, dynamic>;

        // Check if this session is for the same exam and range
        if (sessionData['examId'] == widget.examId &&
            sessionData['start'] == widget.start &&
            sessionData['end'] == widget.end) {
          // Check if session is not too old (72 hours)
          final timestamp = sessionData['timestamp'] as int;
          final sessionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final difference = now.difference(sessionTime);

          if (difference.inHours < 72) {
            // Show dialog to let user choose
            _showSessionChoiceDialog();
            return;
          }
        }
      }

      // No valid session found, start fresh
      _initializeQueue();
    } catch (e) {
      print('Debug: Error checking for existing session: $e');
      _initializeQueue();
    }
  }

  void _showSessionChoiceDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              'Continue Previous Session?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'A previous session was found for this range. Would you like to continue where you left off or start a new session?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeQueue(); // Start fresh
            },
            child: const Text('Start New'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadSession(); // Continue session
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Continue Session'),
          ),
        ],
      ),
    );
  }
}
