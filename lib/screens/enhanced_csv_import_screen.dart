import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../utils/csv_question_parser.dart';
import '../models/imported_exam.dart';
import '../models/exam_question.dart';
import '../data/imported_exam_storage.dart';
import '../providers/exam_provider.dart';
import '../services/user_exam_service.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

class EnhancedCsvImportScreen extends StatefulWidget {
  const EnhancedCsvImportScreen({super.key});

  @override
  State<EnhancedCsvImportScreen> createState() =>
      _EnhancedCsvImportScreenState();
}

class _EnhancedCsvImportScreenState extends State<EnhancedCsvImportScreen> {
  // Import state
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  // CSV file state
  String? _csvFilePath;
  String? _csvFileName;
  List<Question> _parsedQuestions = [];

  // Image folder state
  String? _imageFolderPath;
  List<String> _availableImages = [];
  List<String> _missingImages = [];
  final List<String> _copiedImages = [];

  // Exam details
  String? _examName;
  String? _examDescription;

  // Import options
  bool _importImages = true;
  bool _overwriteExisting = false;
  bool _validateImages = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV Exam'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme),
            const SizedBox(height: 24),

            // Import Steps
            _buildImportSteps(theme),
            const SizedBox(height: 24),

            // Import Options
            _buildImportOptions(theme),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(theme),
            const SizedBox(height: 24),

            // Status and Results
            if (_error != null) _buildErrorCard(theme),
            if (_successMessage != null) _buildSuccessCard(theme),
            if (_parsedQuestions.isNotEmpty) _buildResultsCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.file_upload,
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
                        'Import CSV Exam',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Import exam questions from CSV file with optional image support',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSteps(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Steps',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Step 1: Select CSV
            _buildStepItem(
              theme,
              step: 1,
              title: 'Select CSV File',
              subtitle: _csvFileName ?? 'No file selected',
              icon: Icons.description,
              isCompleted: _csvFilePath != null,
              onTap: _selectCsvFile,
            ),

            // Step 2: Select Images (optional)
            _buildStepItem(
              theme,
              step: 2,
              title: 'Select Image Folder (Optional)',
              subtitle: _imageFolderPath ?? 'No folder selected',
              icon: Icons.folder,
              isCompleted: _imageFolderPath != null || !_importImages,
              onTap: _importImages ? _selectImageFolder : null,
              isOptional: true,
            ),

            // Step 3: Configure Exam
            _buildStepItem(
              theme,
              step: 3,
              title: 'Configure Exam Details',
              subtitle: _examName ?? 'Not configured',
              icon: Icons.settings,
              isCompleted: _examName != null,
              onTap: _configureExamDetails,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(
    ThemeData theme, {
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    VoidCallback? onTap,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          color: theme.colorScheme.onPrimary,
                          size: 18,
                        )
                      : Text(
                          '$step',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isOptional) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Optional',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportOptions(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Options',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Import Images'),
              subtitle: const Text('Include images referenced in the CSV'),
              value: _importImages,
              onChanged: (value) => setState(() => _importImages = value),
              activeColor: theme.colorScheme.primary,
            ),

            SwitchListTile(
              title: const Text('Validate Images'),
              subtitle: const Text('Check if all referenced images exist'),
              value: _validateImages,
              onChanged: (value) => setState(() => _validateImages = value),
              activeColor: theme.colorScheme.primary,
            ),

            SwitchListTile(
              title: const Text('Overwrite Existing'),
              subtitle: const Text('Replace existing exam with same name'),
              value: _overwriteExisting,
              onChanged: (value) => setState(() => _overwriteExisting = value),
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final canImport = _csvFilePath != null && _examName != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetImport,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: canImport && !_isLoading ? _performImport : null,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.file_download),
            label: Text(_isLoading ? 'Importing...' : 'Import Exam'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _successMessage!,
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Summary',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            _buildSummaryItem(
              theme,
              icon: Icons.quiz,
              label: 'Questions',
              value: '${_parsedQuestions.length}',
            ),

            if (_importImages && _availableImages.isNotEmpty)
              _buildSummaryItem(
                theme,
                icon: Icons.image,
                label: 'Images Found',
                value: '${_availableImages.length}',
                color: Colors.green,
              ),

            if (_importImages && _missingImages.isNotEmpty)
              _buildSummaryItem(
                theme,
                icon: Icons.image_not_supported,
                label: 'Images Missing',
                value: '${_missingImages.length}',
                color: Colors.orange,
              ),

            if (_copiedImages.isNotEmpty)
              _buildSummaryItem(
                theme,
                icon: Icons.copy,
                label: 'Images Copied',
                value: '${_copiedImages.length}',
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Import Methods
  Future<void> _selectCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Select CSV File',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final csvString = utf8.decode(file.bytes!);

        if (csvString.trim().isEmpty) {
          _showError('CSV file is empty');
          return;
        }

        final questions = parseQuestionsFromCsv(csvString);
        if (questions.isEmpty) {
          _showError('No questions found in CSV file');
          return;
        }

        setState(() {
          _csvFilePath = file.path;
          _csvFileName = file.name;
          _parsedQuestions = questions;
          _error = null;
        });
      }
    } catch (e) {
      _showError('Failed to read CSV file: $e');
    }
  }

  Future<void> _selectImageFolder() async {
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Image Folder',
      );

      if (folderPath != null) {
        await _processImageFolder(folderPath);
      }
    } catch (e) {
      _showError('Failed to select image folder: $e');
    }
  }

  Future<void> _processImageFolder(String folderPath) async {
    setState(() {
      _imageFolderPath = folderPath;
      _availableImages.clear();
      _missingImages.clear();
    });

    // Collect all image references from questions
    final Set<String> allImagePaths = {};
    for (final question in _parsedQuestions) {
      allImagePaths.addAll(question.questionImages);
      allImagePaths.addAll(question.answerImages);
    }

    if (allImagePaths.isEmpty) {
      setState(() {
        _availableImages = [];
        _missingImages = [];
      });
      return;
    }

    // Check which images exist in the folder
    final folder = Directory(folderPath);
    final existingFiles = await folder.list().toList();
    final existingFileNames = existingFiles
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .toSet();

    for (final imagePath in allImagePaths) {
      final fileName = p.basename(imagePath);
      if (existingFileNames.contains(fileName)) {
        _availableImages.add(imagePath);
      } else {
        _missingImages.add(imagePath);
      }
    }
  }

  Future<void> _configureExamDetails() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ExamDetailsDialog(
        initialName: _examName,
        initialDescription: _examDescription,
        questionCount: _parsedQuestions.length,
        imageCount: _availableImages.length,
        missingImageCount: _missingImages.length,
      ),
    );

    if (result != null) {
      setState(() {
        _examName = result['name'];
        _examDescription = result['description'];
      });
    }
  }

  Future<void> _performImport() async {
    if (_csvFilePath == null || _examName == null) {
      _showError('Please complete all required steps');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // Check for existing exam
      final existingExams = await ImportedExamStorage.loadAll();
      final existingExam = existingExams.firstWhere(
        (exam) => exam.title.toLowerCase() == _examName!.toLowerCase(),
        orElse: () => throw Exception('Exam not found'),
      );

      if (!_overwriteExisting) {
        _showError(
          'An exam with this name already exists. Enable "Overwrite Existing" to replace it.',
        );
        return;
      }

      // Copy images if needed
      if (_importImages && _imageFolderPath != null) {
        await _copyImagesToAppDirectory();
      }

      // Create exam object
      final exam = ImportedExam(
        id: existingExam.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _examName!,
        filename: _csvFileName!,
        importedAt: DateTime.now(),
      );

      // Save exam to admin storage
      if (_overwriteExisting) {
        await ImportedExamStorage.removeExam(existingExam.id);
        await ImportedExamStorage.addExam(exam);
      } else {
        await ImportedExamStorage.addExam(exam);
      }

      // Also save to user exam service for user access
      // Convert Question objects to ExamQuestion objects
      final examQuestions = _parsedQuestions.map((q) => ExamQuestion(
        id: q.id,
        type: q.type,
        text: q.text,
        questionImages: q.questionImages,
        answerImages: q.answerImages,
        options: q.choices.map((c) => c.text).toList(),
        answers: q.correctIndices.map((i) => q.choices[i].text).toList(),
        explanation: null,
      )).toList();

      final examData = {
        'id': exam.id,
        'title': _examName!,
        'questions': examQuestions.map((q) => q.toMap()!).toList(),
        'questionCount': _parsedQuestions.length,
        'category': 'User Import',
        'importDate': DateTime.now().toIso8601String(),
      };

      await UserExamService.addUserImportedExam(examData);

      // Update ExamProvider
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      await examProvider.loadAllExams();

      setState(() {
        _successMessage = 'Exam imported successfully!';
        _isLoading = false;
      });

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/library');
        }
      });
    } catch (e) {
      _showError('Import failed: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyImagesToAppDirectory() async {
    if (_imageFolderPath == null || _availableImages.isEmpty) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      _copiedImages.clear();
      for (final imagePath in _availableImages) {
        final fileName = p.basename(imagePath);
        final sourceFile = File('$_imageFolderPath/$fileName');
        final destFile = File('${imagesDir.path}/$fileName');

        await sourceFile.copy(destFile.path);
        _copiedImages.add(fileName);
      }
    } catch (e) {
      _showError('Failed to copy images: $e');
    }
  }

  void _resetImport() {
    setState(() {
      _csvFilePath = null;
      _csvFileName = null;
      _parsedQuestions.clear();
      _imageFolderPath = null;
      _availableImages.clear();
      _missingImages.clear();
      _copiedImages.clear();
      _examName = null;
      _examDescription = null;
      _error = null;
      _successMessage = null;
    });
  }

  void _showError(String message) {
    setState(() {
      _error = message;
    });
  }
}

class _ExamDetailsDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final int questionCount;
  final int imageCount;
  final int missingImageCount;

  const _ExamDetailsDialog({
    this.initialName,
    this.initialDescription,
    required this.questionCount,
    required this.imageCount,
    required this.missingImageCount,
  });

  @override
  State<_ExamDetailsDialog> createState() => _ExamDetailsDialogState();
}

class _ExamDetailsDialogState extends State<_ExamDetailsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Exam Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Exam Name',
              hintText: 'Enter exam name',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter exam description',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Questions', '${widget.questionCount}'),
                if (widget.imageCount > 0)
                  _buildSummaryRow('Images Found', '${widget.imageCount}'),
                if (widget.missingImageCount > 0)
                  _buildSummaryRow(
                    'Images Missing',
                    '${widget.missingImageCount}',
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
          onPressed: _nameController.text.trim().isNotEmpty
              ? () => Navigator.pop(context, {
                  'name': _nameController.text.trim(),
                  'description': _descriptionController.text.trim(),
                })
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
