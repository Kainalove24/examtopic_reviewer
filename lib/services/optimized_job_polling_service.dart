import 'dart:async';
import '../services/scraper_api_service.dart';
import '../services/admin_portal_cache_service.dart';

class OptimizedJobPollingService {
  static final Map<String, Timer> _pollingTimers = {};
  static final Map<String, int> _pollingIntervals = {};
  static final Map<String, Function(Map<String, dynamic>)> _statusCallbacks =
      {};
  static const int _initialInterval = 2000; // 2 seconds
  static const int _maxInterval = 10000; // 10 seconds
  static const double _intervalMultiplier = 1.5;

  // Start polling for a job with optimized intervals
  static void startPolling(
    String jobId,
    Function(Map<String, dynamic>) onStatusUpdate,
    Function(String) onComplete,
    Function(String) onError,
  ) {
    // Stop any existing polling for this job
    stopPolling(jobId);

    // Initialize polling interval
    _pollingIntervals[jobId] = _initialInterval;
    _statusCallbacks[jobId] = onStatusUpdate;

    // Start polling
    _pollJobStatus(jobId, onComplete, onError);
  }

  // Poll job status with adaptive intervals
  static void _pollJobStatus(
    String jobId,
    Function(String) onComplete,
    Function(String) onError,
  ) {
    _pollingTimers[jobId] = Timer(
      Duration(milliseconds: _pollingIntervals[jobId]!),
      () async {
        try {
          final status = await ScraperApiService.getJobStatus(jobId);

          if (status.containsKey('error')) {
            stopPolling(jobId);
            onError(status['error']);
            return;
          }

          // Update status callback
          if (_statusCallbacks.containsKey(jobId)) {
            _statusCallbacks[jobId]!(status);
          }

          final jobStatus = status['status'] as String? ?? 'unknown';

          if (jobStatus == 'completed') {
            stopPolling(jobId);
            onComplete(jobId);
          } else if (jobStatus == 'failed') {
            stopPolling(jobId);
            onError(status['error'] ?? 'Job failed');
          } else {
            // Continue polling with adaptive interval
            _adaptPollingInterval(jobId, status);
            _pollJobStatus(jobId, onComplete, onError);
          }
        } catch (e) {
          stopPolling(jobId);
          onError('Polling error: $e');
        }
      },
    );
  }

  // Adapt polling interval based on job status
  static void _adaptPollingInterval(String jobId, Map<String, dynamic> status) {
    final currentInterval = _pollingIntervals[jobId] ?? _initialInterval;
    final progress = status['progress'] as int? ?? 0;
    final jobStatus = status['status'] as String? ?? 'unknown';

    int newInterval = currentInterval;

    // If job is making progress, keep current interval
    if (progress > 0 && jobStatus == 'running') {
      newInterval = currentInterval;
    } else if (jobStatus == 'queued' || jobStatus == 'starting') {
      // If job is queued or starting, poll more frequently
      newInterval = _initialInterval;
    } else {
      // Gradually increase interval for long-running jobs
      newInterval = (currentInterval * _intervalMultiplier).round();
      if (newInterval > _maxInterval) {
        newInterval = _maxInterval;
      }
    }

    _pollingIntervals[jobId] = newInterval;
  }

  // Stop polling for a specific job
  static void stopPolling(String jobId) {
    _pollingTimers[jobId]?.cancel();
    _pollingTimers.remove(jobId);
    _pollingIntervals.remove(jobId);
    _statusCallbacks.remove(jobId);
  }

  // Stop all polling
  static void stopAllPolling() {
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _pollingIntervals.clear();
    _statusCallbacks.clear();
  }

  // Get active polling jobs
  static List<String> getActivePollingJobs() {
    return _pollingTimers.keys.toList();
  }

  // Get polling stats
  static Map<String, dynamic> getPollingStats() {
    return {
      'activeJobs': _pollingTimers.length,
      'activeJobIds': _pollingTimers.keys.toList(),
      'intervals': Map<String, int>.from(_pollingIntervals),
    };
  }

  // Preload job data for better performance
  static Future<List<Map<String, dynamic>>> preloadJobs() async {
    try {
      // Try to get cached jobs first
      final cachedJobs = await AdminPortalCacheService.getCachedJobs();
      if (cachedJobs != null) {
        return cachedJobs;
      }

      // Fetch fresh jobs
      final jobs = await ScraperApiService.listJobs();

      // Cache the jobs
      await AdminPortalCacheService.cacheJobs(jobs);

      return jobs;
    } catch (e) {
      return [];
    }
  }

  // Get job with caching
  static Future<Map<String, dynamic>?> getJobWithCache(String jobId) async {
    try {
      final jobs = await preloadJobs();
      return jobs.firstWhere(
        (job) => job['job_id'] == jobId,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }
}
