import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../services/csv_import_service.dart';
import '../models/exam_question.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/data_management_service.dart';
import '../services/user_exam_service.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

class ComprehensiveImportScreen extends StatefulWidget {
  const ComprehensiveImportScreen({super.key});

  @override
  State<ComprehensiveImportScreen> createState() =>
      _ComprehensiveImportScreenState();
}

class _ComprehensiveImportScreenState extends State<ComprehensiveImportScreen> {
  // Import state
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  // Import type selection
  ImportType _selectedImportType = ImportType.csv;

  // CSV import state
  String? _csvFilePath;
  String? _csvFileName;
  List<ExamQuestion> _parsedQuestions = [];

  // Image import state
  String? _imageFolderPath;
  List<String> _availableImages = [];
  final List<String> _missingImages = [];
  List<String> _copiedImages = [];

  // Data import state
  String? _dataFilePath;
  String? _dataFileName;

  // Exam details
  String? _examName;
  String? _examDescription;

  // Import options
  bool _importImages = true;
  bool _overwriteExisting = false;
  bool _validateImages = true;
  bool _backupBeforeImport = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Content'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/library'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme),
            const SizedBox(height: 24),

            // Import Type Selection
            _buildImportTypeSelection(theme),
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
            if (_parsedQuestions.isNotEmpty || _availableImages.isNotEmpty)
              _buildResultsCard(theme),
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
                        'Import Content',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Import exams, images, or data from various sources',
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

  Widget _buildImportTypeSelection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Type',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            _buildImportTypeOption(
              theme,
              type: ImportType.csv,
              icon: Icons.description,
              title: 'CSV Exam',
              subtitle: 'Import exam questions from CSV file',
              description:
                  'Import structured exam data with questions, answers, and image references',
            ),

            _buildImportTypeOption(
              theme,
              type: ImportType.images,
              icon: Icons.folder,
              title: kIsWeb ? 'Image Files' : 'Image Folder',
              subtitle: kIsWeb
                  ? 'Import individual image files for exams'
                  : 'Import folders of images for exams',
              description: kIsWeb
                  ? 'Import individual image files that can be referenced in your exams'
                  : 'Import image collections that can be referenced in your exams',
            ),

            _buildImportTypeOption(
              theme,
              type: ImportType.data,
              icon: Icons.backup,
              title: 'Data Backup',
              subtitle: 'Import data from backup file',
              description:
                  'Restore your progress, settings, and imported exams from backup',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportTypeOption(
    ThemeData theme, {
    required ImportType type,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    final isSelected = _selectedImportType == type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedImportType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
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

            // Step 1: Select File/Folder
            _buildStepItem(
              theme,
              step: 1,
              title: _getStep1Title(),
              subtitle: _getStep1Subtitle(),
              icon: _getStep1Icon(),
              isCompleted: _isStep1Completed(),
              onTap: _handleStep1,
            ),

            // Step 2: Configure (if needed)
            if (_selectedImportType == ImportType.csv)
              _buildStepItem(
                theme,
                step: 2,
                title: 'Configure Exam Details',
                subtitle: _examName ?? 'Not configured',
                icon: Icons.settings,
                isCompleted: _examName != null,
                onTap: _configureExamDetails,
              ),

            // Step 3: Import
            _buildStepItem(
              theme,
              step: _selectedImportType == ImportType.csv ? 3 : 2,
              title: 'Import Content',
              subtitle: 'Ready to import',
              icon: Icons.file_download,
              isCompleted: false,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  String _getStep1Title() {
    switch (_selectedImportType) {
      case ImportType.csv:
        return 'Select CSV File';
      case ImportType.images:
        return kIsWeb ? 'Select Images' : 'Select Image Folder';
      case ImportType.data:
        return 'Select Backup File';
    }
  }

  String _getStep1Subtitle() {
    switch (_selectedImportType) {
      case ImportType.csv:
        return _csvFileName ?? 'No file selected';
      case ImportType.images:
        if (kIsWeb) {
          return _availableImages.isNotEmpty
              ? '${_availableImages.length} images selected'
              : 'No images selected';
        }
        return _imageFolderPath ?? 'No folder selected';
      case ImportType.data:
        return _dataFileName ?? 'No file selected';
    }
  }

  IconData _getStep1Icon() {
    switch (_selectedImportType) {
      case ImportType.csv:
        return Icons.description;
      case ImportType.images:
        return Icons.folder;
      case ImportType.data:
        return Icons.backup;
    }
  }

  bool _isStep1Completed() {
    switch (_selectedImportType) {
      case ImportType.csv:
        return _csvFilePath != null;
      case ImportType.images:
        return _imageFolderPath != null;
      case ImportType.data:
        return _dataFilePath != null;
    }
  }

  Widget _buildStepItem(
    ThemeData theme, {
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    VoidCallback? onTap,
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

            if (_selectedImportType == ImportType.csv) ...[
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
            ],

            SwitchListTile(
              title: const Text('Overwrite Existing'),
              subtitle: const Text('Replace existing content with same name'),
              value: _overwriteExisting,
              onChanged: (value) => setState(() => _overwriteExisting = value),
              activeColor: theme.colorScheme.primary,
            ),

            SwitchListTile(
              title: const Text('Backup Before Import'),
              subtitle: Text(
                kIsWeb
                    ? 'Backup not available on web platform'
                    : 'Create backup before importing',
              ),
              value: _backupBeforeImport,
              onChanged: kIsWeb
                  ? null
                  : (value) => setState(() => _backupBeforeImport = value),
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final canImport =
        _isStep1Completed() &&
        (_selectedImportType != ImportType.csv || _examName != null);

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
            label: Text(_isLoading ? 'Importing...' : 'Import'),
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

            if (_parsedQuestions.isNotEmpty)
              _buildSummaryItem(
                theme,
                icon: Icons.quiz,
                label: 'Questions',
                value: '${_parsedQuestions.length}',
              ),

            if (_availableImages.isNotEmpty)
              _buildSummaryItem(
                theme,
                icon: Icons.image,
                label: 'Images Found',
                value: '${_availableImages.length}',
                color: Colors.green,
              ),

            if (_missingImages.isNotEmpty)
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
  Future<void> _handleStep1() async {
    switch (_selectedImportType) {
      case ImportType.csv:
        await _selectCsvFile();
        break;
      case ImportType.images:
        await _selectImageFolder();
        break;
      case ImportType.data:
        await _selectDataFile();
        break;
    }
  }

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

        // Use the new CsvImportService to parse the CSV
        final parseResult = await CsvImportService.parseCsvContent(csvString);

        if (parseResult['questions'].isEmpty) {
          _showError('No questions found in CSV file');
          return;
        }

        setState(() {
          _csvFilePath = file.path;
          _csvFileName = file.name;
          _parsedQuestions = parseResult['questions'].cast<ExamQuestion>();
          _error = null;
        });
      }
    } catch (e) {
      _showError('Failed to read CSV file: $e');
    }
  }

  Future<void> _selectImageFolder() async {
    // On web platform, use file picker to select multiple images instead
    if (kIsWeb) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          dialogTitle: 'Select Images',
        );

        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _imageFolderPath = 'web_selected_images';
            _availableImages = result.files.map((file) => file.name).toList();
            _missingImages.clear();
            _error = null;
          });
        }
      } catch (e) {
        _showError('Failed to select images: $e');
      }
      return;
    }

    // On mobile/desktop platforms, use directory picker
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

  Future<void> _selectDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _dataFilePath = file.path;
          _dataFileName = file.name;
          _error = null;
        });
      }
    } catch (e) {
      _showError('Failed to select backup file: $e');
    }
  }

  Future<void> _processImageFolder(String folderPath) async {
    setState(() {
      _imageFolderPath = folderPath;
      _availableImages.clear();
      _missingImages.clear();
    });

    try {
      final folder = Directory(folderPath);
      final files = await folder.list().toList();
      final imageFiles = files
          .where((file) => file is File && _isImageFile(file.path))
          .map((file) => p.basename(file.path))
          .toList();

      setState(() {
        _availableImages = imageFiles;
      });
    } catch (e) {
      _showError('Failed to process image folder: $e');
    }
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
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
    if (!_isStep1Completed()) {
      _showError('Please complete all required steps');
      return;
    }

    if (_selectedImportType == ImportType.csv && _examName == null) {
      _showError('Please configure exam details');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // Get providers
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(
        context,
        listen: false,
      );
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final dataService = DataManagementService();

      // Create backup if requested (skip on web platform)
      if (_backupBeforeImport && !kIsWeb) {
        try {
          await dataService.backupData(
            examProvider: examProvider,
            progressProvider: progressProvider,
            settingsProvider: settingsProvider,
          );
        } catch (e) {
          // Log backup failure but continue with import
          print('Backup failed: $e');
        }
      }

      switch (_selectedImportType) {
        case ImportType.csv:
          await _performCsvImport();
          break;
        case ImportType.images:
          await _performImageImport();
          break;
        case ImportType.data:
          await _performDataImport();
          break;
      }

      setState(() {
        _successMessage = 'Import completed successfully!';
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

  Future<void> _performCsvImport() async {
    // Check for existing exam in user imports
    final allUserExams = await UserExamService.getUserExams();
    final existingExam = allUserExams
        .where(
          (exam) =>
              exam['type'] == 'user_imported' &&
              exam['title'].toString().toLowerCase() ==
                  _examName!.toLowerCase(),
        )
        .firstOrNull;

    if (existingExam != null && !_overwriteExisting) {
      throw Exception(
        'An exam with this name already exists. Enable "Overwrite Existing" to replace it.',
      );
    }

    // Copy images if needed
    if (_importImages && _imageFolderPath != null) {
      await _copyImagesToAppDirectory();
    }

    // Convert ExamQuestion objects to ExamEntry format
    final examQuestions = _parsedQuestions.cast<ExamQuestion>();

    // Create exam data for user import
    final examData = {
      'id':
          existingExam?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _examName!,
      'questions': examQuestions.map((q) => q.toMap()).toList(),
      'questionCount': _parsedQuestions.length,
      'category': 'User Import',
      'importDate': DateTime.now().toIso8601String(),
    };

    // Save to UserExamService (user imported exams are always unlocked)
    if (_overwriteExisting && existingExam != null) {
      await UserExamService.removeUserImportedExam(existingExam['id']);
    }

    await UserExamService.addUserImportedExam(examData);

    // Create ExamEntry and add to ExamProvider
    final examEntry = ExamEntry(
      id: examData['id'],
      title: examData['title'],
      questions: examQuestions,
    );

    // Add to ExamProvider
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    examProvider.addExam(examEntry);

    // Save to persistent storage
    await examProvider.saveAllExams();
  }

  Future<void> _performImageImport() async {
    if (_imageFolderPath == null) return;

    // Skip image import on web platform
    if (kIsWeb) {
      setState(() {
        _copiedImages = _availableImages;
      });
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      _copiedImages.clear();
      for (final imageName in _availableImages) {
        final sourceFile = File('$_imageFolderPath/$imageName');
        final destFile = File('${imagesDir.path}/$imageName');

        await sourceFile.copy(destFile.path);
        _copiedImages.add(imageName);
      }
    } catch (e) {
      throw Exception('Failed to copy images: $e');
    }
  }

  Future<void> _performDataImport() async {
    if (_dataFilePath == null) return;

    try {
      final file = File(_dataFilePath!);
      final jsonString = await file.readAsString();

      // Get providers
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(
        context,
        listen: false,
      );
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final dataService = DataManagementService();

      await dataService.importData(
        jsonData: jsonString,
        examProvider: examProvider,
        progressProvider: progressProvider,
        settingsProvider: settingsProvider,
        overwriteExisting: _overwriteExisting,
      );

      // Reload providers
      await examProvider.loadAllExams();
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  Future<void> _copyImagesToAppDirectory() async {
    if (_imageFolderPath == null || _availableImages.isEmpty) return;

    // Skip image copying on web platform
    if (kIsWeb) {
      setState(() {
        _copiedImages = _availableImages;
      });
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      _copiedImages.clear();
      for (final imageName in _availableImages) {
        final sourceFile = File('$_imageFolderPath/$imageName');
        final destFile = File('${imagesDir.path}/$imageName');

        await sourceFile.copy(destFile.path);
        _copiedImages.add(imageName);
      }
    } catch (e) {
      throw Exception('Failed to copy images: $e');
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
      _dataFilePath = null;
      _dataFileName = null;
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

enum ImportType { csv, images, data }

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
    final isNameValid = _nameController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Exam Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Exam Name *',
              hintText: 'Enter exam name',
              errorText: !isNameValid && _nameController.text.isNotEmpty
                  ? 'Exam name cannot be empty'
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true,
            onChanged: (value) {
              setState(() {
                // Trigger rebuild to update button state
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter exam description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
          if (!isNameValid) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please enter an exam name to continue',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isNameValid
              ? () => Navigator.pop(context, {
                  'name': _nameController.text.trim(),
                  'description': _descriptionController.text.trim(),
                })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isNameValid
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: isNameValid
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
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
