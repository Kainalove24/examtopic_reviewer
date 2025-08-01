import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';

class DataManagementService {
  static final DataManagementService _instance =
      DataManagementService._internal();
  factory DataManagementService() => _instance;
  DataManagementService._internal();

  // Export all data to JSON
  Future<String> exportAllData({
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
    required SettingsProvider settingsProvider,
  }) async {
    try {
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'exams': examProvider.exams.map((exam) => exam.toMap()).toList(),
        'progress': await _getAllProgressData(progressProvider),
        'settings': await _getSettingsData(settingsProvider),
      };

      return jsonEncode(exportData);
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  // Import data from JSON
  Future<void> importData({
    required String jsonData,
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
    required SettingsProvider settingsProvider,
    bool overwriteExisting = false,
  }) async {
    try {
      final importData = jsonDecode(jsonData) as Map<String, dynamic>;

      // Validate version
      final version = importData['version'] as String?;
      if (version == null || !version.startsWith('1.')) {
        throw Exception('Unsupported data format version');
      }

      // Import exams
      if (importData.containsKey('exams')) {
        final examsData = importData['exams'] as List;
        if (overwriteExisting) {
          examProvider.setExams([]);
        }

        for (final examData in examsData) {
          final exam = ExamEntry.fromMap(examData as Map<String, dynamic>);
          if (!overwriteExisting && examProvider.getExamById(exam.id) != null) {
            // Skip if exam already exists and we're not overwriting
            continue;
          }
          examProvider.addExam(exam);
        }
      }

      // Import progress
      if (importData.containsKey('progress')) {
        await _importProgressData(
          importData['progress'] as Map<String, dynamic>,
          progressProvider,
          overwriteExisting,
        );
      }

      // Import settings
      if (importData.containsKey('settings')) {
        await _importSettingsData(
          importData['settings'] as Map<String, dynamic>,
          settingsProvider,
          overwriteExisting,
        );
      }
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  // Backup data to file
  Future<String> backupData({
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
    required SettingsProvider settingsProvider,
  }) async {
    try {
      final jsonData = await exportAllData(
        examProvider: examProvider,
        progressProvider: progressProvider,
        settingsProvider: settingsProvider,
      );

      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'examtopic_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');

      await file.writeAsString(jsonData);
      return file.path;
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  // Restore data from backup file
  Future<void> restoreFromBackup({
    required String filePath,
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
    required SettingsProvider settingsProvider,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      final jsonData = await file.readAsString();
      await importData(
        jsonData: jsonData,
        examProvider: examProvider,
        progressProvider: progressProvider,
        settingsProvider: settingsProvider,
        overwriteExisting: true,
      );
    } catch (e) {
      throw Exception('Failed to restore from backup: $e');
    }
  }

  // Get list of available backups
  Future<List<FileSystemEntity>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      return files.where((file) => file.path.endsWith('.json')).toList();
    } catch (e) {
      throw Exception('Failed to get backups: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData({
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
    required SettingsProvider settingsProvider,
  }) async {
    try {
      // Clear exams
      examProvider.setExams([]);
      await examProvider.saveAllExams();

      // Clear progress
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('progress_')) {
          await prefs.remove(key);
        }
      }

      // Clear settings (but keep essential ones)
      await settingsProvider.setAiExplanationsEnabled(true);

      // Clear backup files
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }

  // Get data statistics
  Future<Map<String, dynamic>> getDataStatistics({
    required ExamProvider examProvider,
    required ProgressProvider progressProvider,
  }) async {
    try {
      final stats = <String, dynamic>{
        'totalExams': examProvider.exams.length,
        'totalQuestions': examProvider.exams.fold<int>(
          0,
          (sum, exam) => sum + exam.questions.length,
        ),
        'backupCount': (await getAvailableBackups()).length,
        'lastBackup': null,
      };

      // Get last backup date
      final backups = await getAvailableBackups();
      if (backups.isNotEmpty) {
        final lastBackup = backups.first;
        stats['lastBackup'] = lastBackup.statSync().modified.toIso8601String();
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  // Pick file for import
  Future<String?> pickImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick file: $e');
    }
  }

  // Save file for export
  Future<String?> saveExportFile(String jsonData) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Data Export',
        fileName:
            'examtopic_export_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonData);
        return file.path;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _getAllProgressData(
    ProgressProvider progressProvider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final progressData = <String, dynamic>{};

    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('progress_')) {
        final examId = key.replaceFirst('progress_', '');
        final data = prefs.getString(key);
        if (data != null) {
          progressData[examId] = jsonDecode(data);
        }
      }
    }

    return progressData;
  }

  Future<Map<String, dynamic>> _getSettingsData(
    SettingsProvider settingsProvider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsData = <String, dynamic>{};

    // Get all settings from SharedPreferences
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (!key.startsWith('progress_')) {
        final value = prefs.get(key);
        if (value != null) {
          settingsData[key] = value;
        }
      }
    }

    return settingsData;
  }

  Future<void> _importProgressData(
    Map<String, dynamic> progressData,
    ProgressProvider progressProvider,
    bool overwriteExisting,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in progressData.entries) {
      final examId = entry.key;
      final progress = entry.value;

      if (overwriteExisting || !prefs.containsKey('progress_$examId')) {
        await prefs.setString('progress_$examId', jsonEncode(progress));
      }
    }
  }

  Future<void> _importSettingsData(
    Map<String, dynamic> settingsData,
    SettingsProvider settingsProvider,
    bool overwriteExisting,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in settingsData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (overwriteExisting || !prefs.containsKey(key)) {
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        }
      }
    }
  }
}
