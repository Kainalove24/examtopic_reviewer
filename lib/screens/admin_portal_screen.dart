import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/scraper_api_service.dart';
import '../services/admin_service.dart';
import '../services/admin_auth_service.dart';
import '../services/csv_import_service.dart';
import '../services/admin_portal_cache_service.dart';
import '../services/optimized_job_polling_service.dart';
import '../models/exam_question.dart';
import '../providers/exam_provider.dart';
import 'cloud_voucher_management_screen.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  _AdminPortalScreenState createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
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

  // Exam management
  List<Map<String, dynamic>> _importedExams = [];
  bool _isLoadingExams = false;

  // CSV Import management
  List<ExamQuestion> _csvQuestions = [];
  bool _isImportingCsv = false;
  String _csvImportStatus = '';
  Map<String, dynamic>? _csvValidationResult;

  // Image Processing Server connection
  bool _isImageServerConnected = false;
  bool _isCheckingImageServer = false;

  // Performance tracking
  int _loadTime = 0;
  Map<String, dynamic> _cacheStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAuthentication();
    _checkConnection();
    _checkImageServerConnection();
    _loadImportedExams();
    _loadCacheStatus();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await AdminAuthService.isAuthenticated();
    if (!isAuthenticated) {
      // Redirect to auth screen if not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth');
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    OptimizedJobPollingService.stopAllPolling();
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
    final stopwatch = Stopwatch()..start();

    try {
      // Try to get cached categories first
      final cachedCategories =
          await AdminPortalCacheService.getCachedCategories();
      if (cachedCategories != null) {
        setState(() {
          _categories = cachedCategories;
          _loadTime = stopwatch.elapsedMilliseconds;
        });
        print('📚 Categories loaded from cache in ${_loadTime}ms');
        return;
      }

      // Fetch fresh categories
      final categories = await ScraperApiService.getCategories();

      // Cache the categories
      await AdminPortalCacheService.cacheCategories(categories);

      setState(() {
        _categories = categories;
        _loadTime = stopwatch.elapsedMilliseconds;
      });
      print('📚 Categories loaded from API in ${_loadTime}ms');
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _checkImageServerConnection() async {
    setState(() {
      _isCheckingImageServer = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://image-processing-server-0ski.onrender.com/api/health',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      setState(() {
        _isImageServerConnected = response.statusCode == 200;
        _isCheckingImageServer = false;
      });
    } catch (e) {
      setState(() {
        _isImageServerConnected = false;
        _isCheckingImageServer = false;
      });
    }
  }

  Future<void> _loadCacheStatus() async {
    try {
      final status = await AdminPortalCacheService.getCacheStatus();
      setState(() {
        _cacheStatus = status;
      });
    } catch (e) {
      print('Error loading cache status: $e');
    }
  }

  void _showCacheInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cached, color: Colors.blue),
            SizedBox(width: 8),
            Text('Cache Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cache Count: ${_cacheStatus['cacheCount'] ?? 0}'),
            SizedBox(height: 8),
            Text(
              'Categories Cached: ${_cacheStatus['hasCategories'] ? 'Yes' : 'No'}',
            ),
            Text(
              'Exams Cached: ${_cacheStatus['hasImportedExams'] ? 'Yes' : 'No'}',
            ),
            Text('Jobs Cached: ${_cacheStatus['hasJobs'] ? 'Yes' : 'No'}'),
            SizedBox(height: 16),
            Text(
              'Cache improves performance by storing frequently accessed data locally.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await AdminPortalCacheService.clearAllCaches();
              await _loadCacheStatus();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Cache cleared')));
            },
            child: Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExams(String category) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get cached exams first
      final cachedExams =
          await AdminPortalCacheService.getCachedExamsForCategory(category);
      if (cachedExams != null) {
        setState(() {
          _exams = cachedExams;
          _isLoading = false;
        });
        print('📚 Exams loaded from cache for category: $category');
        return;
      }

      // Fetch fresh exams
      final exams = await ScraperApiService.getExamsForCategory(category);

      // Cache the exams
      await AdminPortalCacheService.cacheExamsForCategory(category, exams);

      setState(() {
        _exams = exams;
        _isLoading = false;
      });
      print('📚 Exams loaded from API for category: $category');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading exams: $e');
    }
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
      final result = await ScraperApiService.startScraping(
        _selectedCategory,
        _selectedExam,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      _currentJobId = result['job_id'];
      _status = 'Job started, monitoring progress...';

      await _pollJobStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _pollJobStatus() async {
    OptimizedJobPollingService.startPolling(
      _currentJobId,
      (status) {
        // Status update callback
        setState(() {
          _progress = status['progress'] ?? 0;
          _status = 'Status: ${status['status']} ($_progress%)';
        });
      },
      (jobId) {
        // Completion callback
        _handleJobCompletion(jobId);
      },
      (error) {
        // Error callback
        setState(() {
          _isLoading = false;
          _status = 'Error: $error';
        });
      },
    );
  }

  Future<void> _handleJobCompletion(String jobId) async {
    try {
      final status = await ScraperApiService.getJobStatus(jobId);
      final csvContent = status['result']['csv_content'];

      if (csvContent != null) {
        final questions = ScraperApiService.parseCsvContent(csvContent);
        setState(() {
          _questions = questions;
          _isLoading = false;
          _status = 'Completed! Found ${questions.length} questions';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error getting job results: $e';
      });
    }
  }

  Future<void> _importExam() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No questions to import')));
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final success = await AdminService.importExam(
        _selectedCategory,
        _selectedExam,
        _questions,
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exam imported successfully!')));
        _loadImportedExams();
        setState(() {
          _questions = [];
          _status = '';
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import exam')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImportedExams() async {
    setState(() {
      _isLoadingExams = true;
    });

    try {
      // Try to get cached exams first
      final cachedExams =
          await AdminPortalCacheService.getCachedImportedExams();
      if (cachedExams != null) {
        setState(() {
          _importedExams = cachedExams;
          _isLoadingExams = false;
        });
        print('📚 Imported exams loaded from cache');
        return;
      }

      // Fetch fresh exams
      final exams = await AdminService.getImportedExams();

      // Cache the exams
      await AdminPortalCacheService.cacheImportedExams(exams);

      setState(() {
        _importedExams = exams;
        _isLoadingExams = false;
      });
      print('📚 Imported exams loaded from API');
    } catch (e) {
      setState(() {
        _isLoadingExams = false;
      });
      print('Error loading exams: $e');
    }
  }

  Future<void> _pickAndParseCsv() async {
    setState(() {
      _isImportingCsv = true;
      _csvImportStatus = 'Picking CSV file...';
      _csvQuestions = [];
      _csvValidationResult = null;
    });

    try {
      final result = await CsvImportService.pickAndParseCsv();

      if (result['success']) {
        final questions = result['questions'] as List<ExamQuestion>;
        final errors = result['errors'] as List<String>;
        final imageConversions =
            result['image_conversions'] as List<String>? ?? [];
        final format = result['format'] as String? ?? 'unknown';

        setState(() {
          _csvQuestions = questions;
          _csvValidationResult = {
            'valid_questions': questions.length,
            'total_errors': errors.length,
            'errors': errors,
            'total_rows': result['total_rows'],
            'image_conversions': imageConversions,
            'format': format,
          };
          _csvImportStatus =
              'CSV parsed successfully! Found ${questions.length} valid questions ($format format)';

          if (imageConversions.isNotEmpty) {
            _csvImportStatus += '\n${imageConversions.length} images processed';
          }
        });
      } else {
        setState(() {
          _csvImportStatus = 'Error: ${result['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _csvImportStatus = 'Error parsing CSV: $e';
      });
    } finally {
      setState(() {
        _isImportingCsv = false;
      });
    }
  }

  Future<void> _importCsvQuestions() async {
    if (_csvQuestions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No questions to import')));
      return;
    }

    // Show dialog to get exam name
    final TextEditingController examNameController = TextEditingController();
    final examName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import CSV Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter a name for this exam:'),
            SizedBox(height: 16),
            TextField(
              controller: examNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Exam Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., AWS SAA Practice Exam',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, examNameController.text),
            child: Text('Import'),
          ),
        ],
      ),
    );

    if (examName == null || examName.trim().isEmpty) return;

    setState(() {
      _isImportingCsv = true;
      _csvImportStatus = 'Importing questions...';
    });

    try {
      final result = await CsvImportService.importQuestionsToExam(
        examName.trim(),
        'CSV Import',
        _csvQuestions,
      );

      if (result['success']) {
        // Also save to ExamProvider for quiz functionality
        final examProvider = Provider.of<ExamProvider>(context, listen: false);
        final examEntry = ExamEntry(
          id: result['exam'].id,
          title: result['exam'].title,
          questions: _csvQuestions,
        );
        examProvider.addExam(examEntry);
        await examProvider.saveAllExams();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exam imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear the imported questions
        setState(() {
          _csvQuestions = [];
          _csvValidationResult = null;
          _csvImportStatus = '';
        });

        // Reload imported exams
        _loadImportedExams();
      } else {
        setState(() {
          _csvImportStatus = 'Import failed: ${result['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _csvImportStatus = 'Import error: $e';
      });
    } finally {
      setState(() {
        _isImportingCsv = false;
      });
    }
  }

  void _downloadCsvTemplate() {
    final template = CsvImportService.getCsvTemplate();
    // TODO: Implement file download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV template copied to clipboard'),
        backgroundColor: Colors.blue,
      ),
    );
    Clipboard.setData(ClipboardData(text: template));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Portal'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _checkConnection,
            tooltip: _isConnected ? 'Connected' : 'Disconnected',
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.cached),
                if (_cacheStatus['cacheCount'] != null &&
                    _cacheStatus['cacheCount'] > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        '${_cacheStatus['cacheCount']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showCacheInfo(),
            tooltip: 'Cache Status',
          ),
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () {
              // Switch to regular app
              context.go('/library');
            },
            tooltip: 'Switch to App',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await AdminAuthService.logout();
              Navigator.pop(context);
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.download), text: 'Scraper'),
            Tab(icon: Icon(Icons.cloud), text: 'Vouchers'),
            Tab(icon: Icon(Icons.library_books), text: 'Exams'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScraperTab(),
          CloudVoucherManagementScreen(),
          _buildExamsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildScraperTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.grey[100],
            child: TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.deepPurple,
              tabs: [
                Tab(icon: Icon(Icons.play_arrow), text: 'Scrape'),
                Tab(icon: Icon(Icons.history), text: 'Jobs'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildScrapeTab(),
                _buildJobsTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrapeTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected
                              ? 'Connected to Scraper API'
                              : 'Disconnected from Scraper API',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Server: http://localhost:5000',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (_loadTime > 0)
                          Text(
                            'Loaded in ${_loadTime}ms',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _checkConnection,
                    tooltip: 'Refresh Connection',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Quick Actions Row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.list,
                  title: 'Categories',
                  subtitle: '${_categories.length} available',
                  color: Colors.blue,
                  onTap: () => _showCategoriesDialog(),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.history,
                  title: 'Recent Jobs',
                  subtitle: 'View all jobs',
                  color: Colors.orange,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Enhanced Scraper Integration Button
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Enhanced Scraper Integration',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Advanced scraping with CSV import, data editing, and exam creation',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/enhanced-scraper'),
                    icon: Icon(Icons.rocket_launch),
                    label: Text('Open Enhanced Scraper'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Scraping Configuration
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text(
                        'Scraping Configuration',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Category Selection
                  _buildDropdownField(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
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
                  SizedBox(height: 16),

                  // Exam Selection
                  if (_selectedCategory.isNotEmpty)
                    _buildDropdownField(
                      label: 'Exam',
                      value: _selectedExam,
                      items: _exams
                          .map(
                            (exam) => DropdownMenuItem(
                              value: exam,
                              child: Text(exam),
                            ),
                          )
                          .toList(),
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

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isConnected &&
                          !_isLoading &&
                          _selectedCategory.isNotEmpty &&
                          _selectedExam.isNotEmpty
                      ? _startScraping
                      : null,
                  icon: Icon(Icons.play_arrow),
                  label: Text('Start Scraping'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _questions.isNotEmpty ? _importExam : null,
                  icon: Icon(Icons.download),
                  label: Text('Import Exam'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Progress and Status
          if (_isLoading || _status.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoading ? Icons.sync : Icons.info,
                          color: _isLoading ? Colors.blue : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(_status),
                    if (_progress > 0) ...[
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _progress / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress: $_progress%'),
                          if (_currentJobId.isNotEmpty)
                            Text('Job ID: ${_currentJobId.substring(0, 8)}...'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SizedBox(height: 16),

          // Results
          if (_questions.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Results (${_questions.length} questions)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Spacer(),
                        TextButton.icon(
                          onPressed: () => _showResultsDialog(),
                          icon: Icon(Icons.visibility),
                          label: Text('View Details'),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _questions.length > 5
                            ? 5
                            : _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getQuestionTypeColor(
                                question.type,
                              ),
                              child: Text(
                                question.type.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              question.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'ID: ${question.id} • Type: ${question.type}',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: question.questionImages.isNotEmpty
                                ? Icon(Icons.image, color: Colors.blue)
                                : null,
                          );
                        },
                      ),
                    ),
                    if (_questions.length > 5)
                      Center(
                        child: TextButton(
                          onPressed: () => _showResultsDialog(),
                          child: Text(
                            'View all ${_questions.length} questions',
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

  Widget _buildJobsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: OptimizedJobPollingService.preloadJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text(
                        'Scraping Jobs (${jobs.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => setState(() {}),
                        tooltip: 'Refresh Jobs',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Jobs List
              if (jobs.isEmpty)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No jobs found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a scraping job to see it here',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...jobs.map((job) => _buildJobCard(job)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.category,
                  title: 'Categories',
                  value: '${_categories.length}',
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.question_answer,
                  title: 'Questions',
                  value: '${_questions.length}',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Connection Status
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(_isConnected ? 'Connected' : 'Disconnected'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          hint: Text('Select $label'),
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String? ?? 'unknown';
    final progress = job['progress'] as int? ?? 0;
    final category = job['category'] as String? ?? '';
    final examCode = job['exam_code'] as String? ?? '';
    final jobId = job['job_id'] as String? ?? '';
    final startTime = job['start_time'] as String? ?? '';
    final endTime = job['end_time'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$category - $examCode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Job ID: ${jobId.substring(0, 8)}...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (status == 'running' && progress > 0) ...[
              LinearProgressIndicator(value: progress / 100),
              SizedBox(height: 8),
              Text('Progress: $progress%'),
              SizedBox(height: 12),
            ],

            Row(
              children: [
                if (startTime.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Started: ${_formatDateTime(startTime)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                if (endTime.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Ended: ${_formatDateTime(endTime)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12),
            Row(
              children: [
                if (status == 'completed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadJobResults(jobId),
                      icon: Icon(Icons.download),
                      label: Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cleanupJob(jobId),
                    icon: Icon(Icons.delete),
                    label: Text('Cleanup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _getQuestionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'mcq':
        return Colors.blue;
      case 'hotspot':
        return Colors.orange;
      case 'ordering':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  void _showCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Available Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final entry = _categories.entries.elementAt(index);
              return ListTile(
                title: Text(entry.value),
                subtitle: Text(entry.key),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() {
                    _selectedCategory = entry.key;
                    _selectedExam = '';
                    _exams = [];
                  });
                  _loadExams(entry.key);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scraping Results'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getQuestionTypeColor(question.type),
                    child: Text(
                      question.type.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    question.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${question.id}'),
                      if (question.questionImages.isNotEmpty)
                        Text('Images: ${question.questionImages.length}'),
                      if (question.options.isNotEmpty)
                        Text('Options: ${question.options.length}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadJobResults(String jobId) async {
    try {
      final csvContent = await ScraperApiService.downloadCsv(jobId);
      if (csvContent != null) {
        final questions = ScraperApiService.parseCsvContent(csvContent);
        setState(() {
          _questions = questions;
          _status = 'Downloaded ${questions.length} questions from job $jobId';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${questions.length} questions')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download results')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cleanupJob(String jobId) async {
    try {
      final success = await ScraperApiService.cleanupJob(jobId);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Job cleaned up successfully')));
        setState(() {}); // Refresh jobs list
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cleanup job')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildExamsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.library_books, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Imported Exams (${_importedExams.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _loadImportedExams,
                    tooltip: 'Refresh Exams List',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // CSV Import Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.file_upload, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'CSV Import',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Image Processing Server Connection Status
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isImageServerConnected
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isImageServerConnected
                            ? Colors.green
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isCheckingImageServer
                              ? Icons.sync
                              : (_isImageServerConnected
                                    ? Icons.check_circle
                                    : Icons.error),
                          color: _isCheckingImageServer
                              ? Colors.blue
                              : (_isImageServerConnected
                                    ? Colors.green
                                    : Colors.red),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCheckingImageServer
                                    ? 'Checking Image Processing Server...'
                                    : (_isImageServerConnected
                                          ? 'Image Processing Server Connected'
                                          : 'Image Processing Server Disconnected'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isCheckingImageServer
                                      ? Colors.blue
                                      : (_isImageServerConnected
                                            ? Colors.green
                                            : Colors.red),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Server: https://image-processing-server-0ski.onrender.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isCheckingImageServer)
                          IconButton(
                            icon: Icon(Icons.refresh, size: 16),
                            onPressed: _checkImageServerConnection,
                            tooltip: 'Refresh Connection',
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  Text(
                    'Import exam questions from a CSV file. Uses the standard format:',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Format: id, type, text, question_images, answer_images, options, answers, explanation',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isImportingCsv ? null : _pickAndParseCsv,
                          icon: _isImportingCsv
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.file_upload),
                          label: Text(
                            _isImportingCsv ? 'Processing...' : 'Pick CSV File',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _csvQuestions.isNotEmpty
                              ? _importCsvQuestions
                              : null,
                          icon: Icon(Icons.save),
                          label: Text('Import Questions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadCsvTemplate,
                          icon: Icon(Icons.download),
                          label: Text('Template'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_csvImportStatus.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _csvImportStatus.contains('Error')
                            ? Colors.red[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _csvImportStatus,
                        style: TextStyle(
                          color: _csvImportStatus.contains('Error')
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                  if (_csvValidationResult != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV Validation Results:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Valid Questions: ${_csvValidationResult!['valid_questions']}',
                          ),
                          Text(
                            'Total Rows: ${_csvValidationResult!['total_rows']}',
                          ),
                          if (_csvValidationResult!['format'] != null) ...[
                            Text('Format: ${_csvValidationResult!['format']}'),
                          ],
                          if (_csvValidationResult!['image_conversions'] !=
                              null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Image Conversions: ${(_csvValidationResult!['image_conversions'] as List<String>).length}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if ((_csvValidationResult!['image_conversions']
                                    as List<String>)
                                .isNotEmpty) ...[
                              SizedBox(height: 4),
                              ...(_csvValidationResult!['image_conversions']
                                      as List<String>)
                                  .take(5)
                                  .map(
                                    (conversion) => Text(
                                      '• $conversion',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                              if ((_csvValidationResult!['image_conversions']
                                          as List<String>)
                                      .length >
                                  5) ...[
                                Text(
                                  '... and ${(_csvValidationResult!['image_conversions'] as List<String>).length - 5} more',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ],
                          if (_csvValidationResult!['total_errors'] > 0) ...[
                            SizedBox(height: 8),
                            Text(
                              'Errors: ${_csvValidationResult!['total_errors']}',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'First few errors:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...(_csvValidationResult!['errors'] as List<String>)
                                .take(3)
                                .map(
                                  (error) => Text(
                                    '• $error',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[600],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Exams List
          _isLoadingExams
              ? Card(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading exams from Firestore...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _importedExams.isEmpty
              ? Container(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No exams found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No exams found in Firestore.\nImport exams using the CSV import feature above.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _importedExams.length,
                  itemBuilder: (context, index) {
                    final exam = _importedExams[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.quiz, color: Colors.deepPurple),
                        title: Text(exam['examCode'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category: ${exam['category'] ?? 'Unknown'}'),
                            Text('Questions: ${exam['questionCount'] ?? 0}'),
                            Text(
                              'Imported: ${exam['importDate'] ?? 'Unknown'}',
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteExam(exam['id']),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Future<void> _deleteExam(String examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Exam'),
        content: Text('Are you sure you want to delete this exam?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminService.deleteExam(examId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exam deleted successfully')));
        _loadImportedExams();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting exam: $e')));
      }
    }
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Admin Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Password Change Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text(
                        'Change Admin Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Change the admin password for enhanced security.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showPasswordChangeDialog(),
                    icon: Icon(Icons.lock_reset),
                    label: Text('Change Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Security Info Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text(
                        'Security Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildSecurityInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Session Timeout', '8 hours'),
        _buildInfoRow('Authentication', 'Local storage'),
        _buildInfoRow('Password Storage', 'Encrypted'),
        _buildInfoRow('Browser Security', 'Obfuscated code'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _showPasswordChangeDialog() async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Change Admin Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your current password and choose a new one.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),

              // Current Password
              TextField(
                controller: currentPasswordController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureCurrent = !obscureCurrent;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),

              // New Password
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureNew = !obscureNew;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Confirm New Password
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirm = !obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate inputs
                if (currentPasswordController.text.isEmpty ||
                    newPasswordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password must be at least 6 characters'),
                    ),
                  );
                  return;
                }

                // Verify current password
                final isValid = await AdminAuthService.authenticate(
                  'admin@admin.com',
                  currentPasswordController.text,
                );

                if (!isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Current password is incorrect')),
                  );
                  return;
                }

                // Change password
                await AdminAuthService.changePassword(
                  newPasswordController.text,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password changed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Change Password'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Password changed successfully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin password has been updated successfully! 🔐'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
