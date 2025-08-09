import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/scraper_api_service.dart';
import '../models/exam_question.dart';
import '../providers/exam_provider.dart';
import '../utils/logger.dart';

class EnhancedScraperIntegrationScreen extends StatefulWidget {
  const EnhancedScraperIntegrationScreen({super.key});

  @override
  _EnhancedScraperIntegrationScreenState createState() =>
      _EnhancedScraperIntegrationScreenState();
}

class _EnhancedScraperIntegrationScreenState
    extends State<EnhancedScraperIntegrationScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Connection state
  bool _isConnected = false;
  bool _isLoading = false;

  // Category and exam selection
  String _selectedCategory = '';
  String _selectedExam = '';
  Map<String, String> _categories = {};
  List<String> _exams = [];

  // CSV import state
  String? _csvFilePath;
  String? _csvFileName;
  List<Map<String, dynamic>> _csvLinks = [];
  bool _isImportingCsv = false;

  // Scraping state
  String _currentJobId = '';
  int _progress = 0;
  String _status = '';
  List<ExamQuestion> _scrapedQuestions = [];
  bool _isScraping = false;

  // Data editing state
  List<ExamQuestion> _editableQuestions = [];
  bool _isEditing = false;
  int _currentEditIndex = 0;

  // Import state
  String? _examName;
  String? _examDescription;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkConnection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
    });

    final connected = await ScraperApiService.checkHealth();
    setState(() {
      _isConnected = connected;
      _isLoading = false;
    });

    if (connected) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ScraperApiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      Logger.error('Failed to load categories: $e');
    }
  }

  Future<void> _loadExams(String category) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exams = await ScraperApiService.getExamsForCategory(category);
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Logger.error('Failed to load exams: $e');
    }
  }

  Future<void> _importCsvFile() async {
    try {
      setState(() {
        _isImportingCsv = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Parse CSV content
        final lines = content.split('\n');
        final headers = lines.first.split(',');

        _csvLinks = [];
        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isNotEmpty) {
            final values = lines[i].split(',');
            if (values.length >= 3) {
              _csvLinks.add({
                'topic': values[0].trim(),
                'question': values[1].trim(),
                'link': values[2].trim(),
              });
            }
          }
        }

        setState(() {
          _csvFilePath = file.path;
          _csvFileName = p.basename(file.path);
          _isImportingCsv = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Imported ${_csvLinks.length} links from CSV'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImportingCsv = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to import CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startScraping() async {
    if (_csvLinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please import a CSV file with links first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isScraping = true;
      _progress = 0;
      _status = 'Starting scraping job...';
      _scrapedQuestions = [];
    });

    try {
      // Start scraping job with CSV data
      final result = await ScraperApiService.startScrapingWithCsv(
        _csvLinks,
        _selectedCategory,
        _selectedExam,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      _currentJobId = result['job_id'] as String;
      _status = 'Job started, monitoring progress...';

      // Poll for completion
      await _pollJobStatus();
    } catch (e) {
      setState(() {
        _isScraping = false;
        _status = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Scraping failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pollJobStatus() async {
    while (_isScraping) {
      try {
        final status = await ScraperApiService.getJobStatus(_currentJobId);

        setState(() {
          _progress = status['progress'] ?? 0;
          _status = status['status'] ?? 'Unknown';
        });

        if (status['status'] == 'completed') {
          // Download results
          final results = await ScraperApiService.downloadResults(
            _currentJobId,
          );
          _scrapedQuestions = _parseScrapedResults(results);

          setState(() {
            _isScraping = false;
            _status = 'Scraping completed!';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Scraped ${_scrapedQuestions.length} questions'),
              backgroundColor: Colors.green,
            ),
          );

          // Switch to editing tab
          _tabController.animateTo(2);
          break;
        } else if (status['status'] == 'failed') {
          setState(() {
            _isScraping = false;
            _status = 'Scraping failed';
          });
          break;
        }

        await Future.delayed(Duration(seconds: 2));
      } catch (e) {
        setState(() {
          _isScraping = false;
          _status = 'Error polling status: $e';
        });
        break;
      }
    }
  }

  List<ExamQuestion> _parseScrapedResults(Map<String, dynamic> results) {
    final List<ExamQuestion> questions = [];

    try {
      final data = results['data'] as List<dynamic>;
      for (final item in data) {
        questions.add(
          ExamQuestion(
            id: item['id'] ?? 0,
            type: item['type'] ?? 'multiple_choice',
            text: item['question_text'] ?? '',
            questionImages: List<String>.from(item['images'] ?? []),
            answerImages: [],
            options: List<String>.from(item['options'] ?? []),
            answers: [item['correct_answer'] ?? ''],
            explanation: item['explanation'] ?? '',
            aiExplanation: null,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to parse scraped results: $e');
    }

    return questions;
  }

  void _prepareForEditing() {
    setState(() {
      _editableQuestions = List.from(_scrapedQuestions);
      _isEditing = true;
      _currentEditIndex = 0;
    });
  }

  void _saveQuestion(int index, ExamQuestion question) {
    setState(() {
      _editableQuestions[index] = question;
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _editableQuestions.removeAt(index);
      if (_currentEditIndex >= _editableQuestions.length) {
        _currentEditIndex = _editableQuestions.length - 1;
      }
    });
  }

  Future<void> _importAsExam() async {
    if (_editableQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No questions to import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_examName == null || _examName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an exam name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final examProvider = Provider.of<ExamProvider>(context, listen: false);

      // Create exam entry
      final examEntry = ExamEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _examName!,
        questions: _editableQuestions,
      );

      // Save to exam provider
      examProvider.addExam(examEntry);
      await examProvider.saveAllExams();

      setState(() {
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Exam imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to library
      if (mounted) {
        context.go('/library');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to import exam: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Scraper Integration'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Setup', icon: Icon(Icons.settings)),
            Tab(text: 'Scrape', icon: Icon(Icons.download)),
            Tab(text: 'Edit', icon: Icon(Icons.edit)),
            Tab(text: 'Import', icon: Icon(Icons.upload)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSetupTab(theme),
          _buildScrapeTab(theme),
          _buildEditTab(theme),
          _buildImportTab(theme),
        ],
      ),
    );
  }

  Widget _buildSetupTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isConnected ? 'Connected to Scraper API' : 'Not connected',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Exam Category',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Category',
                    ),
                    items: _categories.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? '';
                        _selectedExam = '';
                        _exams = [];
                      });
                      if (value != null) {
                        _loadExams(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Exam Selection
          if (_selectedCategory.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Exam', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedExam.isEmpty ? null : _selectedExam,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Exam',
                        ),
                        items: _exams.map((exam) {
                          return DropdownMenuItem(
                            value: exam,
                            child: Text(exam),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedExam = value ?? '';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // CSV Import
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import CSV Links', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_csvFileName != null) Text('Selected: $_csvFileName'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isImportingCsv ? null : _importCsvFile,
                    icon: _isImportingCsv
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(
                      _isImportingCsv ? 'Importing...' : 'Import CSV',
                    ),
                  ),
                  if (_csvLinks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Imported ${_csvLinks.length} links',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrapeTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scraping Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scraping Status', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_isScraping) ...[
                    LinearProgressIndicator(value: _progress / 100),
                    const SizedBox(height: 8),
                    Text('Progress: $_progress%'),
                    const SizedBox(height: 8),
                    Text('Status: $_status'),
                  ] else
                    Text('Ready to start scraping'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Start Scraping Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start Scraping', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: (_csvLinks.isNotEmpty && !_isScraping)
                        ? _startScraping
                        : null,
                    icon: _isScraping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isScraping ? 'Scraping...' : 'Start Scraping'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          if (_scrapedQuestions.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scraping Results',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Scraped ${_scrapedQuestions.length} questions'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _prepareForEditing,
                      child: const Text('Edit Questions'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditTab(ThemeData theme) {
    if (_editableQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No questions to edit', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Complete scraping first to edit questions',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Navigation
        Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _currentEditIndex > 0
                      ? () {
                          setState(() {
                            _currentEditIndex--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Question ${_currentEditIndex + 1} of ${_editableQuestions.length}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _currentEditIndex < _editableQuestions.length - 1
                      ? () {
                          setState(() {
                            _currentEditIndex++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),

        // Question Editor
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildQuestionEditor(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(ThemeData theme) {
    final question = _editableQuestions[_currentEditIndex];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Text
            Text('Question Text', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter question text...',
              ),
              controller: TextEditingController(text: question.text),
              onChanged: (value) {
                final updatedQuestion = question.copyWith(text: value);
                _saveQuestion(_currentEditIndex, updatedQuestion);
              },
            ),
            const SizedBox(height: 16),

            // Options
            Text('Options', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(question.options.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Option ${index + 1}',
                        ),
                        controller: TextEditingController(
                          text: question.options[index],
                        ),
                        onChanged: (value) {
                          final newOptions = List<String>.from(
                            question.options,
                          );
                          newOptions[index] = value;
                          final updatedQuestion = question.copyWith(
                            options: newOptions,
                          );
                          _saveQuestion(_currentEditIndex, updatedQuestion);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final newOptions = List<String>.from(question.options);
                        newOptions.removeAt(index);
                        final updatedQuestion = question.copyWith(
                          options: newOptions,
                        );
                        _saveQuestion(_currentEditIndex, updatedQuestion);
                      },
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                    ),
                  ],
                ),
              );
            }),
            ElevatedButton.icon(
              onPressed: () {
                final newOptions = List<String>.from(question.options);
                newOptions.add('');
                final updatedQuestion = question.copyWith(options: newOptions);
                _saveQuestion(_currentEditIndex, updatedQuestion);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Option'),
            ),
            const SizedBox(height: 16),

            // Correct Answer
            Text('Correct Answer', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter correct answer...',
              ),
              controller: TextEditingController(
                text: question.answers.isNotEmpty ? question.answers.first : '',
              ),
              onChanged: (value) {
                final updatedQuestion = question.copyWith(answers: [value]);
                _saveQuestion(_currentEditIndex, updatedQuestion);
              },
            ),
            const SizedBox(height: 16),

            // Explanation
            Text('Explanation', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter explanation...',
              ),
              controller: TextEditingController(text: question.explanation),
              onChanged: (value) {
                final updatedQuestion = question.copyWith(explanation: value);
                _saveQuestion(_currentEditIndex, updatedQuestion);
              },
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteQuestion(_currentEditIndex),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(3);
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Import Exam'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exam Details', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Exam Name',
                      hintText: 'Enter exam name...',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _examName = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Description (Optional)',
                      hintText: 'Enter exam description...',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _examDescription = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import Summary', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Questions to import: ${_editableQuestions.length}'),
                  if (_examName != null && _examName!.isNotEmpty)
                    Text('Exam name: $_examName'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed:
                        _editableQuestions.isNotEmpty &&
                            _examName != null &&
                            _examName!.isNotEmpty
                        ? _importAsExam
                        : null,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                      _isImporting ? 'Importing...' : 'Import as Exam',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
