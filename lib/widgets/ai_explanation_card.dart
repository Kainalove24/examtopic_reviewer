import 'package:flutter/material.dart';

class AIExplanationCard extends StatelessWidget {
  final String? explanation;
  final bool isLoading;
  final int regenerationAttempts;
  final int maxRegenerationAttempts;
  final VoidCallback? onGetExplanation;
  final VoidCallback? onRegenerate;
  final bool isApiKeyConfigured;
  final VoidCallback? onShowApiKeyDialog;

  const AIExplanationCard({
    super.key,
    this.explanation,
    required this.isLoading,
    required this.regenerationAttempts,
    required this.maxRegenerationAttempts,
    this.onGetExplanation,
    this.onRegenerate,
    required this.isApiKeyConfigured,
    this.onShowApiKeyDialog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExplanation = explanation != null && explanation!.isNotEmpty;

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
          // Header
          Row(
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
                'AI Explanation',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              _buildControls(theme),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (isLoading) ...[
            _buildLoadingState(theme),
          ] else if (hasExplanation) ...[
            _buildExplanationContent(theme),
          ] else ...[
            _buildEmptyState(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    if (explanation == null && !isLoading) {
      return IconButton(
        icon: Icon(
          Icons.help_outline_rounded,
          color: theme.colorScheme.secondary,
          size: 20,
        ),
        onPressed: isApiKeyConfigured ? onGetExplanation : onShowApiKeyDialog,
        tooltip: 'Get AI Explanation',
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.secondaryContainer.withValues(
            alpha: 0.3,
          ),
          padding: const EdgeInsets.all(8),
        ),
      );
    }

    if (explanation != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (regenerationAttempts < maxRegenerationAttempts)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              onPressed: isApiKeyConfigured ? onRegenerate : onShowApiKeyDialog,
              tooltip: 'Refresh AI Explanation',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.3),
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
                    .withValues(alpha: 0.3),
                padding: const EdgeInsets.all(8),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: regenerationAttempts >= maxRegenerationAttempts
                  ? theme.colorScheme.outline.withValues(alpha: 0.2)
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${maxRegenerationAttempts - regenerationAttempts}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: regenerationAttempts >= maxRegenerationAttempts
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

  Widget _buildLoadingState(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Generating AI explanation...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationContent(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: _buildMarkdownText(explanation!, theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
              'Get an AI-powered explanation of why this answer is correct.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownText(String text, ThemeData theme) {
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
}
