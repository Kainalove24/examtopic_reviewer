import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/admin_service.dart';

class ExamSelectionScreen extends StatefulWidget {
  const ExamSelectionScreen({super.key});

  @override
  _ExamSelectionScreenState createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableExams();
  }

  Future<void> _loadAvailableExams() async {
    try {
      final exams = await AdminService.getAvailableExams();
      setState(() {
        _availableExams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading exams: $e')));
    }
  }

  void _startExam(String examId, String examCode) {
    context.go('/quiz-mode', extra: {'examId': examId, 'examCode': examCode});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Exams'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAvailableExams,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _availableExams.isEmpty
          ? _buildEmptyState()
          : _buildExamsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Exams Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Contact your administrator to add exam content',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExamsList() {
    return Padding(
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
                  Icon(Icons.quiz, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Available Exams (${_availableExams.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Exams List
          Expanded(
            child: ListView.builder(
              itemCount: _availableExams.length,
              itemBuilder: (context, index) {
                final exam = _availableExams[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _startExam(exam['id'], exam['examCode']),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Exam Icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.quiz,
                              color: Colors.deepPurple,
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 16),

                          // Exam Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exam['examCode'] ?? 'Unknown Exam',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Category: ${exam['category'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${exam['questionCount'] ?? 0} questions',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Imported: ${exam['importDate']?.toString().split('T')[0] ?? 'Unknown'}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Start Button
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Start',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
