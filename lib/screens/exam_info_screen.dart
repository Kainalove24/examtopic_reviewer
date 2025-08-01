import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/progress_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/enhanced_image_viewer.dart';

class ExamInfoScreen extends StatefulWidget {
  final String examTitle;
  final String examId;
  final int mastered;
  final int total;
  final int setsCompleted;
  final int totalSets;
  final List<Map<String, dynamic>> questions;

  const ExamInfoScreen({
    super.key,
    required this.examTitle,
    required this.examId,
    required this.mastered,
    required this.total,
    required this.setsCompleted,
    required this.totalSets,
    required this.questions,
  });

  @override
  State<ExamInfoScreen> createState() => _ExamInfoScreenState();
}

class _ExamInfoScreenState extends State<ExamInfoScreen> {
  int currentPage = 0;
  static const int questionsPerPage = 10;
  int mastered = 0;
  bool loading = true;
  String searchQuery = '';
  List<Map<String, dynamic>> filteredQuestions = [];
  late TextEditingController searchController;

  List<bool> showAnswer = [];
  bool _isHeaderCollapsed = false;
  bool _isSearchCollapsed = false;

  // AI Explanation state variables
  final Map<int, String?> _aiExplanations = {};
  final Map<int, bool> _isLoadingExplanations = {};
  final Map<int, int> _regenerationAttempts = {};
  static const int _maxRegenerationAttempts = 2;

  @override
  void initState() {
    super.initState();
    showAnswer = List.filled(widget.questions.length, false);
    filteredQuestions = widget.questions;
    searchController = TextEditingController();
    _loadProgress();
  }

  // Question management methods
  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => _QuestionEditDialog(
        question: null,
        onSave: (questionData) async {
          setState(() {
            widget.questions.add(questionData);
            filteredQuestions = widget.questions;
            showAnswer.add(false);
          });
          await _saveQuestions();
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          await examProvider.saveAllExams();
        },
      ),
    );
  }

  void _editQuestion(int index) {
    final question = widget.questions[index];
    showDialog(
      context: context,
      builder: (context) => _QuestionEditDialog(
        question: question,
        onSave: (questionData) async {
          setState(() {
            widget.questions[index] = questionData;
            filteredQuestions = widget.questions;
          });
          await _saveQuestions();
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          await examProvider.saveAllExams();
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
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
                Icons.delete_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Question',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to delete question ${index + 1}?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: theme.colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
              setState(() {
                widget.questions.removeAt(index);
                filteredQuestions = widget.questions;
                showAnswer.removeAt(index);
              });
              _saveQuestions();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuestions() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    await examProvider.updateExamQuestions(widget.examId, widget.questions);
  }

  void _showAIExplanation(
    BuildContext context,
    Map<String, dynamic> question,
    int questionIndex,
  ) async {
    if (_isLoadingExplanations[questionIndex] == true) return;

    // Check if we already have an explanation for this question
    final existingExplanation =
        question['ai_explanation'] ?? question['explanation'];

    // Also check ExamProvider for existing AI explanation
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final savedAIExplanation = examProvider.getQuestionAIExplanation(
      widget.examId,
      questionIndex,
    );

    if (existingExplanation != null &&
        existingExplanation.toString().isNotEmpty) {
      setState(() {
        _aiExplanations[questionIndex] = existingExplanation.toString();
        _regenerationAttempts[questionIndex] = 0;
      });
      return;
    }

    // Check if there's a saved AI explanation in ExamProvider
    if (savedAIExplanation != null && savedAIExplanation.isNotEmpty) {
      print(
        'Found saved AI explanation in ExamProvider for question $questionIndex',
      );
      setState(() {
        _aiExplanations[questionIndex] = savedAIExplanation;
        _regenerationAttempts[questionIndex] = 0;
        // Update the question data to include the AI explanation
        question['ai_explanation'] = savedAIExplanation;
      });
      return;
    }

    // Check regeneration limit
    if ((_regenerationAttempts[questionIndex] ?? 0) >=
        _maxRegenerationAttempts) {
      setState(() {
        _aiExplanations[questionIndex] =
            'Maximum regeneration attempts reached. Please try again later.';
      });
      return;
    }

    setState(() {
      _isLoadingExplanations[questionIndex] = true;
      _aiExplanations[questionIndex] = null;
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
        _aiExplanations[questionIndex] = explanation;
        _isLoadingExplanations[questionIndex] = false;
        _regenerationAttempts[questionIndex] =
            (_regenerationAttempts[questionIndex] ?? 0) + 1;
      });
    } catch (e) {
      setState(() {
        _aiExplanations[questionIndex] = 'Error: ${e.toString()}';
        _isLoadingExplanations[questionIndex] = false;
        _regenerationAttempts[questionIndex] =
            (_regenerationAttempts[questionIndex] ?? 0) + 1;
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

  // Helper method to build image widget that handles local files, assets, and network images
  Widget _buildImageWidget(String imagePath) {
    // Check if it's a network image (starts with 'http://' or 'https://')
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // It's a network image, use Image.network
      return GestureDetector(
        onTap: () => _showImageDialog(context, imagePath),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imagePath,
              height: 120,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade100,
                  height: 120,
                  width: 120,
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
                print('Network image error: $error');
                return Container(
                  color: Colors.red.shade100,
                  height: 120,
                  width: 120,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.red),
                        SizedBox(height: 4),
                        Text('Image not found', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else if (imagePath.startsWith('images/')) {
      // It's a local file, use Image.file
      return FutureBuilder<String?>(
        future: _getLocalImagePath(imagePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return GestureDetector(
              onTap: () => _showImageDialog(context, snapshot.data!),
              child: Container(
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
                      print('Image file error: $error');
                      return Container(
                        color: Colors.red.shade100,
                        height: 120,
                        width: 120,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.red),
                              SizedBox(height: 4),
                              Text(
                                'Image not found',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            print('FutureBuilder error: ${snapshot.error}');
            return Container(
              color: Colors.red.shade100,
              height: 120,
              width: 120,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(height: 4),
                    Text('Error loading image', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          } else {
            return Container(
              color: Colors.grey.shade100,
              height: 120,
              width: 120,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
        },
      );
    } else {
      // It's an asset, use Image.asset
      return GestureDetector(
        onTap: () => _showImageDialog(context, imagePath),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Image asset error: $error');
                return Container(
                  color: Colors.red.shade100,
                  height: 120,
                  width: 120,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.red),
                        SizedBox(height: 4),
                        Text('Image not found', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  // Helper method to get the full path for local images
  Future<String?> _getLocalImagePath(String relativePath) async {
    try {
      print('Debug: Looking for image at relative path: $relativePath');
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = path.join(appDir.path, relativePath);
      print('Debug: Full path: $fullPath');

      final file = File(fullPath);
      final exists = await file.exists();
      print('Debug: File exists: $exists');

      if (exists) {
        final size = await file.length();
        print('Debug: File size: $size bytes');
        return fullPath;
      } else {
        print('Debug: File does not exist at: $fullPath');
        // Try alternative paths
        final altPaths = [
          path.join(appDir.path, 'images', path.basename(relativePath)),
          path.join(appDir.path, 'assets', relativePath),
          relativePath, // Try as absolute path
        ];

        for (final altPath in altPaths) {
          final altFile = File(altPath);
          if (await altFile.exists()) {
            print('Debug: Found image at alternative path: $altPath');
            return altPath;
          }
        }

        print('Debug: Image not found in any alternative paths');
        return null;
      }
    } catch (e) {
      print('Error getting local image path: $e');
      return null;
    }
  }

  // Helper method to show image in a full-screen zoomable dialog
  void _showImageDialog(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imagePath: imagePath),
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

  Future<void> _saveAIExplanation(
    Map<String, dynamic> question,
    String explanation,
  ) async {
    try {
      // Save to the question data
      question['ai_explanation'] = explanation;

      // Save to ExamProvider for persistence across screens
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final questionIndex = widget.questions.indexOf(question);
      if (questionIndex != -1) {
        await examProvider.updateQuestionAIExplanation(
          widget.examId,
          questionIndex,
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

  String? progressError;

  void _performSearch(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredQuestions = widget.questions;
        currentPage = 0;
      } else {
        // Search by question number, question text, or options
        filteredQuestions = widget.questions.where((q) {
          final questionText = (q['text'] ?? '').toString().toLowerCase();
          final questionNumber = (widget.questions.indexOf(q) + 1).toString();
          final queryLower = query.toLowerCase();

          // Check if query matches question number
          if (questionNumber.contains(queryLower)) {
            return true;
          }

          // Check if query matches keywords in question text
          if (questionText.contains(queryLower)) {
            return true;
          }

          // Check if query matches any option text
          final options = q['options'] as List?;
          if (options != null) {
            for (final option in options) {
              final optionText = option.toString().toLowerCase();
              if (optionText.contains(queryLower)) {
                return true;
              }
            }
          }

          return false;
        }).toList();
        currentPage = 0; // Reset to first page when searching
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    try {
      await progressProvider.loadProgress(widget.examId);
      final progress = progressProvider.progress;
      final masteredList =
          (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];
      setState(() {
        mastered = masteredList.length;
        loading = false;
        progressError = null;
      });
      print('Progress loaded: $mastered questions mastered');
    } catch (e) {
      // Fallback: try to get local progress if Firestore is unavailable
      setState(() {
        mastered = 0;
        loading = false;
        progressError = 'Could not load cloud progress. Working offline.';
      });
      print('Progress loading error: $e');
    }
  }

  bool _hasActiveSession() {
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final progress = progressProvider.progress;
    final lastSession = progress['lastSession'] as Map<String, dynamic>?;

    if (lastSession != null && lastSession['examId'] == widget.examId) {
      final sessionTimestamp = lastSession['timestamp'] as int? ?? 0;
      final sessionTime = DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);
      final now = DateTime.now();
      final difference = now.difference(sessionTime);

      return difference.inHours < 72;
    }
    return false;
  }

  void _resumeSession() {
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final progress = progressProvider.progress;
    final lastSession = progress['lastSession'] as Map<String, dynamic>?;

    if (lastSession != null) {
      final start = lastSession['start'] as int? ?? 1;
      final end = lastSession['end'] as int? ?? widget.questions.length;
      context.go('/randomquiz/${widget.examId}/$start/$end');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to progress provider changes
    final progressProvider = Provider.of<ProgressProvider>(context);
    final progress = progressProvider.progress;
    final currentMastered =
        (progress['masteredQuestions'] as List?)?.length ?? 0;

    // Update mastered count if it changed
    if (currentMastered != mastered && !loading) {
      setState(() {
        mastered = currentMastered;
      });
    }

    double progressValue = widget.total == 0 ? 0 : mastered / widget.total;

    // Debug: Print progress values
    print('Progress Debug:');
    print('  Mastered: $mastered');
    print('  Total: ${widget.total}');
    print('  Progress Value: $progressValue');
    final totalPages = (filteredQuestions.length / questionsPerPage).ceil();
    final startIdx = currentPage * questionsPerPage;
    final endIdx = ((currentPage + 1) * questionsPerPage).clamp(
      0,
      filteredQuestions.length,
    );
    final pageQuestions = filteredQuestions.sublist(startIdx, endIdx);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.examTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          leading: BackButton(
            onPressed: () => context.go('/library'),
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
        body: loading
            ? _buildLoadingState()
            : _buildResponsiveLayout(progressValue, pageQuestions, totalPages),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    double progressValue,
    List<Map<String, dynamic>> pageQuestions,
    int totalPages,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine if this is a small screen
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;
    final isVerySmallScreen = screenHeight < 600 || screenWidth < 350;

    return Column(
      children: [
        // Collapsible header for very small screens
        if (isVerySmallScreen) ...[
          _buildCollapsibleHeader(progressValue),
        ] else if (isSmallScreen) ...[
          _buildCompactHeaderSection(progressValue),
          _buildCompactActionButtons(),
          _buildCollapsibleSearchSection(),
        ] else ...[
          _buildHeaderSection(progressValue),
          _buildActionButtons(),
          _buildCollapsibleSearchSection(),
        ],
        Expanded(child: _buildQuestionList(pageQuestions, totalPages)),
      ],
    );
  }

  Widget _buildCollapsibleHeader(double progressValue) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapse/Expand button
          InkWell(
            onTap: () {
              setState(() {
                _isHeaderCollapsed = !_isHeaderCollapsed;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    _isHeaderCollapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Progress: ${(progressValue * 100).toStringAsFixed(0)}% ($mastered/${widget.total})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible content
          if (!_isHeaderCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 3.6, // Reduced by 10% from 4
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action buttons in a more compact layout
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRangeDialog(true),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text(
                            'Study',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRangeDialog(false),
                          icon: const Icon(Icons.quiz_rounded, size: 16),
                          label: const Text(
                            'Quiz',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.go('/mistake-review/${widget.examId}'),
                          icon: const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Review',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      searchController.clear();
                                      _performSearch('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          onChanged: _performSearch,
                          controller: searchController,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 10),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading exam details...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderSection(double progressValue) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progressError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: theme.colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progressError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Compact Progress Section
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
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$mastered/${widget.total} mastered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progressValue * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              minHeight: 5.4, // Reduced by 10% from 6
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButtons() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showRangeDialog(true),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Study', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRangeDialog(false),
              icon: const Icon(Icons.quiz_rounded, size: 18),
              label: const Text('Quiz', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: theme.colorScheme.outline, width: 1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/mistake-review/${widget.examId}'),
              icon: const Icon(Icons.error_outline_rounded, size: 18),
              label: const Text('Review', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: theme.colorScheme.outline, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSearchSection() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapse/Expand button for search section
          InkWell(
            onTap: () {
              setState(() {
                _isSearchCollapsed = !_isSearchCollapsed;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _isSearchCollapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.quiz_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question Bank',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (searchQuery.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${filteredQuestions.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible content
          if (!_isSearchCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              onPressed: () {
                                searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _performSearch,
                    controller: searchController,
                  ),
                  const SizedBox(height: 8),

                  // Add question button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Add Question',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection(double progressValue) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
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
          if (progressError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progressError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Progress Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$mastered of ${widget.total} questions mastered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progressValue * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              minHeight: 7.2, // Reduced by 10% from 8
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    final hasActiveSession = _hasActiveSession();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (hasActiveSession) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: _resumeSession,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Resume Session'),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRangeDialog(true),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Study Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRangeDialog(false),
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('Start Quiz'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/mistake-review/${widget.examId}'),
                  icon: const Icon(Icons.error_outline_rounded),
                  label: const Text('Review'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline,
                      width: 1.5,
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

  Widget _buildQuestionList(
    List<Map<String, dynamic>> pageQuestions,
    int totalPages,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pageQuestions.length,
            itemBuilder: (context, i) {
              final q = pageQuestions[i];
              final originalIdx = widget.questions.indexOf(q);
              final globalIdx = originalIdx;
              return _buildQuestionCard(q, globalIdx);
            },
          ),
        ),
        _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int globalIdx) {
    final show = showAnswer[globalIdx];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${globalIdx + 1}. ${q['text']}',
              style: theme.textTheme.titleMedium,
            ),
            // Show question images if present
            if (q['question_images'] != null &&
                q['question_images'] is List &&
                q['question_images'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...(q['question_images'] as List)
                        .whereType<String>()
                        .map((img) => img.trim())
                        .where((img) => img.isNotEmpty)
                        .map(
                          (img) => GestureDetector(
                            onTap: () {
                              showEnhancedImageViewer(
                                context,
                                img,
                                title: 'Question Image',
                              );
                            },
                            child: _buildImageWidget(img),
                          ),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(q['options'].length, (idx) {
                  final optionText = q['options'][idx];
                  final match = RegExp(
                    r'^()[\.|\)]',
                    caseSensitive: false,
                  ).firstMatch(optionText.trim());
                  final optionLetter = match != null
                      ? match.group(1)!.toUpperCase()
                      : String.fromCharCode(65 + idx);
                  final answersRaw = q['answers'] ?? q['answer'];
                  // Convert answer indices to letters for comparison
                  List<String> correctLetters = [];
                  if (answersRaw is List && answersRaw.isNotEmpty) {
                    // If the answers are numeric indices, convert to letters
                    if (int.tryParse(answersRaw[0].toString()) != null) {
                      correctLetters = answersRaw
                          .map(
                            (a) => String.fromCharCode(
                              65 + int.tryParse(a.toString())!,
                            ),
                          )
                          .toList();
                    } else {
                      correctLetters = answersRaw
                          .map((a) => a.toString().trim().toUpperCase())
                          .toList();
                    }
                  } else if (answersRaw is String && answersRaw.isNotEmpty) {
                    if (int.tryParse(answersRaw) != null) {
                      correctLetters = [
                        String.fromCharCode(65 + int.tryParse(answersRaw)!),
                      ];
                    } else {
                      correctLetters = [answersRaw.trim().toUpperCase()];
                    }
                  }
                  final isCorrect = correctLetters.contains(optionLetter);
                  return Row(
                    children: [
                      if (show && isCorrect)
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                      Text(
                        '$optionLetter. ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: show && isCorrect ? Colors.green : null,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          optionText.replaceFirst(RegExp(r'^\w[\.|\)]\s*'), ''),
                          style: TextStyle(
                            color: show && isCorrect ? Colors.green : null,
                            fontWeight: show && isCorrect
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            // Show answer images only if showAnswer[globalIdx] is true
            if (showAnswer[globalIdx] &&
                q['answer_images'] != null &&
                q['answer_images'] is List &&
                q['answer_images'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...(q['answer_images'] as List)
                        .whereType<String>()
                        .map((img) => img.trim())
                        .where((img) => img.isNotEmpty)
                        .map(
                          (img) => GestureDetector(
                            onTap: () {
                              showEnhancedImageViewer(
                                context,
                                img,
                                title: 'Answer Image',
                              );
                            },
                            child: _buildImageWidget(img),
                          ),
                        ),
                  ],
                ),
              ),

            // AI Explanation Card
            if (showAnswer[globalIdx])
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  if (!settings.aiExplanationsEnabled) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.psychology,
                                  color: Colors.purple,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Explanation',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                ),
                                const Spacer(),
                                if (_aiExplanations[globalIdx] == null &&
                                    (_isLoadingExplanations[globalIdx] != true))
                                  IconButton(
                                    icon: const Icon(
                                      Icons.help_outline,
                                      color: Colors.purple,
                                      size: 18,
                                    ),
                                    onPressed: settings.isApiKeyConfigured
                                        ? () => _showAIExplanation(
                                            context,
                                            q,
                                            globalIdx,
                                          )
                                        : () => _showApiKeyDialog(context),
                                    tooltip: 'Get AI Explanation',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                if (_aiExplanations[globalIdx] != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if ((_regenerationAttempts[globalIdx] ??
                                              0) <
                                          _maxRegenerationAttempts)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.refresh,
                                            color: Colors.purple,
                                            size: 18,
                                          ),
                                          onPressed: settings.isApiKeyConfigured
                                              ? () => _showAIExplanation(
                                                  context,
                                                  q,
                                                  globalIdx,
                                                )
                                              : () =>
                                                    _showApiKeyDialog(context),
                                          tooltip:
                                              'Refresh AI Explanation (${_maxRegenerationAttempts - (_regenerationAttempts[globalIdx] ?? 0)} attempts left)',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(
                                            Icons.refresh,
                                            color: Colors.grey,
                                            size: 18,
                                          ),
                                          onPressed: null,
                                          tooltip:
                                              'Maximum regeneration attempts reached',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_maxRegenerationAttempts - (_regenerationAttempts[globalIdx] ?? 0)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  (_regenerationAttempts[globalIdx] ??
                                                          0) >=
                                                      _maxRegenerationAttempts
                                                  ? Colors.grey
                                                  : Colors.purple,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_aiExplanations[globalIdx] == null &&
                                (_isLoadingExplanations[globalIdx] != true))
                              Text(
                                'Get an AI-powered explanation of why this answer is correct and why the others are incorrect.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            if (_isLoadingExplanations[globalIdx] == true) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.purple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Generating AI explanation...',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                            if (_aiExplanations[globalIdx] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: _buildMarkdownText(
                                  _aiExplanations[globalIdx]!,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                      showAnswer[globalIdx]
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      showAnswer[globalIdx] ? 'Hide Answer' : 'Show Answer',
                    ),
                    onPressed: () => setState(
                      () => showAnswer[globalIdx] = !showAnswer[globalIdx],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => _editQuestion(globalIdx),
                  tooltip: 'Edit Question',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_rounded,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _deleteQuestion(globalIdx),
                  tooltip: 'Delete Question',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 0
                ? () => setState(() => currentPage--)
                : null,
          ),
          Text('Page ${currentPage + 1} of $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages - 1
                ? () => setState(() => currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  void _showRangeDialog(bool isRandom) {
    final theme = Theme.of(context);
    int minQ = 1;
    int maxQ = widget.questions.length;
    int startQ = minQ;
    int endQ = maxQ;

    // Create text controllers outside StatefulBuilder to avoid recreation
    final startController = TextEditingController(text: startQ.toString());
    final endController = TextEditingController(text: endQ.toString());

    showDialog(
      context: context,
      builder: (context) {
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
                  isRandom ? Icons.play_arrow_rounded : Icons.quiz_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isRandom ? 'Select Question Range' : 'Select Quiz Range',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
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
                            'Select a range of questions ($minQ-$maxQ)',
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
                              'From:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: startController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (v) {
                                int? val = int.tryParse(v);
                                if (val != null && val >= minQ && val <= endQ) {
                                  setState(() => startQ = val);
                                }
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
                              'To:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: endController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (v) {
                                int? val = int.tryParse(v);
                                if (val != null &&
                                    val >= startQ &&
                                    val <= maxQ) {
                                  setState(() => endQ = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (startQ <= endQ && startQ >= minQ && endQ <= maxQ) {
                  Navigator.pop(context, [startQ, endQ]);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(isRandom ? 'Start' : 'Start Quiz'),
            ),
          ],
        );
      },
    ).then((range) {
      if (range is List && range.length == 2) {
        if (isRandom) {
          context.go('/randomquiz/${widget.examId}/${range[0]}/${range[1]}');
        } else {
          context.go('/quiz-range/${widget.examId}/${range[0]}/${range[1]}');
        }
      }
    });
  }
}

// Question Edit Dialog Widget
class _QuestionEditDialog extends StatefulWidget {
  final Map<String, dynamic>? question;
  final Function(Map<String, dynamic>) onSave;

  const _QuestionEditDialog({required this.question, required this.onSave});

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  late TextEditingController questionTextController;
  late TextEditingController optionsController;
  late TextEditingController answersController;
  late TextEditingController questionImagesController;
  late TextEditingController answerImagesController;
  late TextEditingController explanationController;
  String selectedType = 'mcq';

  // Image import functionality
  List<String> questionImages = [];
  List<String> answerImages = [];
  bool isDownloadingQuestionImage = false;
  bool isDownloadingAnswerImage = false;

  @override
  void initState() {
    super.initState();
    final question = widget.question;

    questionTextController = TextEditingController(
      text: question?['text'] ?? '',
    );
    optionsController = TextEditingController(
      text: question?['options'] != null
          ? (question!['options'] as List).join('|')
          : '',
    );
    answersController = TextEditingController(
      text: question?['answers'] != null
          ? (question!['answers'] as List).join('|')
          : '',
    );
    questionImagesController = TextEditingController(
      text: question?['question_images'] != null
          ? (question!['question_images'] as List).join('|')
          : '',
    );
    answerImagesController = TextEditingController(
      text: question?['answer_images'] != null
          ? (question!['answer_images'] as List).join('|')
          : '',
    );
    explanationController = TextEditingController(
      text: question?['explanation'] ?? '',
    );
    selectedType = question?['type'] ?? 'mcq';

    // Initialize image lists
    if (question?['question_images'] != null) {
      questionImages = List<String>.from(question!['question_images']);
    }
    if (question?['answer_images'] != null) {
      answerImages = List<String>.from(question!['answer_images']);
    }
  }

  @override
  void dispose() {
    questionTextController.dispose();
    optionsController.dispose();
    answersController.dispose();
    questionImagesController.dispose();
    answerImagesController.dispose();
    explanationController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage(String imageUrl, bool isQuestionImage) async {
    try {
      setState(() {
        if (isQuestionImage) {
          isDownloadingQuestionImage = true;
        } else {
          isDownloadingAnswerImage = true;
        }
      });

      // Create images directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageUrl)}';
      final filePath = path.join(imagesDir.path, fileName);

      // Download the image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Add to appropriate list
        final relativePath = 'images/$fileName';
        setState(() {
          if (isQuestionImage) {
            questionImages.add(relativePath);
            questionImagesController.text = questionImages.join('|');
          } else {
            answerImages.add(relativePath);
            answerImagesController.text = answerImages.join('|');
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image downloaded successfully: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download image: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        if (isQuestionImage) {
          isDownloadingQuestionImage = false;
        } else {
          isDownloadingAnswerImage = false;
        }
      });
    }
  }

  void _showImageImportDialog(bool isQuestionImage) {
    final urlController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isQuestionImage
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.download_rounded,
                color: isQuestionImage
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Import ${isQuestionImage ? 'Question' : 'Answer'} Image',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ),
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
                      'Enter an image URL to download and add to your question.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
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
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _downloadImage(url, isQuestionImage);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a valid URL'),
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
              backgroundColor: isQuestionImage
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index, bool isQuestionImage) {
    setState(() {
      if (isQuestionImage) {
        questionImages.removeAt(index);
        questionImagesController.text = questionImages.join('|');
      } else {
        answerImages.removeAt(index);
        answerImagesController.text = answerImages.join('|');
      }
    });
  }

  void _save() {
    if (questionTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text is required')),
      );
      return;
    }

    if (optionsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Options are required')));
      return;
    }

    if (answersController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Answers are required')));
      return;
    }

    final questionData = {
      'id': widget.question?['id'] ?? DateTime.now().millisecondsSinceEpoch,
      'type': selectedType,
      'text': questionTextController.text.trim(),
      'options': optionsController.text
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'answers': answersController.text
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'question_images': questionImages,
      'answer_images': answerImages,
      'explanation': explanationController.text.trim().isEmpty
          ? null
          : explanationController.text.trim(),
      'ai_explanation': widget.question?['ai_explanation'],
    };

    widget.onSave(questionData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              widget.question == null ? Icons.add_rounded : Icons.edit_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.question == null ? 'Add Question' : 'Edit Question',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question Type
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: InputDecoration(
                labelText: 'Question Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              items: const [
                DropdownMenuItem(value: 'mcq', child: Text('Multiple Choice')),
                DropdownMenuItem(value: 'hotspot', child: Text('Hotspot')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Question Text
            TextField(
              controller: questionTextController,
              decoration: InputDecoration(
                labelText: 'Question Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Options
            TextField(
              controller: optionsController,
              decoration: InputDecoration(
                labelText: 'Options (separated by |)',
                hintText: 'Option A|Option B|Option C|Option D',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Answers
            TextField(
              controller: answersController,
              decoration: InputDecoration(
                labelText: 'Correct Answers (separated by |)',
                hintText: 'A|B or just A for single answer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Question Images Section
            _buildImageSectionDialog(
              'Question Images',
              Icons.image_rounded,
              theme.colorScheme.primary,
              questionImages,
              isDownloadingQuestionImage,
              () => _showImageImportDialog(true),
              (index) => _removeImage(index, true),
            ),
            const SizedBox(height: 16),

            // Answer Images Section
            _buildImageSectionDialog(
              'Answer Images',
              Icons.image_rounded,
              theme.colorScheme.secondary,
              answerImages,
              isDownloadingAnswerImage,
              () => _showImageImportDialog(false),
              (index) => _removeImage(index, false),
            ),
            const SizedBox(height: 16),

            // Explanation
            TextField(
              controller: explanationController,
              decoration: InputDecoration(
                labelText: 'Explanation (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // AI Explanation Display
            if (widget.question?['ai_explanation'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: theme.colorScheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Explanation:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.question!['ai_explanation'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildImageSectionDialog(
    String title,
    IconData icon,
    Color color,
    List<String> images,
    bool isDownloading,
    VoidCallback onAdd,
    Function(int) onRemove,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isDownloading ? null : onAdd,
                  icon: isDownloading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    isDownloading ? 'Downloading...' : 'Import',
                    style: theme.textTheme.labelSmall,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (images.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.3,
                  ),
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
                    Text(
                      'No images added yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...images.asMap().entries.map((entry) {
                final index = entry.key;
                final imagePath = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image_rounded, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              path.basename(imagePath),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              imagePath,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_rounded,
                          color: theme.colorScheme.error,
                          size: 16,
                        ),
                        onPressed: () => onRemove(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// Full-screen zoomable image viewer
class _FullScreenImageViewer extends StatefulWidget {
  final String imagePath;

  const _FullScreenImageViewer({required this.imagePath});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  double _scale = 1.0;
  double _minScale = 1.0;
  double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    if (_scale == _minScale) {
      // Zoom in to max scale
      final position = _doubleTapDetails!.localPosition;
      final x = -position.dx * (_maxScale - 1);
      final y = -position.dy * (_maxScale - 1);

      final Matrix4 zoomedMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(_maxScale);

      _transformationController.value = zoomedMatrix;
      _scale = _maxScale;
    } else {
      // Reset to original scale
      _transformationController.value = Matrix4.identity();
      _scale = _minScale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Question Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              if (_scale < _maxScale) {
                setState(() {
                  _scale = (_scale + 0.5).clamp(_minScale, _maxScale);
                });
                _transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              }
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              if (_scale > _minScale) {
                setState(() {
                  _scale = (_scale - 0.5).clamp(_minScale, _maxScale);
                });
                _transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              }
            },
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _scale = _minScale;
              });
              _transformationController.value = Matrix4.identity();
            },
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: _minScale,
          maxScale: _maxScale,
          child: Center(
            child:
                widget.imagePath.startsWith('http://') ||
                    widget.imagePath.startsWith('https://')
                ? Image.network(
                    widget.imagePath,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Image not found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : widget.imagePath.startsWith('images/')
                ? FutureBuilder<String?>(
                    future: _getLocalImagePath(widget.imagePath),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.file(
                          File(snapshot.data!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Image not found',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      } else if (snapshot.hasError) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Error loading image',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  )
                : Image.asset(
                    widget.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Image not found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  // Helper method to get the full path for local images (copied from parent)
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
}
