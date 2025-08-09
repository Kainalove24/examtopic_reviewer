import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/optimized_image_service.dart';
import 'enhanced_image_viewer.dart';

class OptimizedQuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final int globalIndex;
  final bool showAnswer;
  final String? searchQuery;
  final Function(String)? onOptionSelected;
  final bool isSelected;
  final bool isCorrect;
  final VoidCallback? onToggleAnswer; // NEW: Add toggle callback
  final VoidCallback? onEdit; // NEW: Add edit callback
  final VoidCallback? onDelete; // NEW: Add delete callback

  const OptimizedQuestionCard({
    super.key,
    required this.question,
    required this.globalIndex,
    required this.showAnswer,
    this.searchQuery,
    this.onOptionSelected,
    this.isSelected = false,
    this.isCorrect = false,
    this.onToggleAnswer, // NEW: Add toggle callback
    this.onEdit, // NEW: Add edit callback
    this.onDelete, // NEW: Add delete callback
  });

  @override
  State<OptimizedQuestionCard> createState() => _OptimizedQuestionCardState();
}

class _OptimizedQuestionCardState extends State<OptimizedQuestionCard> {
  final Map<String, String?> _loadedImages = {};
  final Map<String, bool> _loadingImages = {};

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  void _preloadImages() {
    final questionImages = widget.question['question_images'] as List? ?? [];
    final answerImages = widget.question['answer_images'] as List? ?? [];

    for (final image in questionImages) {
      if (image is String && image.isNotEmpty) {
        _loadImageAsync(image);
      }
    }

    for (final image in answerImages) {
      if (image is String && image.isNotEmpty) {
        _loadImageAsync(image);
      }
    }
  }

  // Debug method to check image status
  void _debugImageStatus(String imagePath) {
    print('🔍 Debug Image Status:');
    print('  Path: $imagePath');
    print('  Is Network: ${imagePath.startsWith('http')}');
    print('  Is Local: ${imagePath.startsWith('images/')}');
    print(
      '  Is Asset: ${!imagePath.startsWith('http') && !imagePath.startsWith('images/')}',
    );
    print('  In Memory Cache: ${_loadedImages.containsKey(imagePath)}');
    print('  Is Loading: ${_loadingImages[imagePath] == true}');
    if (_loadedImages.containsKey(imagePath)) {
      print('  Cached Path: ${_loadedImages[imagePath]}');
    }
  }

  // Enhanced image loading with better error handling
  Future<void> _loadImageAsync(String imagePath) async {
    if (_loadedImages.containsKey(imagePath) ||
        _loadingImages[imagePath] == true) {
      return;
    }

    setState(() {
      _loadingImages[imagePath] = true;
    });

    try {
      print('🖼️ Loading image: $imagePath');
      _debugImageStatus(imagePath);

      final processedUrl = await OptimizedImageService.loadImage(imagePath);

      if (mounted) {
        setState(() {
          if (processedUrl != null) {
            _loadedImages[imagePath] = processedUrl;
            print('✅ Image loaded successfully: ${path.basename(imagePath)}');
          } else {
            _loadedImages[imagePath] = null; // Mark as failed
            print('❌ Image loading failed: ${path.basename(imagePath)}');
          }
          _loadingImages[imagePath] = false;
        });
      }
    } catch (e) {
      print('❌ Error loading image $imagePath: $e');
      if (mounted) {
        setState(() {
          _loadedImages[imagePath] = null; // Mark as failed
          _loadingImages[imagePath] = false;
        });
      }
    }
  }

  // Build optimized image widget with retry functionality
  Widget _buildOptimizedImageWidget(String imagePath) {
    if (_loadedImages.containsKey(imagePath)) {
      final loadedPath = _loadedImages[imagePath];
      if (loadedPath != null) {
        return _buildImageWidget(loadedPath);
      } else {
        // Image failed to load, show error state
        return _buildErrorWidget(imagePath);
      }
    }

    if (_loadingImages[imagePath] == true) {
      return Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // If image failed to load, show retry option
    return _buildErrorWidget(imagePath);
  }

  // Build error widget for failed images
  Widget _buildErrorWidget(String imagePath) {
    return GestureDetector(
      onTap: () {
        print('🔄 Retrying image load: $imagePath');
        _loadImageAsync(imagePath);
      },
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.red.shade400, size: 24),
              const SizedBox(height: 4),
              Text(
                'Image Unavailable',
                style: TextStyle(fontSize: 8, color: Colors.red.shade600),
              ),
              Text(
                'Tap to retry',
                style: TextStyle(fontSize: 6, color: Colors.red.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build image widget with enhanced error handling
  Widget _buildImageWidget(String imagePath) {
    return GestureDetector(
      onTap: () => _showImageDialog(context, imagePath),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              imagePath.startsWith('http://') ||
                  imagePath.startsWith('https://')
              ? Image.network(
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Network image error for $imagePath: $error');
                    return Container(
                      color: Colors.red.shade100,
                      height: 120,
                      width: 120,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Network Error',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              'Tap to retry',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Image.file(
                  File(imagePath),
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Local image error for $imagePath: $error');
                    return Container(
                      color: Colors.red.shade100,
                      height: 120,
                      width: 120,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'File Not Found',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              'Path: ${imagePath.length > 20 ? '...${imagePath.substring(imagePath.length - 20)}' : imagePath}',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.red.shade600,
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
    );
  }

  // Show image dialog
  void _showImageDialog(BuildContext context, String imagePath) {
    showEnhancedImageViewer(context, imagePath, title: 'Question Image');
  }

  // Highlight search terms in text
  Widget _buildHighlightedText(
    String text,
    String searchQuery, {
    bool isCorrectAnswer = false,
  }) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: widget.showAnswer && isCorrectAnswer
              ? Colors.green.shade700
              : null,
          fontWeight: widget.showAnswer && isCorrectAnswer
              ? FontWeight.bold
              : null,
        ),
      );
    }

    final queryLower = searchQuery.toLowerCase();
    final textLower = text.toLowerCase();
    final matches = <MapEntry<int, int>>[];

    int start = 0;
    while (true) {
      final index = textLower.indexOf(queryLower, start);
      if (index == -1) break;
      matches.add(MapEntry(index, index + queryLower.length));
      start = index + 1;
    }

    if (matches.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.key > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.key),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: widget.showAnswer && isCorrectAnswer
                  ? Colors.green.shade700
                  : null,
              fontWeight: widget.showAnswer && isCorrectAnswer
                  ? FontWeight.bold
                  : null,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.key, match.value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            backgroundColor: Colors.yellow.withOpacity(0.3),
            fontWeight: FontWeight.bold,
            color: widget.showAnswer && isCorrectAnswer
                ? Colors.green.shade700
                : null,
          ),
        ),
      );
      currentIndex = match.value;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: widget.showAnswer && isCorrectAnswer
                ? Colors.green.shade700
                : null,
            fontWeight: widget.showAnswer && isCorrectAnswer
                ? FontWeight.bold
                : null,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text with search highlighting
            _buildHighlightedText(
              'Q${widget.globalIndex + 1}. ${q['text']}',
              widget.searchQuery ?? '',
              isCorrectAnswer: false,
            ),

            // Question images
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
                        .map((img) => _buildOptimizedImageWidget(img)),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // Options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(q['options'].length, (idx) {
                  final optionText = q['options'][idx];

                  // Debug option text format
                  if (widget.showAnswer) {
                    print('🔍 Option Debug - Index $idx:');
                    print('  Raw Option Text: "$optionText"');
                    print('  Trimmed: "${optionText.trim()}"');
                  }

                  // Always use index-based letters (A, B, C, D, E, etc.)
                  String optionLetter = String.fromCharCode(
                    65 + idx,
                  ); // A=0, B=1, C=2, D=3, etc.

                  if (widget.showAnswer) {
                    print(
                      '  Index-based Letter: $optionLetter (from index $idx)',
                    );
                  }

                  final answersRaw = q['answers'] ?? q['answer'];
                  List<String> correctLetters = [];

                  if (widget.showAnswer) {
                    print('🔍 Answers Debug:');
                    print('  Answers Raw: $answersRaw');
                    print('  Type: ${answersRaw.runtimeType}');
                    if (answersRaw is List) {
                      print('  Is List: true, Length: ${answersRaw.length}');
                      for (int i = 0; i < answersRaw.length; i++) {
                        print(
                          '    [$i]: ${answersRaw[i]} (${answersRaw[i].runtimeType})',
                        );
                        // Test if it can be parsed as integer
                        final parsed = int.tryParse(answersRaw[i].toString());
                        print('    [$i] parsed as int: $parsed');
                        if (parsed != null) {
                          final letter = String.fromCharCode(65 + parsed);
                          print('    [$i] -> letter: $letter');
                        }
                      }
                    } else if (answersRaw is String) {
                      print('  Is String: true, Length: ${answersRaw.length}');
                      final parsed = int.tryParse(answersRaw);
                      print('  String parsed as int: $parsed');
                      if (parsed != null) {
                        final letter = String.fromCharCode(65 + parsed);
                        print('  String -> letter: $letter');
                      }
                    }
                  }

                  if (answersRaw is List && answersRaw.isNotEmpty) {
                    if (int.tryParse(answersRaw[0].toString()) != null) {
                      correctLetters = answersRaw
                          .map(
                            (a) => String.fromCharCode(
                              65 + int.tryParse(a.toString())!,
                            ),
                          )
                          .toList();
                      if (widget.showAnswer) {
                        print(
                          '  Processing as indices -> letters: $correctLetters',
                        );
                      }
                    } else {
                      // Extract just the letter from answer text (e.g., "C.Use the SageMaker..." -> "C")
                      correctLetters = answersRaw.map((a) {
                        final answerText = a.toString().trim();
                        // Try to extract letter from beginning of answer text
                        final letterMatch = RegExp(
                          r'^([A-Za-z])[\.|\s]',
                        ).firstMatch(answerText);
                        if (letterMatch != null) {
                          return letterMatch.group(1)!.toUpperCase();
                        }
                        // Fallback: just take the first character if it's a letter
                        if (answerText.isNotEmpty &&
                            RegExp(r'^[A-Za-z]').hasMatch(answerText[0])) {
                          return answerText[0].toUpperCase();
                        }
                        return answerText.toUpperCase();
                      }).toList();
                      if (widget.showAnswer) {
                        print(
                          '  Processing as direct letters (extracted): $correctLetters',
                        );
                      }
                    }
                  } else if (answersRaw is String && answersRaw.isNotEmpty) {
                    if (int.tryParse(answersRaw) != null) {
                      correctLetters = [
                        String.fromCharCode(65 + int.tryParse(answersRaw)!),
                      ];
                      if (widget.showAnswer) {
                        print(
                          '  Processing as single index -> letter: $correctLetters',
                        );
                      }
                    } else {
                      // Extract just the letter from answer text
                      final answerText = answersRaw.trim();
                      final letterMatch = RegExp(
                        r'^([A-Za-z])[\.|\s]',
                      ).firstMatch(answerText);
                      String extractedLetter;
                      if (letterMatch != null) {
                        extractedLetter = letterMatch.group(1)!.toUpperCase();
                      } else if (answerText.isNotEmpty &&
                          RegExp(r'^[A-Za-z]').hasMatch(answerText[0])) {
                        extractedLetter = answerText[0].toUpperCase();
                      } else {
                        extractedLetter = answerText.toUpperCase();
                      }
                      correctLetters = [extractedLetter];
                      if (widget.showAnswer) {
                        print(
                          '  Processing as single letter (extracted): $correctLetters',
                        );
                      }
                    }
                  }

                  bool isCorrect = correctLetters.contains(optionLetter);

                  // Debug output for answer highlighting
                  if (widget.showAnswer) {
                    print(
                      '🔍 Answer Debug - Question ${widget.globalIndex + 1}, Option $optionLetter:',
                    );
                    print('  Option Text: $optionText');
                    print('  Extracted Letter: $optionLetter');
                    print('  Answers Raw: $answersRaw');
                    print('  Correct Letters: $correctLetters');
                    print('  Is Correct: $isCorrect');
                    print(
                      '  Contains check: ${correctLetters.contains(optionLetter)}',
                    );
                    print(
                      '  Correct letters type: ${correctLetters.runtimeType}',
                    );
                    print('  Option letter type: ${optionLetter.runtimeType}');

                    // Force highlight for debugging - uncomment to test
                    // if (optionLetter == 'A') {
                    //   print('  FORCING HIGHLIGHT FOR OPTION A');
                    //   isCorrect = true;
                    // }
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showAnswer && isCorrect)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                      SizedBox(
                        width: 30, // Fixed width for letter column
                        child: Text(
                          '$optionLetter. ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.showAnswer && isCorrect
                                ? Colors.green.shade700
                                : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildHighlightedText(
                          // Remove any letter prefix (A., B., C., etc.) from the beginning of the text
                          optionText.replaceFirst(
                            RegExp(r'^[A-Za-z][\.|\)]\s*'),
                            '',
                          ),
                          widget.searchQuery ?? '',
                          isCorrectAnswer: isCorrect,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            // Answer images (only when showing answer)
            if (widget.showAnswer &&
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
                        .map((img) => _buildOptimizedImageWidget(img)),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                      widget.showAnswer
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      widget.showAnswer ? 'Hide Answer' : 'Show Answer',
                    ),
                    onPressed: () {
                      widget.onToggleAnswer?.call();
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    widget.onEdit?.call();
                  },
                  tooltip: 'Edit Question',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_rounded,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () {
                    widget.onDelete?.call();
                  },
                  tooltip: 'Delete Question',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
