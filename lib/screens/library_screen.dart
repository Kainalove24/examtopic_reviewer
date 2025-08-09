// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/imported_exam_storage.dart';
import '../models/imported_exam.dart';
import '../models/exam_question.dart';
import 'package:provider/provider.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../services/user_exam_service.dart';
import '../services/admin_auth_service.dart';
import '../services/expiry_cleanup_service.dart';
import '../services/optimized_library_service.dart';
import '../utils/logger.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late FocusNode _focusNode;
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  String search = '';
  List<ImportedExam> importedExams = [];
  String? loadError;
  Map<String, int> examProgress = {}; // Cache for exam progress
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // New variables for user exams
  List<Map<String, dynamic>> userExams = [];
  List<Map<String, dynamic>> unlockedExams = [];
  List<Map<String, dynamic>> userImportedExams = [];
  bool _isSyncing = false; // Add sync state variable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _loadExams();
    _loadAllProgress();

    // Check if we need to force refresh (e.g., from voucher redemption)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRefreshParameter();
    });
  }

  // Check for refresh parameter in URL
  void _checkForRefreshParameter() {
    final uri = Uri.base;
    final refreshParam = uri.queryParameters['refresh'];
    if (refreshParam == 'true') {
      Logger.debug('Force refreshing library from voucher redemption');
      // Force refresh the library
      _loadExams();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh library when app comes back to foreground
      _loadExams();
    }
  }

  // Method to manually refresh the library
  void refreshLibrary() {
    if (mounted && !loading) {
      _loadExams();
    }
  }

  // Force refresh library (called from external sources)
  void forceRefreshLibrary() {
    Logger.debug('Force refreshing library');
    setState(() {
      loading = true;
    });
    _loadExams();
  }

  // Sync user data with cloud
  Future<void> _syncUserData() async {
    if (_isSyncing) return; // Prevent multiple simultaneous syncs

    setState(() {
      _isSyncing = true;
    });

    try {
      Logger.debug('Starting user data sync...');

      // Show sync started message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Syncing data with cloud...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // Force refresh library to trigger cloud sync
      await _loadExams();

      // Clean up expired exams
      await UserExamService.cleanupExpiredExams();

      // Show sync completed message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sync completed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Logger.debug('User data sync completed');
    } catch (e) {
      Logger.error('Error during sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _loadAllProgress() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );

    for (final exam in examProvider.exams) {
      try {
        await progressProvider.loadProgress(exam.id);
        final progress = progressProvider.progress;
        final masteredList =
            (progress['masteredQuestions'] as List?)?.cast<String>() ?? [];
        setState(() {
          examProgress[exam.id] = masteredList.length;
        });
      } catch (e) {
        setState(() {
          examProgress[exam.id] = 0;
        });
      }
    }
  }

  Future<void> _loadExams() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      // Use optimized library service
      final libraryData = await OptimizedLibraryService.loadLibraryData();

      final allExams = libraryData['exams'] as List<ExamEntry>;
      final userExamsData =
          libraryData['userExams'] as List<Map<String, dynamic>>;
      final adminExamsData =
          libraryData['adminExams'] as List<Map<String, dynamic>>;
      final loadTime = libraryData['loadTime'] as int;

      Logger.debug('📚 Library loaded in ${loadTime}ms');

      // Update exam provider
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      examProvider.setExams(allExams);
      await examProvider.saveAllExams();

      // Update state
      setState(() {
        importedExams = adminExamsData
            .map(
              (exam) => ImportedExam(
                id: exam['id'] as String,
                title: exam['title'] as String,
                filename: 'cloud_${exam['id']}',
                importedAt: DateTime.now(),
              ),
            )
            .toList();
        userExams = userExamsData;
        unlockedExams = userExamsData
            .where((exam) => exam['type'] == 'unlocked')
            .toList();
        userImportedExams = userExamsData
            .where((exam) => exam['type'] == 'user_imported')
            .toList();
        loading = false;
        loadError = null;
      });

      // Start animations
      _fadeController.forward();
      _slideController.forward();

      // Load progress for all exams after they're loaded
      _loadAllProgress();
    } catch (e) {
      setState(() {
        loadError = 'Failed to load exams: ${e.toString()}';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    Logger.debug(
      'Library build - Total exams in provider: ${examProvider.exams.length}',
    );
    Logger.debug('Library build - Search term: "$search"');

    final filtered = examProvider.exams
        .where((e) => e.title.toLowerCase().contains(search.toLowerCase()))
        .toList();

    Logger.debug('Library build - Filtered exams count: ${filtered.length}');
    for (final exam in examProvider.exams) {
      Logger.debug('Library build - Exam: ${exam.title}');
    }

    Provider.of<ProgressProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          '📚 Study Library',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Refresh Button with cache indicator
          FutureBuilder<Map<String, dynamic>>(
            future: Future.value(OptimizedLibraryService.getCacheStatus()),
            builder: (context, snapshot) {
              final cacheStatus =
                  snapshot.data ?? {'isValid': false, 'ageMinutes': 0};
              final isCacheValid = cacheStatus['isValid'] as bool;
              final cacheAge = cacheStatus['ageMinutes'] as int;

              return IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.refresh, color: theme.colorScheme.onSurface),
                    if (isCacheValid)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  setState(() {
                    loading = true;
                  });
                  _loadExams();
                },
                tooltip: isCacheValid
                    ? 'Refresh Library (Cache: ${cacheAge}min ago)'
                    : 'Refresh Library',
              );
            },
          ),
          // Voucher Entry Button
          IconButton(
            icon: Icon(Icons.card_giftcard, color: theme.colorScheme.primary),
            onPressed: () {
              context.go('/voucher-entry');
            },
            tooltip: 'Enter Voucher',
          ),
          // Admin Portal Switch Button (only visible for authenticated admins)
          FutureBuilder<bool>(
            future: AdminAuthService.isAuthenticated(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return IconButton(
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color: theme.colorScheme.primary,
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
          // Sync Button (replaces burger menu)
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(Icons.sync, color: theme.colorScheme.primary),
            onPressed: _isSyncing ? null : _syncUserData,
            tooltip: _isSyncing ? 'Syncing...' : 'Sync Data',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/comprehensive-import');
        },
        icon: const Icon(Icons.file_upload),
        label: const Text('Import'),
        elevation: 4,
      ),
      body: loading
          ? _buildLoadingState()
          : loadError != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildSearchSection(theme),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildExamList(filtered, theme),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your study materials...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loadError!,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadExams,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search exams...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: search.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => search = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No exams found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamList(List filtered, ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length + 1, // +1 for the "Add Exam" button
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              return _buildAddExamButton(theme);
            }
            return _buildExamCard(filtered[index], theme);
          },
        ),
      ),
    );
  }

  Widget _buildExamCard(dynamic exam, ThemeData theme) {
    final mastered = examProgress[exam.id] ?? 0;
    final total = exam.questions.length;
    final percent = total > 0 ? mastered / total : 0.0;

    // Determine exam type and styling
    final isUnlocked = unlockedExams.any((e) => e['id'] == exam.id);
    final isUserImported = userImportedExams.any((e) => e['id'] == exam.id);
    final isAdminImported = importedExams.any((e) => e.id == exam.id);

    // Get exam type for badge
    String examType = 'Unknown';
    Color badgeColor = Colors.grey;
    IconData examIcon = Icons.help;

    if (isUnlocked) {
      examType = 'Unlocked';
      badgeColor = Colors.green;
      examIcon = Icons.lock_open;
    } else if (isUserImported) {
      examType = 'User Imported';
      badgeColor = Colors.orange;
      examIcon = Icons.upload;
    } else if (isAdminImported) {
      examType = 'Admin Imported (Locked)';
      badgeColor = Colors.red;
      examIcon = Icons.lock;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // If admin imported and not unlocked, show voucher entry
            if (isAdminImported && !isUnlocked) {
              _showVoucherEntryDialog(exam);
            } else {
              context.go('/exam/${exam.id}');
            }
          },
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
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(examIcon, color: badgeColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              examType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'rename':
                            await _showRenameDialog(exam);
                            break;
                          case 'delete':
                            await _showDeleteDialog(exam);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isUnlocked && (isUserImported || isAdminImported))
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                const Text('Rename'),
                              ],
                            ),
                          ),
                        if (!isUnlocked && (isUserImported || isAdminImported))
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildProgressSection(mastered, total, percent, theme),
                const SizedBox(height: 16),
                // Add expiration info for unlocked exams
                if (isUnlocked) _buildExpirationSection(exam, theme),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // If admin imported and not unlocked, show voucher entry
                          if (isAdminImported && !isUnlocked) {
                            _showVoucherEntryDialog(exam);
                          } else {
                            context.go('/exam/${exam.id}');
                          }
                        },
                        icon: Icon(
                          isAdminImported && !isUnlocked
                              ? Icons.lock
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          isAdminImported && !isUnlocked
                              ? 'Unlock with Voucher'
                              : 'Start Studying',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpirationSection(dynamic exam, ThemeData theme) {
    // Find the unlocked exam data to get expiry information
    final unlockedExam = unlockedExams.firstWhere(
      (e) => e['id'] == exam.id,
      orElse: () => <String, dynamic>{},
    );

    final expiryDateStr = unlockedExam['expiryDate'];
    if (expiryDateStr == null) return SizedBox.shrink();

    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      final expiryStatus = ExpiryCleanupService.getExpiryDateString(expiryDate);
      final statusColor = ExpiryCleanupService.getExpiryStatusColor(expiryDate);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 16, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Access expires: $expiryStatus',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return SizedBox.shrink();
    }
  }

  Widget _buildProgressSection(
    int mastered,
    int total,
    double percent,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$mastered of $total questions mastered',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAddExamButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAddExamDialog(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 32,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Exam Manually',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a custom exam with your own questions',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(dynamic exam) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => _buildRenameDialog(exam),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      final idx = importedExams.indexWhere((e) => e.id == exam.id);
      if (idx != -1) {
        final updated = ImportedExam(
          id: importedExams[idx].id,
          title: newTitle.trim(),
          filename: importedExams[idx].filename,
          importedAt: importedExams[idx].importedAt,
        );
        importedExams[idx] = updated;
        await ImportedExamStorage.saveAll(importedExams);
        _loadExams();
      }
    }
  }

  Widget _buildRenameDialog(dynamic exam) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: exam.title);

    return AlertDialog(
      title: Text(
        'Rename Exam',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Exam Title',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }

  void _showVoucherEntryDialog(dynamic exam) {
    // Navigate to the dedicated voucher entry screen
    context.go('/voucher-entry');
  }

  Future<void> _showDeleteDialog(dynamic exam) async {
    // Check if exam is unlocked (redeemed via voucher)
    final isUnlocked = unlockedExams.any((e) => e['id'] == exam.id);

    if (isUnlocked) {
      // Show error dialog for redeemed exams
      showDialog(
        context: context,
        builder: (context) => _buildProtectedExamDialog(exam),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteDialog(exam),
    );
    if (confirm == true) {
      // Check if it's a user imported exam
      final isUserImported = userImportedExams.any((e) => e['id'] == exam.id);

      if (isUserImported) {
        // Delete from UserExamService
        await UserExamService.removeUserImportedExam(exam.id);
      } else {
        // Delete from ImportedExamStorage (admin imported)
        await ImportedExamStorage.removeExam(exam.id);
      }

      _loadExams();
    }
  }

  Widget _buildProtectedExamDialog(dynamic exam) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: theme.colorScheme.onErrorContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Protected Exam',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cannot delete "${exam.title}"',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This exam was unlocked using a voucher and cannot be deleted. Redeemed exams are protected to maintain your access.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can only delete exams that you imported manually.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildDeleteDialog(dynamic exam) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 8),
          Text(
            'Delete Exam',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete "${exam.title}"? This action cannot be undone.',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _showAddExamDialog() async {
    final newExam = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildAddExamDialog(),
    );
    if (newExam != null) {
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Create the exam questions
      final questions = (newExam['questions'] as List<String>)
          .asMap()
          .entries
          .map(
            (entry) => ExamQuestion(
              id: entry.key,
              type: 'mcq', // Default to multiple choice
              text: entry.value,
              questionImages: const [],
              answerImages: const [],
              options: [
                'Option A',
                'Option B',
                'Option C',
                'Option D',
              ], // Default options
              answers: ['A'], // Default answer
              explanation: null,
            ),
          )
          .toList();

      // Create the exam entry
      final examEntry = ExamEntry(
        id: id,
        title: newExam['title'] as String,
        questions: questions,
      );

      // Add to ExamProvider
      examProvider.addExam(examEntry);

      // Add to UserExamService as user imported
      final examData = {
        'id': id,
        'title': newExam['title'] as String,
        'questions': questions.map((q) => q.toMap()).toList(),
        'type': 'user_imported',
        'importDate': DateTime.now().toIso8601String(),
      };

      await UserExamService.addUserImportedExam(examData);

      // Reload exams to ensure everything is properly updated
      await _loadExams();
      // Save all exams to persistent storage
      await examProvider.saveAllExams();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exam "${newExam['title']}" added successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAddExamDialog() {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final questionController = TextEditingController();

    return AlertDialog(
      title: Text(
        'Add Exam Manually',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Exam Title',
                hintText: 'Enter exam title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              decoration: InputDecoration(
                labelText: 'Questions (one per line)',
                hintText: 'Enter questions, one per line',
                helperText:
                    'You can add options and answers later by editing the exam',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            titleController.clear();
            questionController.clear();
            Navigator.pop(context);
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            final questions = questionController.text
                .split('\n')
                .map((q) => q.trim())
                .where((q) => q.isNotEmpty)
                .toList();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter an exam title'),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }
            if (questions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter at least one question'),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, {'title': title, 'questions': questions});
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
