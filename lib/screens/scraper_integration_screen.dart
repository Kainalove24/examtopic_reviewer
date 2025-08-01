import 'package:flutter/material.dart';
import '../services/scraper_api_service.dart';
import '../models/exam_question.dart';

class ScraperIntegrationScreen extends StatefulWidget {
  const ScraperIntegrationScreen({super.key});

  @override
  _ScraperIntegrationScreenState createState() =>
      _ScraperIntegrationScreenState();
}

class _ScraperIntegrationScreenState extends State<ScraperIntegrationScreen> {
  bool _isConnected = false;
  bool _isLoading = false;
  String _selectedCategory = '';
  String _selectedExam = '';
  Map<String, String> _categories = {};
  List<String> _exams = [];
  List<ExamQuestion> _questions = [];
  String _currentJobId = '';
  int _progress = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkConnection();
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
    final categories = await ScraperApiService.getCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _loadExams(String category) async {
    setState(() {
      _isLoading = true;
    });

    final exams = await ScraperApiService.getExamsForCategory(category);
    setState(() {
      _exams = exams;
      _isLoading = false;
    });
  }

  Future<void> _startScraping() async {
    if (_selectedCategory.isEmpty || _selectedExam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select category and exam')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0;
      _status = 'Starting scraping job...';
      _questions = [];
    });

    try {
      // Start scraping job
      final result = await ScraperApiService.startScraping(
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
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _pollJobStatus() async {
    while (true) {
      await Future.delayed(Duration(seconds: 2));

      final status = await ScraperApiService.getJobStatus(_currentJobId);

      if (status.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _status = 'Error: ${status['error']}';
        });
        return;
      }

      setState(() {
        _progress = status['progress'] ?? 0;
        _status = 'Status: ${status['status']} ($_progress%)';
      });

      if (status['status'] == 'completed') {
        // Get CSV content and parse questions
        final csvContent = status['result']['csv_content'];
        if (csvContent != null) {
          final questions = ScraperApiService.parseCsvContent(csvContent);
          setState(() {
            _questions = questions;
            _isLoading = false;
            _status = 'Completed! Found ${questions.length} questions';
          });
        }
        return;
      } else if (status['status'] == 'failed') {
        setState(() {
          _isLoading = false;
          _status = 'Failed: ${status['error']}';
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scraper Integration'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _checkConnection,
            tooltip: _isConnected ? 'Connected' : 'Disconnected',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isConnected
                          ? 'Connected to Scraper API'
                          : 'Disconnected from Scraper API',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Category Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory.isEmpty
                          ? null
                          : _selectedCategory,
                      hint: Text('Select category'),
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
            SizedBox(height: 16),

            // Exam Selection
            if (_selectedCategory.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exam',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedExam.isEmpty ? null : _selectedExam,
                        hint: Text('Select exam'),
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
            SizedBox(height: 16),

            // Scrape Button
            ElevatedButton(
              onPressed: _isConnected && !_isLoading ? _startScraping : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Start Scraping'),
            ),
            SizedBox(height: 16),

            // Progress and Status
            if (_isLoading || _status.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(_status),
                      if (_progress > 0) ...[
                        SizedBox(height: 8),
                        LinearProgressIndicator(value: _progress / 100),
                        SizedBox(height: 4),
                        Text('Progress: $_progress%'),
                      ],
                    ],
                  ),
                ),
              ),
            SizedBox(height: 16),

            // Results
            if (_questions.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results (${_questions.length} questions)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _questions.length,
                            itemBuilder: (context, index) {
                              final question = _questions[index];
                              return ListTile(
                                title: Text(
                                  question.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('Type: ${question.type}'),
                                trailing: Text('ID: ${question.id}'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
