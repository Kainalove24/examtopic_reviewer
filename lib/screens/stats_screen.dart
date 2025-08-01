import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../providers/progress_provider.dart';
import '../providers/exam_provider.dart';
import '../services/admin_auth_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String selectedTimeRange = '7d'; // 7d, 30d, 90d, all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final progressProvider = Provider.of<ProgressProvider>(context);
    final exams = examProvider.exams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Learning Analytics'),
        actions: [
          // Admin Portal Switch Button (only visible for authenticated admins)
          FutureBuilder<bool>(
            future: AdminAuthService.isAuthenticated(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return IconButton(
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    context.go('/admin');
                  },
                  tooltip: 'Switch to Admin Portal',
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up), text: 'Progress'),
            Tab(icon: Icon(Icons.analytics), text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, exams, progressProvider),
          _buildProgressTab(context, exams, progressProvider),
          _buildPerformanceTab(context, progressProvider),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    List exams,
    ProgressProvider progressProvider,
  ) {
    final stats = _calculateOverallStats(exams, progressProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Range Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📅 Time Range',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTimeRangeChip('7d', '7 Days'),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip('30d', '30 Days'),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip('90d', '90 Days'),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip('all', 'All Time'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  '📚 Total Exams',
                  '${stats['totalExams']}',
                  Colors.blue,
                  Icons.book,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  '❓ Total Questions',
                  '${stats['totalQuestions']}',
                  Colors.orange,
                  Icons.quiz,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  '✅ Mastered',
                  '${stats['totalMastered']}',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  '📈 Mastery Rate',
                  '${stats['masteryRate']}%',
                  Colors.purple,
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Overview Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Overall Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 200, child: _buildProgressPieChart(stats)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Study Streak
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔥 Study Streak',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats['currentStreak']} days',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Current streak',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stats['bestStreak']} days',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Best streak',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🕒 Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentActivityList(progressProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab(
    BuildContext context,
    List exams,
    ProgressProvider progressProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Progress Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📈 Exam Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildExamProgressChart(exams, progressProvider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Daily Activity Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📅 Daily Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildDailyActivityChart(progressProvider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Study Time Distribution
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏰ Study Time Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildStudyTimeChart(progressProvider),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(
    BuildContext context,
    ProgressProvider progressProvider,
  ) {
    final quizStats = _calculateQuizStats(progressProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz Performance Overview
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  '🎯 Quiz Attempts',
                  '${quizStats['totalAttempts']}',
                  Colors.indigo,
                  Icons.quiz,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  '📊 Average Score',
                  '${quizStats['averageScore']}%',
                  Colors.teal,
                  Icons.analytics,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  '🏆 Best Score',
                  '${quizStats['bestScore']}%',
                  Colors.amber,
                  Icons.emoji_events,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  '📈 Improvement',
                  '${quizStats['improvement']}%',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quiz Score Trend
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📈 Quiz Score Trend',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildQuizScoreChart(progressProvider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Performance by Question Type
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎯 Performance by Question Type',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildQuestionTypeChart(progressProvider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Study Efficiency Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚡ Study Efficiency',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildEfficiencyMetrics(progressProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChip(String value, String label) {
    final isSelected = selectedTimeRange == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedTimeRange = value;
        });
      },
      backgroundColor: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : Colors.grey[200],
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withOpacity(0.3),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressPieChart(Map<String, dynamic> stats) {
    final mastered = stats['totalMastered'] as int;
    final total = stats['totalQuestions'] as int;
    final remaining = total - mastered;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: mastered.toDouble(),
            title: '${((mastered / total) * 100).toStringAsFixed(1)}%',
            color: Colors.green,
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: remaining.toDouble(),
            title: '${((remaining / total) * 100).toStringAsFixed(1)}%',
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.grey[300]!,
            radius: 60,
            titleStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : Colors.black87,
            ),
          ),
        ],
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildExamProgressChart(
    List exams,
    ProgressProvider progressProvider,
  ) {
    final examData = <FlSpot>[];
    final examNames = <String>[];

    for (int i = 0; i < exams.length; i++) {
      final exam = exams[i];
      final progress = progressProvider.progress;
      final mastered = (progress['masteredQuestions'] as List?)?.length ?? 0;
      final total = exam.questions.length;
      final percentage = total > 0 ? (mastered / total) * 100 : 0.0;

      examData.add(FlSpot(i.toDouble(), percentage.toDouble()));
      examNames.add(
        exam.title.length > 10
            ? '${exam.title.substring(0, 10)}...'
            : exam.title,
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < examNames.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      examNames[value.toInt()],
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: examData.map((spot) {
          return BarChartGroupData(
            x: spot.x.toInt(),
            barRods: [
              BarChartRodData(
                toY: spot.y,
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyActivityChart(ProgressProvider progressProvider) {
    final activityData = <FlSpot>[];
    final today = DateTime.now();

    // Get activity data from progress provider
    final activityHistory =
        progressProvider.progress['activityHistory'] as Map<String, dynamic>? ??
        {};

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Get real activity data or default to 0
      final dayActivity = activityHistory[dateKey] as int? ?? 0;
      activityData.add(FlSpot(i.toDouble(), dayActivity.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: activityData,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyTimeChart(ProgressProvider progressProvider) {
    // Get real study time data from progress provider
    final studyTimeData =
        progressProvider.progress['studyTimeDistribution']
            as Map<String, dynamic>? ??
        {};

    final timeData = [
      {
        'time': 'Morning',
        'hours': studyTimeData['morning'] as double? ?? 0.0,
        'color': Colors.orange,
      },
      {
        'time': 'Afternoon',
        'hours': studyTimeData['afternoon'] as double? ?? 0.0,
        'color': Colors.blue,
      },
      {
        'time': 'Evening',
        'hours': studyTimeData['evening'] as double? ?? 0.0,
        'color': Colors.purple,
      },
      {
        'time': 'Night',
        'hours': studyTimeData['night'] as double? ?? 0.0,
        'color': Colors.indigo,
      },
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 5,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < timeData.length) {
                  return Text(
                    timeData[value.toInt()]['time'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: timeData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data['hours'] as double,
                color: data['color'] as Color,
                width: 30,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuizScoreChart(ProgressProvider progressProvider) {
    final quizScores =
        (progressProvider.progress['quizScores'] as List?)?.cast<int>() ?? [];

    if (quizScores.isEmpty) {
      return Center(
        child: Text(
          'No quiz data available yet.\nTake some quizzes to see your progress!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final scoreData = <FlSpot>[];
    for (int i = 0; i < quizScores.length; i++) {
      scoreData.add(FlSpot(i.toDouble(), quizScores[i].toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  'Q${value.toInt() + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: scoreData,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeChart(ProgressProvider progressProvider) {
    // Get real question type performance data
    final questionTypeStats =
        progressProvider.progress['questionTypeStats']
            as Map<String, dynamic>? ??
        {};

    final typeData = [
      {
        'type': 'MCQ',
        'accuracy': questionTypeStats['mcq'] as int? ?? 0,
        'color': Colors.blue,
      },
      {
        'type': 'True/False',
        'accuracy': questionTypeStats['trueFalse'] as int? ?? 0,
        'color': Colors.green,
      },
      {
        'type': 'Fill Blank',
        'accuracy': questionTypeStats['fillBlank'] as int? ?? 0,
        'color': Colors.orange,
      },
      {
        'type': 'Essay',
        'accuracy': questionTypeStats['essay'] as int? ?? 0,
        'color': Colors.red,
      },
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < typeData.length) {
                  return Text(
                    typeData[value.toInt()]['type'] as String,
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: typeData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data['accuracy'] as double,
                color: data['color'] as Color,
                width: 25,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEfficiencyMetrics(ProgressProvider progressProvider) {
    // Get real efficiency data from progress provider
    final efficiencyData =
        progressProvider.progress['efficiencyMetrics']
            as Map<String, dynamic>? ??
        {};

    final avgSessionMinutes = efficiencyData['avgSessionMinutes'] as int? ?? 0;
    final questionsPerHour = efficiencyData['questionsPerHour'] as int? ?? 0;
    final sessionsToday = efficiencyData['sessionsToday'] as int? ?? 0;
    final aiExplanationsUsed =
        efficiencyData['aiExplanationsUsed'] as int? ?? 0;

    return Column(
      children: [
        _buildEfficiencyRow(
          '⏱️ Average Study Session',
          '$avgSessionMinutes minutes',
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildEfficiencyRow(
          '🎯 Questions per Hour',
          '$questionsPerHour questions',
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildEfficiencyRow(
          '📚 Study Sessions Today',
          '$sessionsToday sessions',
          Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildEfficiencyRow(
          '💡 AI Explanations Used',
          '$aiExplanationsUsed times',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildEfficiencyRow(String label, String value, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList(ProgressProvider progressProvider) {
    final recentActivities =
        progressProvider.progress['recentActivities'] as List<dynamic>? ?? [];

    if (recentActivities.isEmpty) {
      return Text(
        'No recent activity.\nStart studying to see your activity here!',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: recentActivities.take(3).map((activity) {
        final activityData = activity as Map<String, dynamic>;
        final type = activityData['type'] as String? ?? '';
        final description = activityData['description'] as String? ?? '';
        final timeAgo = activityData['timeAgo'] as String? ?? '';
        final color = _getActivityColor(type);

        return Column(
          children: [
            _buildActivityItem(
              _getActivityIcon(type),
              description,
              timeAgo,
              color,
            ),
            if (activity != recentActivities.take(3).last)
              const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'quiz':
        return Colors.green;
      case 'mastered':
        return Colors.blue;
      case 'ai_explanation':
        return Colors.purple;
      case 'study_session':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getActivityIcon(String type) {
    switch (type) {
      case 'quiz':
        return '📖 Quiz Completed';
      case 'mastered':
        return '✅ Questions Mastered';
      case 'ai_explanation':
        return '🤖 AI Explanation';
      case 'study_session':
        return '📚 Study Session';
      default:
        return '📝 Activity';
    }
  }

  Widget _buildActivityItem(
    String title,
    String description,
    String time,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateOverallStats(
    List exams,
    ProgressProvider progressProvider,
  ) {
    int totalMastered = 0;
    int totalQuestions = 0;

    for (final exam in exams) {
      final progress = progressProvider.progress;
      final mastered = (progress['masteredQuestions'] as List?)?.length ?? 0;
      totalMastered += mastered;
      totalQuestions += exam.questions.length as int;
    }

    final masteryRate = totalQuestions > 0
        ? (totalMastered / totalQuestions * 100).round()
        : 0;

    // Calculate real streak data
    final streakData =
        progressProvider.progress['streakData'] as Map<String, dynamic>? ?? {};
    final realCurrentStreak = streakData['currentStreak'] as int? ?? 0;
    final realBestStreak = streakData['bestStreak'] as int? ?? 0;

    return {
      'totalExams': exams.length,
      'totalQuestions': totalQuestions,
      'totalMastered': totalMastered,
      'masteryRate': masteryRate,
      'currentStreak': realCurrentStreak,
      'bestStreak': realBestStreak,
    };
  }

  Map<String, dynamic> _calculateQuizStats(ProgressProvider progressProvider) {
    final quizScores =
        (progressProvider.progress['quizScores'] as List?)?.cast<int>() ?? [];

    if (quizScores.isEmpty) {
      return {
        'totalAttempts': 0,
        'averageScore': 0,
        'bestScore': 0,
        'improvement': 0,
      };
    }

    final totalAttempts = quizScores.length;
    final averageScore =
        (quizScores.reduce((a, b) => a + b) / quizScores.length).round();
    final bestScore = quizScores.reduce((a, b) => a > b ? a : b);

    // Calculate improvement (simplified)
    final improvement = quizScores.length > 1
        ? ((quizScores.last - quizScores.first) / quizScores.first * 100)
              .round()
        : 0;

    return {
      'totalAttempts': totalAttempts,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'improvement': improvement,
    };
  }
}
