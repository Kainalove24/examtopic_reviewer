import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AIExplanationDialog extends StatefulWidget {
  final String questionText;
  final List<String> options;
  final List<String> correctAnswers;
  final String selectedAnswer;
  final List<String>? questionImages;
  final List<String>? answerImages;
  final String? existingExplanation;

  const AIExplanationDialog({
    super.key,
    required this.questionText,
    required this.options,
    required this.correctAnswers,
    required this.selectedAnswer,
    this.questionImages,
    this.answerImages,
    this.existingExplanation,
  });

  @override
  State<AIExplanationDialog> createState() => _AIExplanationDialogState();
}

class _AIExplanationDialogState extends State<AIExplanationDialog> {
  String? _explanation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getExplanation();
  }

  Future<void> _getExplanation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final explanation = await AIService.getExplanation(
        questionText: widget.questionText,
        options: widget.options,
        correctAnswers: widget.correctAnswers,
        selectedAnswer: widget.selectedAnswer,
        questionImages: widget.questionImages,
        answerImages: widget.answerImages,
        existingExplanation: widget.existingExplanation,
      );

      setState(() {
        _explanation = explanation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Explanation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Powered by OpenAI GPT-4',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _getExplanation,
                    child: const Text('Regenerate'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating AI explanation...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to generate explanation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getExplanation,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_explanation == null) {
      return const Center(child: Text('No explanation available'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question Summary',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.questionText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Your answer: ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            widget.correctAnswers.contains(
                              widget.selectedAnswer,
                            )
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.selectedAnswer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              widget.correctAnswers.contains(
                                widget.selectedAnswer,
                              )
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.correctAnswers.contains(widget.selectedAnswer)
                          ? '✓ Correct'
                          : '✗ Incorrect',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            widget.correctAnswers.contains(
                              widget.selectedAnswer,
                            )
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // AI Explanation
          Text(
            'AI Explanation',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primaryContainer,
                width: 1,
              ),
            ),
            child: Text(
              _explanation!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
